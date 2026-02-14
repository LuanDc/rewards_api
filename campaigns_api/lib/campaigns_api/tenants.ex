defmodule CampaignsApi.Tenants do
  @moduledoc """
  The Tenants context manages tenant lifecycle, status checks, and JIT provisioning.
  """

  alias CampaignsApi.Repo
  alias CampaignsApi.Tenants.Tenant

  @type tenant_id :: String.t()
  @type attrs :: map()

  @doc """
  Gets a tenant by ID.
  """
  @spec get_tenant(tenant_id()) :: Tenant.t() | nil
  def get_tenant(tenant_id) do
    Repo.get(Tenant, tenant_id)
  end

  @doc """
  Creates a new tenant with JIT provisioning.
  """
  @spec create_tenant(tenant_id(), attrs()) :: {:ok, Tenant.t()} | {:error, Ecto.Changeset.t()}
  def create_tenant(tenant_id, attrs \\ %{}) do
    default_attrs = %{id: tenant_id, name: tenant_id}
    merged_attrs = Map.merge(default_attrs, attrs)

    %Tenant{}
    |> Tenant.changeset(merged_attrs)
    |> Repo.insert()
  end

  @doc """
  Gets an existing tenant or creates a new one (JIT provisioning).
  """
  @spec get_or_create_tenant(tenant_id()) :: {:ok, Tenant.t()}
  def get_or_create_tenant(tenant_id) do
    case get_tenant(tenant_id) do
      nil -> create_tenant(tenant_id)
      tenant -> {:ok, tenant}
    end
  end

  @doc """
  Checks if a tenant can access the API.
  """
  @spec tenant_active?(Tenant.t()) :: boolean()
  def tenant_active?(%Tenant{status: :active}), do: true
  def tenant_active?(_), do: false
end
