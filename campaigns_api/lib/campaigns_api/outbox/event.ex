defmodule CampaignsApi.Outbox.Event do
  @moduledoc """
  Persistent domain event record used by the outbox + CDC integration.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          aggregate_type: String.t(),
          aggregate_id: String.t(),
          event_type: String.t(),
          payload: map(),
          occurred_at: DateTime.t(),
          inserted_at: DateTime.t()
        }

  schema "outbox_events" do
    field(:aggregate_type, :string)
    field(:aggregate_id, :string)
    field(:event_type, :string)
    field(:payload, :map)
    field(:occurred_at, :utc_datetime_usec)

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(event, attrs) do
    event
    |> cast(attrs, [:aggregate_type, :aggregate_id, :event_type, :payload, :occurred_at])
    |> validate_required([:aggregate_type, :aggregate_id, :event_type, :payload, :occurred_at])
  end
end
