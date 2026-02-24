defmodule CampaignsApi.ParticipantManagement.ParticipantChallenge do
  @moduledoc """
  Schema for participant-challenge associations with campaign context.

  Represents the N:N relationship between participants and challenges,
  maintaining campaign context to ensure participants can only be assigned
  to challenges within campaigns they are enrolled in.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          participant_id: Ecto.UUID.t(),
          challenge_id: Ecto.UUID.t(),
          campaign_id: Ecto.UUID.t(),
          participant: CampaignsApi.ParticipantManagement.Participant.t()
                       | Ecto.Association.NotLoaded.t(),
          challenge: CampaignsApi.Challenges.Challenge.t()
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
             :challenge_id,
             :campaign_id,
             :inserted_at,
             :updated_at
           ]}

  schema "participant_challenges" do
    belongs_to :participant, CampaignsApi.ParticipantManagement.Participant
    belongs_to :challenge, CampaignsApi.Challenges.Challenge
    belongs_to :campaign, CampaignsApi.CampaignManagement.Campaign

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t() | Ecto.Changeset.t() | %__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(participant_challenge, attrs) do
    participant_challenge
    |> cast(attrs, [:participant_id, :challenge_id, :campaign_id])
    |> validate_required([:participant_id, :challenge_id, :campaign_id])
    |> unique_constraint([:participant_id, :challenge_id],
      name: :participant_challenges_participant_id_challenge_id_index
    )
    |> foreign_key_constraint(:participant_id)
    |> foreign_key_constraint(:challenge_id)
    |> foreign_key_constraint(:campaign_id)
  end
end
