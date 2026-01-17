defmodule CampaignsApi.Campaigns.CampaignCriterion do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, Ecto.UUID, autogenerate: false}
  @foreign_key_type Ecto.UUID

  @statuses ~w(active inactive)

  schema "campaign_criteria" do
    belongs_to(:campaign, CampaignsApi.Campaigns.Campaign)
    belongs_to(:criterion, CampaignsApi.Criteria.Criterion)

    field(:periodicity, :string)
    field(:status, :string, default: "active")
    field(:reward_points_amount, :integer)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(campaign_criterion, attrs) do
    campaign_criterion
    |> cast(attrs, [:campaign_id, :criterion_id, :periodicity, :status, :reward_points_amount])
    |> validate_required([:campaign_id, :criterion_id, :status, :reward_points_amount])
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:reward_points_amount, greater_than: 0)
    |> foreign_key_constraint(:campaign_id)
    |> foreign_key_constraint(:criterion_id)
    |> unique_constraint([:campaign_id, :criterion_id])
    |> put_uuid()
  end

  defp put_uuid(changeset) do
    case get_field(changeset, :id) do
      nil -> put_change(changeset, :id, Uniq.UUID.uuid7())
      _ -> changeset
    end
  end
end
