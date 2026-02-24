defmodule CampaignsApi.Repo.Migrations.CreateCampaigns do
  use Ecto.Migration

  def change do
    create table(:campaigns, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:product_id, references(:products, type: :string, on_delete: :restrict), null: false)
      add(:name, :string, null: false)
      add(:description, :text)
      add(:start_time, :utc_datetime)
      add(:end_time, :utc_datetime)
      add(:status, :string, null: false, default: "active")

      timestamps(type: :utc_datetime)
    end

    create(index(:campaigns, [:product_id, :id]))
    create(index(:campaigns, [:product_id, :inserted_at]))
  end
end
