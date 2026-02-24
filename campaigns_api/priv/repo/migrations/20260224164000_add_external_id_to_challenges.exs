defmodule CampaignsApi.Repo.Migrations.AddExternalIdToChallenges do
  use Ecto.Migration

  def up do
    alter table(:challenges) do
      add :external_id, :string
    end

    execute("UPDATE challenges SET external_id = id WHERE external_id IS NULL")

    alter table(:challenges) do
      modify :external_id, :string, null: false
    end

    create unique_index(:challenges, [:external_id])
  end

  def down do
    drop_if_exists unique_index(:challenges, [:external_id])

    alter table(:challenges) do
      remove :external_id
    end
  end
end
