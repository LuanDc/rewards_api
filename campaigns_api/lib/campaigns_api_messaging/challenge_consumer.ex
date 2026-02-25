defmodule CampaignsApiMessaging.ChallengeConsumer do
  @moduledoc """
  Broadway consumer for challenge ingestion events.
  """

  use Broadway

  alias Broadway.Message
  alias CampaignsApi.Challenges
  alias CampaignsApiMessaging.ChallengeMessage
  alias CampaignsApiMessaging.ChallengePublisher

  def start_link(_opts) do
    broadway_config = Application.fetch_env!(:campaigns_api, CampaignsApiMessaging.Broadway)
    messaging_config = Application.fetch_env!(:campaigns_api, CampaignsApiMessaging)

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

  defp classify_failure_action({:invalid_payload, _}), do: :dlq
  defp classify_failure_action({:validation_error, _}), do: :dlq
  defp classify_failure_action(_), do: :retry

  defp republish_with_retry(message) do
    current_retry_count = retry_count(message)
    max_retries = Application.fetch_env!(:campaigns_api, CampaignsApiMessaging)[:max_retries]

    if current_retry_count < max_retries do
      ChallengePublisher.publish_raw(raw_payload(message),
        headers: [{"x-retry-count", :long, current_retry_count + 1}]
      )
    else
      publish_to_dlq(message)
    end
  end

  defp publish_to_dlq(message) do
    messaging_config = Application.fetch_env!(:campaigns_api, CampaignsApiMessaging)

    ChallengePublisher.publish_raw(raw_payload(message),
      routing_key: messaging_config[:dlq_routing_key],
      headers: [{"x-retry-count", :long, retry_count(message)}]
    )
  end

  defp raw_payload(%Message{metadata: metadata, data: data}) do
    Map.get(metadata, :raw_payload, data)
  end

  defp retry_count(%Message{metadata: metadata}) do
    metadata
    |> Map.get(:headers, [])
    |> Enum.find_value(0, fn
      {"x-retry-count", _type, value} when is_integer(value) -> value
      {<<"x-retry-count">>, _type, value} when is_integer(value) -> value
      _ -> nil
    end)
  end

  defp put_raw_payload(%Message{metadata: metadata} = message, payload) do
    %{message | metadata: Map.put(metadata, :raw_payload, payload)}
  end
end
