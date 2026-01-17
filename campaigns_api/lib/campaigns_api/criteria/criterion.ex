defmodule CampaignsApi.Criteria.Criterion do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, Ecto.UUID, autogenerate: false}
  @foreign_key_type Ecto.UUID

  @statuses ~w(active inactive)

  schema "criteria" do
    field :name, :string
    field :status, :string, default: "active"
    field :description, :string

    many_to_many :campaigns, CampaignsApi.Campaigns.Campaign,
      join_through: CampaignsApi.Campaigns.CampaignCriterion,
      on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(criterion, attrs) do
    criterion
    |> cast(attrs, [:name, :status, :description])
    |> validate_required([:name, :status])
    |> validate_inclusion(:status, @statuses)
    |> unique_constraint(:name)
    |> put_uuid()
  end

  defp put_uuid(changeset) do
    case get_field(changeset, :id) do
      nil -> put_change(changeset, :id, Uniq.UUID.uuid7())
      _ -> changeset
    end
  end
end
