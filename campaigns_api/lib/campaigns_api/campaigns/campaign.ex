defmodule CampaignsApi.Campaigns.Campaign do
  @moduledoc """
  Schema for campaigns.

  Campaigns represent marketing or engagement initiatives managed by tenants.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type status :: :not_started | :active | :paused | :completed | :cancelled
  @type t :: %__MODULE__{
          id: Ecto.UUID.t() | nil,
          name: String.t(),
          tenant: String.t(),
          started_at: DateTime.t() | nil,
          finished_at: DateTime.t() | nil,
          status: status(),
          inserted_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil
        }

  @statuses ~w(not_started active paused completed cancelled)a

  @primary_key {:id, Uniq.UUID, version: 7, autogenerate: true}
  @foreign_key_type Uniq.UUID

  schema "campaigns" do
    field(:name, :string)
    field(:tenant, :string)
    field(:started_at, :utc_datetime_usec)
    field(:finished_at, :utc_datetime_usec)
    field(:status, Ecto.Enum, values: @statuses, default: :not_started)

    many_to_many(:criteria, CampaignsApi.Criteria.Criterion,
      join_through: CampaignsApi.Campaigns.CampaignCriterion,
      on_replace: :delete
    )

    timestamps()
  end

  @doc """
  Creates a changeset for creating a new campaign.

  ## Required fields
  - name: Campaign name (1-255 characters)
  - tenant: Tenant identifier string (1-100 characters)

  ## Optional fields
  - started_at: Campaign start date/time in UTC with microseconds
  - finished_at: Campaign end date/time in UTC with microseconds
  - status: Campaign status (defaults to :not_started)

  ## Validations
  - name must be present and between 1 and 255 characters
  - tenant must be present and between 1 and 100 characters
  - status must be one of: #{Enum.join(@statuses, ", ")}
  - finished_at must be after started_at (if both are present)
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(campaign, attrs) do
    campaign
    |> cast(attrs, [:name, :tenant, :started_at, :finished_at, :status])
    |> validate_required([:name, :tenant])
    |> validate_length(:name, min: 1, max: 255)
    |> validate_length(:tenant, min: 1, max: 100)
    |> validate_inclusion(:status, @statuses)
    |> validate_dates()
  end

  @doc """
  Returns the list of valid campaign statuses.
  """
  @spec statuses() :: [status()]
  def statuses, do: @statuses

  # Private functions

  defp validate_dates(changeset) do
    started_at = get_field(changeset, :started_at)
    finished_at = get_field(changeset, :finished_at)

    case {started_at, finished_at} do
      {%DateTime{} = start, %DateTime{} = finish} ->
        if DateTime.compare(finish, start) in [:lt, :eq] do
          add_error(changeset, :finished_at, "must be after started_at")
        else
          changeset
        end

      _ ->
        changeset
    end
  end
end
