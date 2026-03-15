defmodule CampaignsApiMessaging.ChallengeConsumer do
  @moduledoc """
  Broadway consumer for challenge ingestion events.
  """

  use Broadway

  alias Broadway.Message
  alias CampaignsApi.Challenges
  alias CampaignsApiMessaging.ChallengeMessage

  def start_link(_opts) do
    broadway_config = Application.fetch_env!(:campaigns_api, CampaignsApiMessaging.Broadway)
    messaging_config = Application.fetch_env!(:campaigns_api, CampaignsApiMessaging)

    queue_arguments = [
      {"x-dead-letter-exchange", :longstr, messaging_config[:exchange]},
      {"x-dead-letter-routing-key", :longstr, messaging_config[:dlq_routing_key]}
    ]

    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [
        module: {
          BroadwayRabbitMQ.Producer,
          after_connect: fn channel -> declare_rabbitmq_topology(channel, messaging_config) end,
          queue: messaging_config[:queue],
          declare: [durable: true, arguments: queue_arguments],
          bindings: [{messaging_config[:exchange], [routing_key: messaging_config[:routing_key]]}],
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
    Enum.map(messages, &Message.configure_ack(&1, on_failure: :reject))
  end

  defp declare_rabbitmq_topology(channel, messaging_config) do
    with :ok <-
           AMQP.Exchange.declare(channel, messaging_config[:exchange], :direct, durable: true),
         {:ok, _} <- AMQP.Queue.declare(channel, messaging_config[:queue_dlq], durable: true),
         :ok <-
           AMQP.Queue.bind(channel, messaging_config[:queue_dlq], messaging_config[:exchange],
             routing_key: messaging_config[:dlq_routing_key]
           ) do
      :ok
    end
  end

  defp put_raw_payload(%Message{metadata: metadata} = message, payload) do
    %{message | metadata: Map.put(metadata, :raw_payload, payload)}
  end
end
