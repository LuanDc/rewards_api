defmodule CampaignsApi.TenantsTest do
  use CampaignsApi.DataCase
  use ExUnitProperties

  alias CampaignsApi.Tenants

  describe "get_tenant/1" do
    test "returns tenant when it exists" do
      tenant = insert(:tenant)
      result = Tenants.get_tenant(tenant.id)

      assert result.id == tenant.id
      assert result.name == tenant.name
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
      existing_tenant = insert(:tenant)
      {:ok, tenant} = Tenants.get_or_create_tenant(existing_tenant.id)

      assert tenant.id == existing_tenant.id
      assert tenant.name == existing_tenant.name
      assert tenant.inserted_at == existing_tenant.inserted_at
    end

    test "creates new tenant when it does not exist" do
      assert Tenants.get_tenant("new-tenant") == nil
      {:ok, tenant} = Tenants.get_or_create_tenant("new-tenant")

      assert tenant.id == "new-tenant"
      assert tenant.name == "new-tenant"
      assert tenant.status == :active
    end

    test "multiple calls with same tenant_id do not create duplicates" do
      {:ok, tenant1} = Tenants.get_or_create_tenant("idempotent-tenant")
      {:ok, tenant2} = Tenants.get_or_create_tenant("idempotent-tenant")

      assert tenant1.id == tenant2.id
      assert tenant1.inserted_at == tenant2.inserted_at
    end
  end

  describe "tenant_active?/1" do
    test "returns true for active tenant" do
      tenant = build(:tenant, status: :active)
      assert Tenants.tenant_active?(tenant) == true
    end

    test "returns false for suspended tenant" do
      tenant = build(:suspended_tenant)
      assert Tenants.tenant_active?(tenant) == false
    end

    test "returns false for deleted tenant" do
      tenant = build(:deleted_tenant)
      assert Tenants.tenant_active?(tenant) == false
    end
  end

  describe "Properties: Tenant Creation and Status Validation (Business Invariants)" do
    @tag :property
    property "tenant creation with new tenant_id creates active tenant" do
      check all(
              tenant_id <- string(:alphanumeric, min_length: 5, max_length: 30),
              max_runs: 50
            ) do
        tenant_id = "tenant-#{tenant_id}"

        {:ok, tenant} = Tenants.get_or_create_tenant(tenant_id)

        assert tenant.id == tenant_id
        assert tenant.status == :active
        assert tenant.name == tenant_id
        assert tenant.inserted_at != nil
        assert tenant.updated_at != nil
      end
    end

    @tag :property
    property "multiple requests with same tenant_id do not create duplicates" do
      check all(
              tenant_id <- string(:alphanumeric, min_length: 5, max_length: 30),
              request_count <- integer(2..5),
              max_runs: 50
            ) do
        tenant_id = "tenant-#{tenant_id}"

        results =
          Enum.map(1..request_count, fn _ ->
            Tenants.get_or_create_tenant(tenant_id)
          end)

        assert Enum.all?(results, fn result -> match?({:ok, _}, result) end)

        tenants = Enum.map(results, fn {:ok, tenant} -> tenant end)
        assert Enum.all?(tenants, fn t -> t.id == tenant_id end)

        first_inserted_at = hd(tenants).inserted_at
        assert Enum.all?(tenants, fn t -> t.inserted_at == first_inserted_at end)
      end
    end

    @tag :property
    property "tenant status validation - non-active tenants denied access" do
      check all(
              tenant_id <- string(:alphanumeric, min_length: 5, max_length: 30),
              non_active_status <- member_of([:deleted, :suspended]),
              max_runs: 50
            ) do
        tenant_id = "tenant-#{tenant_id}"

        {:ok, tenant} = Tenants.create_tenant(tenant_id, %{status: non_active_status})

        assert Tenants.tenant_active?(tenant) == false

        retrieved_tenant = Tenants.get_tenant(tenant_id)
        assert retrieved_tenant != nil
        assert retrieved_tenant.status == non_active_status
        assert Tenants.tenant_active?(retrieved_tenant) == false
      end
    end
  end
end
