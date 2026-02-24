defmodule CampaignsApi.Repo.Migrations.CreateParticipants do
  use Ecto.Migration

  def change do
    create table(:participants, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:name, :string, null: false)
      add(:nickname, :string, null: false)
      add(:product_id, references(:products, type: :string, on_delete: :delete_all), null: false)
      add(:status, :string, null: false, default: "active")

      timestamps(type: :utc_datetime)
    end

    create(unique_index(:participants, [:nickname]))
    create(index(:participants, [:product_id]))
    create(index(:participants, [:status]))
    create(index(:participants, [:inserted_at]))
  end
end
