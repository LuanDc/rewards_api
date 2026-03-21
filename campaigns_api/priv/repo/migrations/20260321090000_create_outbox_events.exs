defmodule CampaignsApi.Repo.Migrations.CreateOutboxEvents do
  use Ecto.Migration

  def change do
    create table(:outbox_events, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:aggregate_type, :string, null: false)
      add(:aggregate_id, :string, null: false)
      add(:event_type, :string, null: false)
      add(:payload, :map, null: false)
      add(:occurred_at, :utc_datetime_usec, null: false)

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create(index(:outbox_events, [:aggregate_type, :aggregate_id]))
    create(index(:outbox_events, [:event_type]))
    create(index(:outbox_events, [:inserted_at]))
  end
end
