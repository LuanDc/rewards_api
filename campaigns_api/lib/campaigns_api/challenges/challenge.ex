defmodule CampaignsApi.Challenges.Challenge do
  @moduledoc """
  Schema for reusable challenge evaluation mechanisms.

  Challenges define the technical evaluation logic that can be
  associated with multiple campaigns by any product. The actual evaluation
  implementation will be registered automatically in future iterations.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          name: String.t(),
          description: String.t() | nil,
          metadata: map() | nil,
          campaign_challenges:
            [CampaignsApi.CampaignManagement.CampaignChallenge.t()]
            | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @derive {Jason.Encoder, only: [:id, :name, :description, :metadata, :inserted_at, :updated_at]}

  schema "challenges" do
    field :name, :string
    field :description, :string
    field :metadata, :map

    has_many :campaign_challenges, CampaignsApi.CampaignManagement.CampaignChallenge

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t() | Ecto.Changeset.t() | %__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(challenge, attrs) do
    challenge
    |> cast(attrs, [:name, :description, :metadata])
    |> validate_required([:name])
    |> validate_length(:name, min: 3)
  end
end
