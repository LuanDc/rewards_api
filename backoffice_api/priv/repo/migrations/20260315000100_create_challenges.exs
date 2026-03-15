defmodule BackofficeApi.Repo.Migrations.CreateChallenges do
  use Ecto.Migration

  def change do
    create table(:challenges, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:external_id, :string, null: false)
      add(:name, :string, null: false)
      add(:description, :text)
      add(:metadata, :map)

      timestamps(type: :utc_datetime)
    end

    create(unique_index(:challenges, [:external_id]))
  end
end
