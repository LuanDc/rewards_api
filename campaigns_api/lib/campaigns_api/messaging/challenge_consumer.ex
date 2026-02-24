defmodule CampaignsApi.Messaging.ChallengeConsumer do
  @moduledoc """
  Broadway consumer for challenge ingestion events.
  """

  use Broadway

  alias Broadway.Message
  alias CampaignsApi.Challenges
  alias CampaignsApi.Messaging.ChallengeMessage
  alias CampaignsApi.Messaging.ChallengePublisher

  def start_link(_opts) do
    broadway_config = Application.fetch_env!(:campaigns_api, CampaignsApi.Messaging.Broadway)
    messaging_config = Application.fetch_env!(:campaigns_api, CampaignsApi.Messaging)

    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [
        module: {
          BroadwayRabbitMQ.Producer,
          queue: messaging_config[:queue],
          connection: messaging_config[:rabbitmq_url],
          qos: [prefetch_count: broadway_config[:prefetch_count]],
          metadata: [:headers],
          on_failure: :reject_and_requeue,
          on_success: :ack
        },
        concurrency: broadway_config[:producers]
      ],
      processors: [
        default: [concurrency: broadway_config[:processors]]
      ],
      batchers: [
        challenges: [
          concurrency: broadway_config[:batchers],
          batch_size: broadway_config[:batch_size],
          batch_timeout: broadway_config[:batch_timeout_ms]
        ]
      ]
    )
  end

  @impl true
  def handle_message(_, %Message{data: raw_payload} = message, _) do
    case ChallengeMessage.decode(raw_payload) do
      {:ok, decoded_payload} ->
        message
        |> put_raw_payload(raw_payload)
        |> Message.update_data(fn _ -> decoded_payload end)
        |> Message.put_batcher(:challenges)

      {:error, reason} ->
        Message.failed(message, {:invalid_payload, reason})
    end
  end

  @impl true
  def handle_batch(:challenges, messages, _batch_info, _context) do
    Enum.map(messages, fn message ->
      case Challenges.upsert_challenge(message.data) do
        {:ok, _challenge} ->
          message

        {:error, %Ecto.Changeset{} = changeset} ->
          Message.failed(message, {:validation_error, changeset})

        {:error, reason} ->
          Message.failed(message, {:processing_error, reason})
      end
    end)
  end

  @impl true
  def handle_failed(messages, _context) do
    Enum.map(messages, &route_failed_message/1)
  end

  @spec route_failed_message(Message.t()) :: Message.t()
  defp route_failed_message(message) do
    case classify_failure_action(message.status) do
      :dlq ->
        case publish_to_dlq(message) do
          :ok -> Message.configure_ack(message, on_failure: :ack)
          {:error, _reason} -> Message.configure_ack(message, on_failure: :reject_and_requeue)
        end

      :retry ->
        case republish_with_retry(message) do
          :ok -> Message.configure_ack(message, on_failure: :ack)
          {:error, _reason} -> Message.configure_ack(message, on_failure: :reject_and_requeue)
        end
    end
  end

  @spec classify_failure_action(term()) :: :retry | :dlq
  defp classify_failure_action({:invalid_payload, _}), do: :dlq
  defp classify_failure_action({:validation_error, _}), do: :dlq
  defp classify_failure_action(_), do: :retry

  @spec republish_with_retry(Message.t()) :: :ok | {:error, term()}
  defp republish_with_retry(message) do
    current_retry_count = retry_count(message)
    max_retries = Application.fetch_env!(:campaigns_api, CampaignsApi.Messaging)[:max_retries]

    if current_retry_count < max_retries do
      ChallengePublisher.publish_raw(raw_payload(message),
        headers: [{"x-retry-count", :long, current_retry_count + 1}]
      )
    else
      publish_to_dlq(message)
    end
  end

  @spec publish_to_dlq(Message.t()) :: :ok | {:error, term()}
  defp publish_to_dlq(message) do
    messaging_config = Application.fetch_env!(:campaigns_api, CampaignsApi.Messaging)

    ChallengePublisher.publish_raw(raw_payload(message),
      routing_key: messaging_config[:dlq_routing_key],
      headers: [{"x-retry-count", :long, retry_count(message)}]
    )
  end

  @spec raw_payload(Message.t()) :: binary()
  defp raw_payload(%Message{metadata: metadata, data: data}) do
    Map.get(metadata, :raw_payload, data)
  end

  @spec retry_count(Message.t()) :: non_neg_integer()
  defp retry_count(%Message{metadata: metadata}) do
    metadata
    |> Map.get(:headers, [])
    |> Enum.find_value(0, fn
      {"x-retry-count", _type, value} when is_integer(value) -> value
      {<<"x-retry-count">>, _type, value} when is_integer(value) -> value
      _ -> nil
    end)
  end

  @spec put_raw_payload(Message.t(), binary()) :: Message.t()
  defp put_raw_payload(%Message{metadata: metadata} = message, payload) do
    %{message | metadata: Map.put(metadata, :raw_payload, payload)}
  end
end
