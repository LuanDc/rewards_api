defmodule CampaignsApi.Tenants.TenantPropertyTest do
  use CampaignsApi.DataCase
  use ExUnitProperties

  alias CampaignsApi.Repo
  alias CampaignsApi.Tenants.Tenant

  property "any tenant record contains all required fields" do
    check all(
            tenant_id <- string(:alphanumeric, min_length: 1, max_length: 50),
            name <- string(:alphanumeric, min_length: 1, max_length: 100),
            status <- member_of([:active, :suspended, :deleted]),
            deleted_at <- one_of([constant(nil), datetime()]),
            max_runs: 100
          ) do
      # Create a tenant with generated data
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
            assert tenant.id != nil, "id should not be nil"
            assert tenant.name != nil, "name should not be nil"
            assert tenant.status != nil, "status should not be nil"
            assert tenant.inserted_at != nil, "inserted_at should not be nil"
            assert tenant.updated_at != nil, "updated_at should not be nil"

            assert is_nil(tenant.deleted_at) or match?(%DateTime{}, tenant.deleted_at),
                   "deleted_at should be nil or a DateTime"

            retrieved_tenant = Repo.get(Tenant, tenant.id)
            assert retrieved_tenant != nil, "tenant should be retrievable"
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

  defp datetime do
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
