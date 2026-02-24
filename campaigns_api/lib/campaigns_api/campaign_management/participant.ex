defmodule CampaignsApi.CampaignManagement.Participant do
  @moduledoc """
  Participant schema representing an individual who can participate in campaigns and challenges.

  Participants belong to a tenant and can be associated with multiple campaigns and challenges.
  Each participant has a unique nickname across all participants in the system.

  Status can be:
  - `:active` - Participant can participate in campaigns
  - `:inactive` - Participant is temporarily disabled
  - `:ineligible` - Participant is not eligible to participate
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          name: String.t(),
          nickname: String.t(),
          tenant_id: String.t(),
          status: :active | :inactive | :ineligible,
          tenant: CampaignsApi.Tenants.Tenant.t() | Ecto.Association.NotLoaded.t(),
          campaign_participants:
            [CampaignsApi.CampaignManagement.CampaignParticipant.t()]
            | Ecto.Association.NotLoaded.t(),
          participant_challenges:
            [CampaignsApi.CampaignManagement.ParticipantChallenge.t()]
            | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :string
  @derive {Jason.Encoder,
           only: [:id, :name, :nickname, :tenant_id, :status, :inserted_at, :updated_at]}

  schema "participants" do
    field :name, :string
    field :nickname, :string
    field :status, Ecto.Enum, values: [:active, :inactive, :ineligible], default: :active

    belongs_to :tenant, CampaignsApi.Tenants.Tenant, type: :string

    has_many :campaign_participants, CampaignsApi.CampaignManagement.CampaignParticipant
    has_many :participant_challenges, CampaignsApi.CampaignManagement.ParticipantChallenge

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t() | Ecto.Changeset.t() | %__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(participant, attrs) do
    participant
    |> cast(attrs, [:tenant_id, :name, :nickname, :status])
    |> validate_required([:tenant_id, :name, :nickname])
    |> validate_length(:name, min: 1)
    |> validate_length(:nickname, min: 3)
    |> unique_constraint(:nickname)
    |> foreign_key_constraint(:tenant_id)
  end
end
