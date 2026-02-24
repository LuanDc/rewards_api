defmodule CampaignsApi.Products.Product do
  @moduledoc """
  product schema representing a client organization in the multi-product system.

  products can have three statuses:
  - `:active` - product can access the API
  - `:suspended` - product access is temporarily disabled
  - `:deleted` - product is soft-deleted
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          status: :active | :suspended | :deleted,
          deleted_at: DateTime.t() | nil,
          campaigns:
            [CampaignsApi.CampaignManagement.Campaign.t()] | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @primary_key {:id, :string, autogenerate: false}
  @derive {Jason.Encoder, only: [:id, :name, :status, :inserted_at, :updated_at]}

  schema "products" do
    field(:name, :string)
    field(:status, Ecto.Enum, values: [:active, :suspended, :deleted], default: :active)
    field(:deleted_at, :utc_datetime)

    has_many(:campaigns, CampaignsApi.CampaignManagement.Campaign)

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t() | Ecto.Changeset.t() | %__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(product, attrs) do
    product
    |> cast(attrs, [:id, :name, :status, :deleted_at])
    |> validate_required([:id, :name])
    |> validate_length(:name, min: 1)
    |> unique_constraint(:id, name: :products_pkey)
  end
end
