defmodule ChallengesSchedulerMessaging.DomainEvent do
  @moduledoc """
  Parser for domain event payloads delivered from RabbitMQ.

  Supports direct outbox event payloads and CDC envelopes where the outbox row is
  available in `payload.after`.
  """

  @type t :: %__MODULE__{
          aggregate_type: String.t(),
          aggregate_id: String.t(),
          event_type: String.t(),
          payload: map()
        }

  @enforce_keys [:aggregate_type, :aggregate_id, :event_type, :payload]
  defstruct [:aggregate_type, :aggregate_id, :event_type, :payload]

  @spec decode(binary()) :: {:ok, t()} | {:error, term()}
  def decode(raw_payload) when is_binary(raw_payload) do
    with {:ok, decoded} <- Jason.decode(raw_payload),
         outbox_row <- normalize(decoded),
         {:ok, event} <- from_map(outbox_row) do
      {:ok, event}
    else
      {:error, reason} -> {:error, reason}
      :error -> {:error, :invalid_payload}
    end
  end

  defp normalize(%{"payload" => %{"after" => after_payload}}) when is_map(after_payload),
    do: after_payload

  defp normalize(decoded), do: decoded

  defp from_map(%{
         "aggregate_type" => aggregate_type,
         "aggregate_id" => aggregate_id,
         "event_type" => event_type,
         "payload" => payload
       })
       when is_binary(aggregate_type) and is_binary(aggregate_id) and is_binary(event_type) and
              is_map(payload) do
    {:ok,
     %__MODULE__{
       aggregate_type: aggregate_type,
       aggregate_id: aggregate_id,
       event_type: event_type,
       payload: payload
     }}
  end

  defp from_map(_), do: :error
end
