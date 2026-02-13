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

  Returns the tenant struct or nil if not found.

  ## Examples

      iex> get_tenant("tenant-123")
      %Tenant{}

      iex> get_tenant("non-existent")
      nil

  """
  @spec get_tenant(tenant_id()) :: Tenant.t() | nil
  def get_tenant(tenant_id) do
    Repo.get(Tenant, tenant_id)
  end

  @doc """
  Creates a new tenant with JIT provisioning.

  ## Parameters

    - tenant_id: The unique identifier for the tenant
    - attrs: Optional attributes map (can include :name)

  If no name is provided in attrs, the tenant_id will be used as the name.

  ## Examples

      iex> create_tenant("tenant-123", %{name: "Acme Corp"})
      {:ok, %Tenant{}}

      iex> create_tenant("tenant-456")
      {:ok, %Tenant{name: "tenant-456"}}

      iex> create_tenant("", %{})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_tenant(tenant_id(), attrs()) :: {:ok, Tenant.t()} | {:error, Ecto.Changeset.t()}
  def create_tenant(tenant_id, attrs \\ %{}) do
    # Merge tenant_id and default name with provided attrs
    default_attrs = %{id: tenant_id, name: tenant_id}
    merged_attrs = Map.merge(default_attrs, attrs)

    %Tenant{}
    |> Tenant.changeset(merged_attrs)
    |> Repo.insert()
  end

  @doc """
  Gets an existing tenant or creates a new one (JIT provisioning).

  This function implements Just-in-Time provisioning by automatically creating
  a tenant record on first access if it doesn't exist.

  ## Examples

      iex> get_or_create_tenant("existing-tenant")
      {:ok, %Tenant{}}

      iex> get_or_create_tenant("new-tenant")
      {:ok, %Tenant{id: "new-tenant", name: "new-tenant", status: :active}}

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

  Returns true only if the tenant status is :active.
  Returns false for :suspended or :deleted tenants.

  ## Examples

      iex> tenant_active?(%Tenant{status: :active})
      true

      iex> tenant_active?(%Tenant{status: :suspended})
      false

      iex> tenant_active?(%Tenant{status: :deleted})
      false

  """
  @spec tenant_active?(Tenant.t()) :: boolean()
  def tenant_active?(%Tenant{status: :active}), do: true
  def tenant_active?(_), do: false
end
