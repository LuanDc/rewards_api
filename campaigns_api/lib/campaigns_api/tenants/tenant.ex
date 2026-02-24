defmodule CampaignsApi.Tenants.Tenant do
  @moduledoc """
  Tenant schema representing a client organization in the multi-tenant system.

  Tenants can have three statuses:
  - `:active` - Tenant can access the API
  - `:suspended` - Tenant access is temporarily disabled
  - `:deleted` - Tenant is soft-deleted
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

  schema "tenants" do
    field :name, :string
    field :status, Ecto.Enum, values: [:active, :suspended, :deleted], default: :active
    field :deleted_at, :utc_datetime

    has_many :campaigns, CampaignsApi.CampaignManagement.Campaign

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t() | Ecto.Changeset.t() | %__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(tenant, attrs) do
    tenant
    |> cast(attrs, [:id, :name, :status, :deleted_at])
    |> validate_required([:id, :name])
    |> validate_length(:name, min: 1)
    |> unique_constraint(:id, name: :tenants_pkey)
  end
end
