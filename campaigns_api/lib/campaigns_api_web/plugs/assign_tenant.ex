defmodule CampaignsApiWeb.Plugs.AssignTenant do
  @moduledoc """
  Plug for Just-in-Time tenant provisioning and access control.

  This plug:
  - Gets or creates a tenant based on the tenant_id from conn.assigns
  - Checks if the tenant is active
  - Assigns the tenant to conn.assigns if active
  - Returns 403 Forbidden if tenant is not active (suspended or deleted)

  Requires RequireAuth plug to run first to set conn.assigns.tenant_id.
  """

  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]
  alias CampaignsApi.Tenants

  @spec init(keyword()) :: keyword()
  def init(opts), do: opts

  @spec call(Plug.Conn.t(), keyword()) :: Plug.Conn.t()
  def call(conn, _opts) do
    tenant_id = conn.assigns.tenant_id

    {:ok, tenant} = Tenants.get_or_create_tenant(tenant_id)

    if Tenants.tenant_active?(tenant) do
      assign(conn, :tenant, tenant)
    else
      forbidden(conn)
    end
  end

  @spec forbidden(Plug.Conn.t()) :: Plug.Conn.t()
  defp forbidden(conn) do
    conn
    |> put_status(:forbidden)
    |> json(%{error: "Tenant access denied"})
    |> halt()
  end
end
