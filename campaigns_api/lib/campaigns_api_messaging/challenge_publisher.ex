defmodule CampaignsApiMessaging.ChallengePublisher do
  @moduledoc """
  Publisher for challenge ingestion messages.
  """

  alias CampaignsApiMessaging.ChallengeMessage

  @spec publish_challenge(map()) :: :ok | {:error, term()}
  def publish_challenge(challenge_attrs) do
    payload = %{
      schema_version: 1,
      external_id: get_field(challenge_attrs, :external_id),
      name: get_field(challenge_attrs, :name),
      description: get_field(challenge_attrs, :description),
      metadata: get_field(challenge_attrs, :metadata) || %{}
    }

    with {:ok, encoded_payload} <- ChallengeMessage.encode(payload) do
      publish_raw(encoded_payload, routing_key: config(:routing_key), headers: [])
    end
  end

  @spec publish_raw(binary(), keyword()) :: :ok | {:error, term()}
  def publish_raw(raw_payload, opts \\ []) when is_binary(raw_payload) do
    with {:ok, connection} <- AMQP.Connection.open(config(:rabbitmq_url)),
         {:ok, channel} <- AMQP.Channel.open(connection),
         :ok <- setup_topology(channel),
         :ok <-
           AMQP.Basic.publish(
             channel,
             config(:exchange),
             Keyword.get(opts, :routing_key, config(:routing_key)),
             raw_payload,
             persistent: true,
             content_type: "application/json",
             headers: Keyword.get(opts, :headers, [])
           ) do
      AMQP.Channel.close(channel)
      AMQP.Connection.close(connection)
      :ok
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec setup_topology(AMQP.Channel.t()) :: :ok | {:error, term()}
  def setup_topology(channel) do
    exchange = config(:exchange)
    queue = config(:queue)
    queue_dlq = config(:queue_dlq)
    routing_key = config(:routing_key)
    dlq_routing_key = config(:dlq_routing_key)

    with :ok <- AMQP.Exchange.declare(channel, exchange, :direct, durable: true),
         {:ok, _} <- AMQP.Queue.declare(channel, queue, durable: true),
         {:ok, _} <- AMQP.Queue.declare(channel, queue_dlq, durable: true),
         :ok <- AMQP.Queue.bind(channel, queue, exchange, routing_key: routing_key),
         :ok <- AMQP.Queue.bind(channel, queue_dlq, exchange, routing_key: dlq_routing_key) do
      :ok
    end
  end

  @spec config(atom()) :: term()
  defp config(key), do: Application.fetch_env!(:campaigns_api, CampaignsApiMessaging)[key]

  @spec get_field(map(), atom()) :: term()
  defp get_field(map, key) when is_map(map) do
    Map.get(map, key) || Map.get(map, Atom.to_string(key))
  end
end
