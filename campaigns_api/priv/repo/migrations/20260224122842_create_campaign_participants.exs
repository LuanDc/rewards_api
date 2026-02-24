defmodule CampaignsApi.Repo.Migrations.CreateCampaignParticipants do
  use Ecto.Migration

  def change do
    create table(:campaign_participants, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :participant_id, references(:participants, type: :binary_id, on_delete: :delete_all), null: false
      add :campaign_id, references(:campaigns, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:campaign_participants, [:participant_id, :campaign_id])
    create index(:campaign_participants, [:participant_id])
    create index(:campaign_participants, [:campaign_id])
    create index(:campaign_participants, [:inserted_at])
  end
end
