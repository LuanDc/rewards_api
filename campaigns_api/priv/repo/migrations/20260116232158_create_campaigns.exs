defmodule CampaignsApi.Repo.Migrations.CreateCampaigns do
  use Ecto.Migration

  def change do
    create table(:campaigns, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :name, :string, size: 255, null: false
      add :tenant, :string, size: 100, null: false
      add :started_at, :utc_datetime_usec
      add :finished_at, :utc_datetime_usec
      add :status, :string, size: 50, null: false, default: "not_started"

      timestamps()
    end

    create index(:campaigns, [:tenant])
    create index(:campaigns, [:status])
  end
end
