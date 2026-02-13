defmodule CampaignsApi.TenantsTest do
  use CampaignsApi.DataCase

  alias CampaignsApi.Tenants
  alias CampaignsApi.Tenants.Tenant

  describe "get_tenant/1" do
    test "returns tenant when it exists" do
      # Create a tenant
      {:ok, tenant} = Tenants.create_tenant("test-tenant-1", %{name: "Test Tenant"})

      # Get the tenant
      result = Tenants.get_tenant("test-tenant-1")

      assert result.id == tenant.id
      assert result.name == "Test Tenant"
    end

    test "returns nil when tenant does not exist" do
      result = Tenants.get_tenant("non-existent-tenant")
      assert result == nil
    end
  end

  describe "create_tenant/2" do
    test "creates tenant with provided name" do
      {:ok, tenant} = Tenants.create_tenant("tenant-123", %{name: "Acme Corp"})

      assert tenant.id == "tenant-123"
      assert tenant.name == "Acme Corp"
      assert tenant.status == :active
      assert tenant.deleted_at == nil
    end

    test "creates tenant with tenant_id as name when name not provided" do
      {:ok, tenant} = Tenants.create_tenant("tenant-456")

      assert tenant.id == "tenant-456"
      assert tenant.name == "tenant-456"
      assert tenant.status == :active
    end

    test "creates tenant with default status active" do
      {:ok, tenant} = Tenants.create_tenant("tenant-789", %{name: "Test"})

      assert tenant.status == :active
    end

    test "returns error for invalid tenant_id" do
      {:error, changeset} = Tenants.create_tenant("", %{name: "Test"})

      assert changeset.valid? == false
      assert "can't be blank" in errors_on(changeset).id
    end

    test "returns error for invalid name" do
      {:error, changeset} = Tenants.create_tenant("tenant-999", %{name: ""})

      assert changeset.valid? == false
      assert "can't be blank" in errors_on(changeset).name
    end
  end

  describe "get_or_create_tenant/1" do
    test "returns existing tenant when it exists" do
      # Create a tenant
      {:ok, existing_tenant} = Tenants.create_tenant("existing-tenant", %{name: "Existing"})

      # Get or create should return the existing tenant
      {:ok, tenant} = Tenants.get_or_create_tenant("existing-tenant")

      assert tenant.id == existing_tenant.id
      assert tenant.name == "Existing"
      assert tenant.inserted_at == existing_tenant.inserted_at
    end

    test "creates new tenant when it does not exist" do
      # Ensure tenant doesn't exist
      assert Tenants.get_tenant("new-tenant") == nil

      # Get or create should create a new tenant
      {:ok, tenant} = Tenants.get_or_create_tenant("new-tenant")

      assert tenant.id == "new-tenant"
      assert tenant.name == "new-tenant"
      assert tenant.status == :active
    end

    test "multiple calls with same tenant_id do not create duplicates" do
      # First call creates the tenant
      {:ok, tenant1} = Tenants.get_or_create_tenant("idempotent-tenant")

      # Second call returns the same tenant
      {:ok, tenant2} = Tenants.get_or_create_tenant("idempotent-tenant")

      assert tenant1.id == tenant2.id
      assert tenant1.inserted_at == tenant2.inserted_at
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
