defmodule ChallengesScheduler.CampaignCalendars.CampaignCalendar do
  @moduledoc """
  Projection row representing a campaign calendar in the scheduler database.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias ChallengesScheduler.CampaignCalendars.ChallengeSchedule

  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          product_id: String.t(),
          name: String.t(),
          description: String.t() | nil,
          start_time: DateTime.t() | nil,
          end_time: DateTime.t() | nil,
          status: :active | :paused,
          challenge_schedules: [ChallengeSchedule.t()] | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @primary_key {:id, :binary_id, autogenerate: false}
  @foreign_key_type :binary_id

  schema "campaign_calendars" do
    field(:product_id, :string)
    field(:name, :string)
    field(:description, :string)
    field(:start_time, :utc_datetime)
    field(:end_time, :utc_datetime)
    field(:status, Ecto.Enum, values: [:active, :paused], default: :active)

    has_many(:challenge_schedules, ChallengeSchedule, foreign_key: :campaign_id)

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(campaign_calendar, attrs) do
    campaign_calendar
    |> cast(attrs, [:id, :product_id, :name, :description, :start_time, :end_time, :status])
    |> validate_required([:id, :product_id, :name, :status])
    |> validate_length(:name, min: 3)
  end
end
