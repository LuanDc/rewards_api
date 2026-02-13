defmodule CampaignsApi.Tenants.TenantTest do
  use CampaignsApi.DataCase

  alias CampaignsApi.Tenants
  alias CampaignsApi.Tenants.Tenant

  describe "create_tenant/2" do
    test "creates tenant with explicit name from JWT claim" do
      tenant_id = "tenant-#{System.unique_integer([:positive])}"
      attrs = %{name: "Acme Corporation"}

      assert {:ok, %Tenant{} = tenant} = Tenants.create_tenant(tenant_id, attrs)
      assert tenant.id == tenant_id
      assert tenant.name == "Acme Corporation"
      assert tenant.status == :active
    end

    test "creates tenant with fallback to tenant_id as name" do
      tenant_id = "tenant-#{System.unique_integer([:positive])}"

      assert {:ok, %Tenant{} = tenant} = Tenants.create_tenant(tenant_id)
      assert tenant.id == tenant_id
      assert tenant.name == tenant_id
      assert tenant.status == :active
    end
  end

  describe "get_tenant/1" do
    test "loads existing tenant" do
      tenant_id = "tenant-#{System.unique_integer([:positive])}"
      {:ok, created_tenant} = Tenants.create_tenant(tenant_id, %{name: "Test Tenant"})

      loaded_tenant = Tenants.get_tenant(tenant_id)

      assert loaded_tenant != nil
      assert loaded_tenant.id == created_tenant.id
      assert loaded_tenant.name == created_tenant.name
      assert loaded_tenant.status == created_tenant.status
    end

    test "returns nil for non-existent tenant" do
      assert Tenants.get_tenant("non-existent-tenant") == nil
    end
  end

  describe "tenant_active?/1" do
    test "returns true for active tenant" do
      tenant = %Tenant{status: :active}
      assert Tenants.tenant_active?(tenant) == true
    end

    test "returns false for suspended tenant" do
      tenant = %Tenant{status: :suspended}
      assert Tenants.tenant_active?(tenant) == false
    end

    test "returns false for deleted tenant" do
      tenant = %Tenant{status: :deleted}
      assert Tenants.tenant_active?(tenant) == false
    end
  end
end
