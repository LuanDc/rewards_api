defmodule CampaignsApi.TenantsPropertyTest do
  use CampaignsApi.DataCase
  use ExUnitProperties

  import Ecto.Query

  alias CampaignsApi.Repo
  alias CampaignsApi.Tenants
  alias CampaignsApi.Tenants.Tenant

  property "any tenant_id that does not exist creates a new tenant with status active" do
    check all(
            tenant_id <- tenant_id_generator(),
            max_runs: 100
          ) do
      Repo.delete_all(Tenant)

      {:ok, tenant} = Tenants.get_or_create_tenant(tenant_id)

      assert tenant.id == tenant_id, "tenant id should match the provided tenant_id"
      assert tenant.status == :active, "newly created tenant should have status :active"
      assert tenant.name == tenant_id, "tenant name should default to tenant_id"
      assert tenant.inserted_at != nil, "tenant should have inserted_at timestamp"
      assert tenant.updated_at != nil, "tenant should have updated_at timestamp"

      db_tenant = Repo.get(Tenant, tenant_id)
      assert db_tenant != nil, "tenant should be persisted in database"
      assert db_tenant.id == tenant_id
      assert db_tenant.status == :active
    end
  end

  property "multiple requests with same tenant_id do not create duplicate tenants" do
    check all(
            tenant_id <- tenant_id_generator(),
            request_count <- integer(2..10),
            max_runs: 100
          ) do
      Repo.delete_all(Tenant)

      results =
        Enum.map(1..request_count, fn _ ->
          Tenants.get_or_create_tenant(tenant_id)
        end)

      assert Enum.all?(results, fn result -> match?({:ok, _}, result) end),
             "all get_or_create_tenant calls should succeed"

      tenants = Enum.map(results, fn {:ok, tenant} -> tenant end)

      assert Enum.all?(tenants, fn t -> t.id == tenant_id end),
             "all returned tenants should have the same id"

      first_inserted_at = hd(tenants).inserted_at

      assert Enum.all?(tenants, fn t -> t.inserted_at == first_inserted_at end),
             "all tenants should have the same inserted_at timestamp (same record)"

      tenant_count = Repo.aggregate(from(t in Tenant, where: t.id == ^tenant_id), :count)
      assert tenant_count == 1, "only one tenant record should exist in database"
    end
  end

  property "any tenant with status deleted or suspended is denied access" do
    check all(
            tenant_id <- tenant_id_generator(),
            non_active_status <- member_of([:deleted, :suspended]),
            max_runs: 100
          ) do
      Repo.delete_all(from t in Tenant, where: t.id == ^tenant_id)

      {:ok, tenant} = Tenants.create_tenant(tenant_id, %{status: non_active_status})

      assert Tenants.tenant_active?(tenant) == false,
             "tenant with status #{non_active_status} should not be active"

      retrieved_tenant = Tenants.get_tenant(tenant_id)
      assert retrieved_tenant != nil, "tenant should exist in database"
      assert retrieved_tenant.status == non_active_status
      assert Tenants.tenant_active?(retrieved_tenant) == false,
             "retrieved tenant should not be active"
    end
  end

  property "any tenant with status active is allowed access" do
    check all(
            tenant_id <- tenant_id_generator(),
            max_runs: 100
          ) do
      Repo.delete_all(from t in Tenant, where: t.id == ^tenant_id)

      {:ok, tenant} = Tenants.create_tenant(tenant_id, %{status: :active})

      assert Tenants.tenant_active?(tenant) == true,
             "tenant with status :active should be active"

      retrieved_tenant = Tenants.get_tenant(tenant_id)
      assert retrieved_tenant != nil, "tenant should exist in database"
      assert retrieved_tenant.status == :active
      assert Tenants.tenant_active?(retrieved_tenant) == true,
             "retrieved tenant should be active"

      {:ok, jit_tenant} = Tenants.get_or_create_tenant(tenant_id)
      assert Tenants.tenant_active?(jit_tenant) == true,
             "tenant retrieved via JIT should be active"
    end
  end

  defp tenant_id_generator do
    gen all(
          prefix <- member_of(["tenant", "org", "client", "company"]),
          suffix <- string(:alphanumeric, min_length: 1, max_length: 20)
        ) do
      "#{prefix}-#{suffix}"
    end
  end
end
