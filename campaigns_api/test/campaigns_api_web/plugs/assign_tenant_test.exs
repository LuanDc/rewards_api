defmodule CampaignsApiWeb.Plugs.AssignTenantTest do
  use CampaignsApiWeb.ConnCase, async: true

  alias CampaignsApi.Tenants
  alias CampaignsApi.Tenants.Tenant
  alias CampaignsApiWeb.Plugs.AssignTenant

  describe "AssignTenant plug" do
    test "creates new tenant on first access (JIT provisioning)", %{conn: conn} do
      tenant_id = "new-tenant-#{System.unique_integer([:positive])}"

      # Verify tenant doesn't exist yet
      assert Tenants.get_tenant(tenant_id) == nil

      conn =
        conn
        |> assign(:tenant_id, tenant_id)
        |> AssignTenant.call(%{})

      # Verify tenant was created and assigned to conn
      assert %Tenant{} = conn.assigns.tenant
      assert conn.assigns.tenant.id == tenant_id
      assert conn.assigns.tenant.name == tenant_id
      assert conn.assigns.tenant.status == :active
      refute conn.halted

      # Verify tenant now exists in database
      assert %Tenant{} = Tenants.get_tenant(tenant_id)
    end

    test "loads existing tenant on subsequent access", %{conn: conn} do
      # Create a tenant first
      tenant_id = "existing-tenant-#{System.unique_integer([:positive])}"
      {:ok, existing_tenant} = Tenants.create_tenant(tenant_id, %{name: "Existing Corp"})

      conn =
        conn
        |> assign(:tenant_id, tenant_id)
        |> AssignTenant.call(%{})

      # Verify existing tenant was loaded
      assert conn.assigns.tenant.id == existing_tenant.id
      assert conn.assigns.tenant.name == "Existing Corp"
      assert conn.assigns.tenant.status == :active
      refute conn.halted
    end

    test "returns 403 when tenant status is deleted", %{conn: conn} do
      # Create a deleted tenant
      tenant_id = "deleted-tenant-#{System.unique_integer([:positive])}"
      {:ok, _tenant} = Tenants.create_tenant(tenant_id, %{status: :deleted})

      conn =
        conn
        |> assign(:tenant_id, tenant_id)
        |> AssignTenant.call(%{})

      assert conn.status == 403
      assert conn.halted
      assert json_response(conn, 403) == %{"error" => "Tenant access denied"}
    end

    test "returns 403 when tenant status is suspended", %{conn: conn} do
      # Create a suspended tenant
      tenant_id = "suspended-tenant-#{System.unique_integer([:positive])}"
      {:ok, _tenant} = Tenants.create_tenant(tenant_id, %{status: :suspended})

      conn =
        conn
        |> assign(:tenant_id, tenant_id)
        |> AssignTenant.call(%{})

      assert conn.status == 403
      assert conn.halted
      assert json_response(conn, 403) == %{"error" => "Tenant access denied"}
    end

    test "assigns active tenant to conn", %{conn: conn} do
      # Create an active tenant
      tenant_id = "active-tenant-#{System.unique_integer([:positive])}"
      {:ok, tenant} = Tenants.create_tenant(tenant_id, %{status: :active})

      conn =
        conn
        |> assign(:tenant_id, tenant_id)
        |> AssignTenant.call(%{})

      # Verify tenant was assigned and request was not halted
      assert conn.assigns.tenant.id == tenant.id
      assert conn.assigns.tenant.status == :active
      refute conn.halted
    end
  end
end
