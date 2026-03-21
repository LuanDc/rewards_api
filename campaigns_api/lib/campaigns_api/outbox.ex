defmodule CampaignsApi.Outbox do
  @moduledoc """
  Helpers for transactional outbox writes.

  Events are persisted in the same database transaction as domain changes and
  later published asynchronously by CDC.
  """

  alias CampaignsApi.Outbox.Event
  alias Ecto.Multi

  @type changes :: map()
  @type aggregate_id_fun :: (changes() -> term())
  @type payload_fun :: (changes() -> map())

  @spec enqueue_multi(Multi.t(), atom(), keyword()) :: Multi.t()
  def enqueue_multi(%Multi{} = multi, step_name, opts) do
    aggregate_type = Keyword.fetch!(opts, :aggregate_type)
    event_type = Keyword.fetch!(opts, :event_type)
    aggregate_id_fun = Keyword.fetch!(opts, :aggregate_id)
    payload_fun = Keyword.fetch!(opts, :payload)

    Multi.run(multi, {:outbox, step_name}, fn repo, changes ->
      attrs = %{
        aggregate_type: aggregate_type,
        aggregate_id: aggregate_id_fun.(changes) |> to_string(),
        event_type: event_type,
        payload: payload_fun.(changes),
        occurred_at: DateTime.utc_now() |> DateTime.truncate(:second)
      }

      %Event{}
      |> Event.changeset(attrs)
      |> repo.insert()
    end)
  end
end
