defmodule CampaignsApi.Repo.Migrations.CreateCampaignCriteria do
  use Ecto.Migration

  def change do
    create table(:campaign_criteria, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :campaign_id, references(:campaigns, type: :uuid, on_delete: :delete_all), null: false
      add :criterion_id, references(:criteria, type: :uuid, on_delete: :delete_all), null: false
      add :periodicity, :string
      add :status, :string, null: false, default: "active"
      add :reward_points_amount, :integer, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:campaign_criteria, [:campaign_id])
    create index(:campaign_criteria, [:criterion_id])
    create index(:campaign_criteria, [:status])
    create unique_index(:campaign_criteria, [:campaign_id, :criterion_id])
  end
end
