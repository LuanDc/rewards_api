defmodule ChallengesScheduler.CampaignCalendars.ChallengeSchedule do
  @moduledoc """
  Projection row representing a scheduled challenge within a campaign calendar.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias ChallengesScheduler.CampaignCalendars.CampaignCalendar

  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          product_id: String.t(),
          campaign_id: Ecto.UUID.t(),
          challenge_id: Ecto.UUID.t(),
          display_name: String.t(),
          display_description: String.t() | nil,
          evaluation_frequency: String.t(),
          reward_points: integer(),
          configuration: map() | nil,
          campaign_calendar: CampaignCalendar.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @primary_key {:id, :binary_id, autogenerate: false}
  @foreign_key_type :binary_id

  schema "challenge_schedules" do
    field(:product_id, :string)
    field(:challenge_id, :binary_id)
    field(:display_name, :string)
    field(:display_description, :string)
    field(:evaluation_frequency, :string)
    field(:reward_points, :integer)
    field(:configuration, :map)

    belongs_to(:campaign_calendar, CampaignCalendar,
      foreign_key: :campaign_id,
      references: :id,
      type: :binary_id
    )

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(challenge_schedule, attrs) do
    challenge_schedule
    |> cast(attrs, [
      :id,
      :product_id,
      :campaign_id,
      :challenge_id,
      :display_name,
      :display_description,
      :evaluation_frequency,
      :reward_points,
      :configuration
    ])
    |> validate_required([
      :id,
      :product_id,
      :campaign_id,
      :challenge_id,
      :display_name,
      :evaluation_frequency,
      :reward_points
    ])
    |> validate_length(:display_name, min: 3)
    |> foreign_key_constraint(:campaign_id)
  end
end
