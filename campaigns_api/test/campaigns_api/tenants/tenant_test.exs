defmodule CampaignsApi.Tenants.TenantTest do
  use CampaignsApi.DataCase
  use ExUnitProperties

  alias CampaignsApi.Repo
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

  describe "Property: Tenant Record Fields" do
    @tag :property
    property "any tenant record contains all required fields" do
      check all(
              tenant_id <- string(:alphanumeric, min_length: 1, max_length: 50),
              name <- string(:alphanumeric, min_length: 1, max_length: 100),
              status <- member_of([:active, :suspended, :deleted]),
              deleted_at <- one_of([constant(nil), datetime_generator()]),
              max_runs: 50
            ) do
        attrs = %{
          id: tenant_id,
          name: name,
          status: status,
          deleted_at: deleted_at
        }

        changeset = Tenant.changeset(%Tenant{}, attrs)

        if changeset.valid? do
          case Repo.insert(changeset) do
            {:ok, tenant} ->
              assert tenant.id != nil
              assert tenant.name != nil
              assert tenant.status != nil
              assert tenant.inserted_at != nil
              assert tenant.updated_at != nil
              assert is_nil(tenant.deleted_at) or match?(%DateTime{}, tenant.deleted_at)

              retrieved_tenant = Repo.get(Tenant, tenant.id)
              assert retrieved_tenant != nil
              assert retrieved_tenant.id == tenant.id
              assert retrieved_tenant.name == tenant.name
              assert retrieved_tenant.status == tenant.status
              assert retrieved_tenant.deleted_at == tenant.deleted_at
              assert retrieved_tenant.inserted_at != nil
              assert retrieved_tenant.updated_at != nil

            {:error, _changeset} ->
              :ok
          end
        end
      end
    end

    defp datetime_generator do
      gen all(
            year <- integer(2020..2030),
            month <- integer(1..12),
            day <- integer(1..28),
            hour <- integer(0..23),
            minute <- integer(0..59),
            second <- integer(0..59)
          ) do
        {:ok, dt} = DateTime.new(Date.new!(year, month, day), Time.new!(hour, minute, second))
        DateTime.truncate(dt, :second)
      end
    end
  end
end
