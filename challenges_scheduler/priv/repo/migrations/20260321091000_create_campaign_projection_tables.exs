defmodule ChallengesScheduler.Repo.Migrations.CreateCampaignProjectionTables do
  use Ecto.Migration

  def change do
    create table(:campaign_calendars, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:product_id, :string, null: false)
      add(:name, :string, null: false)
      add(:description, :text)
      add(:start_time, :utc_datetime)
      add(:end_time, :utc_datetime)
      add(:status, :string, null: false, default: "active")

      timestamps(type: :utc_datetime)
    end

    create table(:challenge_schedules, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:product_id, :string, null: false)

      add(
        :campaign_id,
        references(:campaign_calendars,
          type: :binary_id,
          column: :id,
          on_delete: :delete_all
        ),
        null: false
      )

      add(:challenge_id, :binary_id, null: false)
      add(:display_name, :string, null: false)
      add(:display_description, :text)
      add(:evaluation_frequency, :string, null: false)
      add(:reward_points, :integer, null: false)
      add(:configuration, :map)

      timestamps(type: :utc_datetime)
    end

    create(index(:campaign_calendars, [:product_id]))
    create(index(:challenge_schedules, [:campaign_id]))
    create(index(:challenge_schedules, [:challenge_id]))
    create(index(:challenge_schedules, [:product_id]))
  end
end
