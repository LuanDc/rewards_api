defmodule ChallengesSchedulerMessaging.CampaignProjectionConsumer do
  @moduledoc """
  Broadway consumer that projects campaign domain events into scheduler read models.
  """

  use Broadway

  alias Broadway.Message
  alias ChallengesScheduler.CampaignCalendars
  alias ChallengesSchedulerMessaging.DomainEvent

  def start_link(_opts) do
    broadway_config =
      Application.fetch_env!(:challenges_scheduler, ChallengesSchedulerMessaging.Broadway)

    messaging_config = Application.fetch_env!(:challenges_scheduler, ChallengesSchedulerMessaging)

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
          bindings:
            Enum.map(messaging_config[:routing_keys], fn routing_key ->
              {messaging_config[:exchange], [routing_key: routing_key]}
            end),
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
        projections: [
          concurrency: broadway_config[:batchers],
          batch_size: broadway_config[:batch_size],
          batch_timeout: broadway_config[:batch_timeout_ms]
        ]
      ]
    )
  end

  @impl true
  def handle_message(_, %Message{data: raw_payload} = message, _) do
    case DomainEvent.decode(raw_payload) do
      {:ok, event} ->
        message
        |> Message.update_data(fn _ -> event end)
        |> Message.put_batcher(:projections)

      {:error, reason} ->
        Message.failed(message, {:invalid_payload, reason})
    end
  end

  @impl true
  def handle_batch(:projections, messages, _batch_info, _context) do
    Enum.map(messages, fn message ->
      case project_event(message.data) do
        :ok -> message
        {:error, reason} -> Message.failed(message, {:projection_error, reason})
      end
    end)
  end

  @impl true
  def handle_failed(messages, _context) do
    Enum.map(messages, &Message.configure_ack(&1, on_failure: :reject))
  end

  defp project_event(%DomainEvent{event_type: "campaign.created", payload: payload}),
    do: run_projection(CampaignCalendars.upsert_campaign(payload))

  defp project_event(%DomainEvent{event_type: "campaign.updated", payload: payload}),
    do: run_projection(CampaignCalendars.upsert_campaign(payload))

  defp project_event(%DomainEvent{event_type: "campaign.deleted", payload: payload}) do
    campaign_id = Map.get(payload, "id")

    if is_nil(campaign_id) do
      {:error, :missing_campaign_id}
    else
      CampaignCalendars.delete_campaign(campaign_id)
    end
  end

  defp project_event(%DomainEvent{event_type: "campaign_challenge.created", payload: payload}),
    do: run_projection(CampaignCalendars.upsert_challenge_schedule(payload))

  defp project_event(%DomainEvent{event_type: "campaign_challenge.updated", payload: payload}),
    do: run_projection(CampaignCalendars.upsert_challenge_schedule(payload))

  defp project_event(%DomainEvent{event_type: "campaign_challenge.deleted", payload: payload}) do
    campaign_challenge_id = Map.get(payload, "id")

    if is_nil(campaign_challenge_id) do
      {:error, :missing_campaign_challenge_id}
    else
      CampaignCalendars.delete_challenge_schedule(campaign_challenge_id)
    end
  end

  defp project_event(%DomainEvent{event_type: "challenge.deleted", payload: payload}) do
    challenge_id = Map.get(payload, "id")

    if is_nil(challenge_id) do
      {:error, :missing_challenge_id}
    else
      CampaignCalendars.delete_challenge_schedules_by_challenge(challenge_id)
    end
  end

  defp project_event(%DomainEvent{event_type: event_type})
       when event_type in ["challenge.created", "challenge.updated"],
       do: :ok

  defp project_event(%DomainEvent{event_type: event_type}),
    do: {:error, {:unsupported_event, event_type}}

  defp run_projection({:ok, _projection}), do: :ok
  defp run_projection({:error, reason}), do: {:error, reason}

  defp declare_rabbitmq_topology(channel, messaging_config) do
    with :ok <-
           AMQP.Exchange.declare(channel, messaging_config[:exchange], :topic, durable: true),
         {:ok, _} <- AMQP.Queue.declare(channel, messaging_config[:queue_dlq], durable: true),
         :ok <-
           AMQP.Queue.bind(channel, messaging_config[:queue_dlq], messaging_config[:exchange],
             routing_key: messaging_config[:dlq_routing_key]
           ) do
      :ok
    end
  end
end
