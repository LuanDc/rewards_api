defmodule BackofficeApiMessaging.ChallengePublisher do
  @moduledoc """
  Publishes challenge upsert events to RabbitMQ.
  """

  alias BackofficeApiMessaging.ChallengeMessage

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
         :ok <- ensure_exchange(channel),
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
      _ = AMQP.Channel.close(channel)
      _ = AMQP.Connection.close(connection)
      :ok
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec ensure_exchange(AMQP.Channel.t()) :: :ok | {:error, :blocked | :closing}
  defp ensure_exchange(channel) do
    AMQP.Exchange.declare(channel, config(:exchange), :direct, durable: true)
  end

  defp config(key), do: Application.fetch_env!(:backoffice_api, BackofficeApiMessaging)[key]

  defp get_field(map, key) when is_map(map) do
    Map.get(map, key) || Map.get(map, Atom.to_string(key))
  end
end
