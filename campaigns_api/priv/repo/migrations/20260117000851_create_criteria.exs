defmodule CampaignsApi.Repo.Migrations.CreateCriteria do
  use Ecto.Migration

  def change do
    create table(:criteria, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :name, :string, null: false
      add :status, :string, null: false, default: "active"
      add :description, :text

      timestamps(type: :utc_datetime)
    end

    create index(:criteria, [:status])
    create unique_index(:criteria, [:name])
  end
end
