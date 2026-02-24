defmodule CampaignsApi.Repo.Migrations.CreateParticipantChallenges do
  use Ecto.Migration

  def change do
    create table(:participant_challenges, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :participant_id, references(:participants, type: :binary_id, on_delete: :delete_all), null: false
      add :challenge_id, references(:challenges, type: :binary_id, on_delete: :delete_all), null: false
      add :campaign_id, references(:campaigns, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:participant_challenges, [:participant_id, :challenge_id])
    create index(:participant_challenges, [:participant_id])
    create index(:participant_challenges, [:challenge_id])
    create index(:participant_challenges, [:campaign_id])
    create index(:participant_challenges, [:inserted_at])
  end
end
