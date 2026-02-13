defmodule CampaignsApi.Repo.Migrations.CreateTenants do
  use Ecto.Migration

  def change do
    create table(:tenants, primary_key: false) do
      add :id, :string, primary_key: true
      add :name, :string, null: false
      add :status, :string, null: false, default: "active"
      add :deleted_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:tenants, [:status])
  end
end
