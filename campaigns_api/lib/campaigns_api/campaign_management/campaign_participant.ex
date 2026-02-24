defmodule CampaignsApi.CampaignManagement.CampaignParticipant do
  @moduledoc """
  Schema for participant-campaign associations.

  Represents the N:N relationship between participants and campaigns,
  enabling participants to be enrolled in multiple campaigns and campaigns
  to have multiple participants.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          participant_id: Ecto.UUID.t(),
          campaign_id: Ecto.UUID.t(),
          participant: CampaignsApi.CampaignManagement.Participant.t()
                       | Ecto.Association.NotLoaded.t(),
          campaign: CampaignsApi.CampaignManagement.Campaign.t()
                    | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @derive {Jason.Encoder,
           only: [
             :id,
             :participant_id,
             :campaign_id,
             :inserted_at,
             :updated_at
           ]}

  schema "campaign_participants" do
    belongs_to :participant, CampaignsApi.CampaignManagement.Participant
    belongs_to :campaign, CampaignsApi.CampaignManagement.Campaign

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t() | Ecto.Changeset.t() | %__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(campaign_participant, attrs) do
    campaign_participant
    |> cast(attrs, [:participant_id, :campaign_id])
    |> validate_required([:participant_id, :campaign_id])
    |> unique_constraint([:participant_id, :campaign_id],
      name: :campaign_participants_participant_id_campaign_id_index
    )
    |> foreign_key_constraint(:participant_id)
    |> foreign_key_constraint(:campaign_id)
  end
end
