defmodule CampaignsApi.Repo.Migrations.CreateCampaignChallenges do
  use Ecto.Migration

  def change do
    create table(:campaign_challenges, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :campaign_id, references(:campaigns, type: :binary_id, on_delete: :delete_all),
        null: false

      add :challenge_id, references(:challenges, type: :binary_id, on_delete: :restrict),
        null: false

      add :display_name, :string, null: false
      add :display_description, :text
      add :evaluation_frequency, :string, null: false
      add :reward_points, :integer, null: false
      add :configuration, :jsonb

      timestamps(type: :utc_datetime)
    end

    create unique_index(:campaign_challenges, [:campaign_id, :challenge_id])
  end
end
