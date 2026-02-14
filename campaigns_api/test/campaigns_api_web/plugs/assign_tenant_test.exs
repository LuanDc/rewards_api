defmodule CampaignsApiWeb.Plugs.AssignTenantTest do
  use CampaignsApiWeb.ConnCase, async: true

  alias CampaignsApi.Tenants
  alias CampaignsApi.Tenants.Tenant
  alias CampaignsApiWeb.Plugs.AssignTenant

  describe "AssignTenant plug" do
    test "creates new tenant on first access (JIT provisioning)", %{conn: conn} do
      tenant_id = "new-tenant-#{System.unique_integer([:positive])}"

      assert Tenants.get_tenant(tenant_id) == nil

      conn =
        conn
        |> assign(:tenant_id, tenant_id)
        |> AssignTenant.call(%{})

      assert %Tenant{} = conn.assigns.tenant
      assert conn.assigns.tenant.id == tenant_id
      assert conn.assigns.tenant.name == tenant_id
      assert conn.assigns.tenant.status == :active
      refute conn.halted

      assert %Tenant{} = Tenants.get_tenant(tenant_id)
    end

    test "loads existing tenant on subsequent access", %{conn: conn} do
      existing_tenant = insert(:tenant, name: "Existing Corp")

      conn =
        conn
        |> assign(:tenant_id, existing_tenant.id)
        |> AssignTenant.call(%{})

      assert conn.assigns.tenant.id == existing_tenant.id
      assert conn.assigns.tenant.name == "Existing Corp"
      assert conn.assigns.tenant.status == :active
      refute conn.halted
    end

    test "returns 403 when tenant status is deleted", %{conn: conn} do
      deleted_tenant = insert(:deleted_tenant)

      conn =
        conn
        |> assign(:tenant_id, deleted_tenant.id)
        |> AssignTenant.call(%{})

      assert conn.status == 403
      assert conn.halted
      assert json_response(conn, 403) == %{"error" => "Tenant access denied"}
    end

    test "returns 403 when tenant status is suspended", %{conn: conn} do
      suspended_tenant = insert(:suspended_tenant)

      conn =
        conn
        |> assign(:tenant_id, suspended_tenant.id)
        |> AssignTenant.call(%{})

      assert conn.status == 403
      assert conn.halted
      assert json_response(conn, 403) == %{"error" => "Tenant access denied"}
    end

    test "assigns active tenant to conn", %{conn: conn} do
      tenant = insert(:tenant, status: :active)

      conn =
        conn
        |> assign(:tenant_id, tenant.id)
        |> AssignTenant.call(%{})

      assert conn.assigns.tenant.id == tenant.id
      assert conn.assigns.tenant.status == :active
      refute conn.halted
    end
  end
end
