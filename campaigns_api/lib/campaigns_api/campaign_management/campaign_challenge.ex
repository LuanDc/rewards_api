defmodule CampaignsApi.CampaignManagement.CampaignChallenge do
  @moduledoc """
  Schema for challenge-campaign associations with configuration.

  Represents the N:N relationship between challenges and campaigns,
  storing campaign-specific configuration including evaluation frequency,
  reward points, and marketing-friendly display information.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          campaign_id: Ecto.UUID.t(),
          challenge_id: Ecto.UUID.t(),
          display_name: String.t(),
          display_description: String.t() | nil,
          evaluation_frequency: String.t(),
          reward_points: integer(),
          configuration: map() | nil,
          campaign:
            CampaignsApi.CampaignManagement.Campaign.t()
            | Ecto.Association.NotLoaded.t(),
          challenge: CampaignsApi.Challenges.Challenge.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @derive {Jason.Encoder,
           only: [
             :id,
             :campaign_id,
             :challenge_id,
             :display_name,
             :display_description,
             :evaluation_frequency,
             :reward_points,
             :configuration,
             :inserted_at,
             :updated_at
           ]}

  @frequency_keywords ~w(daily weekly monthly on_event)

  schema "campaign_challenges" do
    field(:display_name, :string)
    field(:display_description, :string)
    field(:evaluation_frequency, :string)
    field(:reward_points, :integer)
    field(:configuration, :map)

    belongs_to(:campaign, CampaignsApi.CampaignManagement.Campaign)
    belongs_to(:challenge, CampaignsApi.Challenges.Challenge)

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t() | Ecto.Changeset.t() | %__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(campaign_challenge, attrs) do
    campaign_challenge
    |> cast(attrs, [
      :campaign_id,
      :challenge_id,
      :display_name,
      :display_description,
      :evaluation_frequency,
      :reward_points,
      :configuration
    ])
    |> validate_required([
      :campaign_id,
      :challenge_id,
      :display_name,
      :evaluation_frequency,
      :reward_points
    ])
    |> validate_length(:display_name, min: 3)
    |> validate_evaluation_frequency()
    |> validate_number(:reward_points, message: "must be an integer")
    |> unique_constraint([:campaign_id, :challenge_id],
      name: :campaign_challenges_campaign_id_challenge_id_index
    )
    |> foreign_key_constraint(:campaign_id)
    |> foreign_key_constraint(:challenge_id)
  end

  @spec validate_evaluation_frequency(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  defp validate_evaluation_frequency(changeset) do
    frequency = get_field(changeset, :evaluation_frequency)

    cond do
      is_nil(frequency) ->
        changeset

      frequency in @frequency_keywords ->
        changeset

      valid_cron_expression?(frequency) ->
        changeset

      true ->
        add_error(
          changeset,
          :evaluation_frequency,
          "must be a valid cron expression or one of: #{Enum.join(@frequency_keywords, ", ")}"
        )
    end
  end

  @spec valid_cron_expression?(String.t()) :: boolean()
  defp valid_cron_expression?(expression) do
    parts = String.split(expression, " ")
    length(parts) == 5
  end
end
