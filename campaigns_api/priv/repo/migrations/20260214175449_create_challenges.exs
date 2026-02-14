defmodule CampaignsApi.Repo.Migrations.CreateChallenges do
  use Ecto.Migration

  def change do
    create table(:challenges, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :text
      add :metadata, :jsonb

      timestamps(type: :utc_datetime)
    end

    create index(:challenges, [:id])
  end
end
