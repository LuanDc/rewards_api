defmodule CampaignsApi.CampaignManagementPropertyTest do
  use CampaignsApi.DataCase
  use ExUnitProperties

  import Ecto.Query

  alias CampaignsApi.CampaignManagement
  alias CampaignsApi.CampaignManagement.Campaign
  alias CampaignsApi.Repo
  alias CampaignsApi.Tenants

  setup do
    {:ok, tenant1} = Tenants.create_tenant("test-tenant-1-#{System.unique_integer([:positive])}")
    {:ok, tenant2} = Tenants.create_tenant("test-tenant-2-#{System.unique_integer([:positive])}")

    {:ok, tenant1: tenant1, tenant2: tenant2}
  end

  property "any authenticated client with valid campaign data creates campaign with tenant association and UUID",
           %{tenant1: tenant} do
    check all(
            name <- campaign_name_generator(),
            max_runs: 100
          ) do
      attrs = %{name: name}

      {:ok, campaign} = CampaignManagement.create_campaign(tenant.id, attrs)

      assert campaign.tenant_id == tenant.id,
             "campaign should be associated with the client's tenant_id"

      assert is_binary(campaign.id), "campaign id should be a binary (UUID)"
      assert String.length(campaign.id) == 36, "campaign id should be a valid UUID format"

      assert campaign.id =~ ~r/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/,
             "campaign id should match UUID format"

      db_campaign = Repo.get(Campaign, campaign.id)
      assert db_campaign != nil, "campaign should be persisted in database"
      assert db_campaign.tenant_id == tenant.id, "persisted campaign should have correct tenant_id"
    end
  end

  property "any campaign created without explicit status has status active", %{tenant1: tenant} do
    check all(
            name <- campaign_name_generator(),
            max_runs: 100
          ) do
      attrs = %{name: name}

      {:ok, campaign} = CampaignManagement.create_campaign(tenant.id, attrs)

      assert campaign.status == :active,
             "campaign created without status should default to :active"

      db_campaign = Repo.get(Campaign, campaign.id)
      assert db_campaign.status == :active, "persisted campaign should have :active status"
    end
  end

  property "campaigns are valid with or without optional fields (description, start_time, end_time)",
           %{tenant1: tenant} do
    check all(
            name <- campaign_name_generator(),
            include_description <- boolean(),
            include_start_time <- boolean(),
            include_end_time <- boolean(),
            description <- string(:alphanumeric, min_length: 1, max_length: 100),
            datetime <- datetime_generator(),
            max_runs: 100
          ) do
      attrs = %{name: name}

      attrs =
        if include_description do
          Map.put(attrs, :description, description)
        else
          attrs
        end

      attrs =
        if include_start_time do
          Map.put(attrs, :start_time, datetime)
        else
          attrs
        end

      attrs =
        if include_end_time do
          end_datetime =
            if include_start_time do
              DateTime.add(datetime, 3600, :second)
            else
              datetime
            end

          Map.put(attrs, :end_time, end_datetime)
        else
          attrs
        end

      {:ok, campaign} = CampaignManagement.create_campaign(tenant.id, attrs)

      assert campaign.name == name, "campaign should have the provided name"

      if include_description do
        assert campaign.description == description
      else
        assert campaign.description == nil
      end

      if include_start_time do
        assert campaign.start_time != nil
      else
        assert campaign.start_time == nil
      end

      if include_end_time do
        assert campaign.end_time != nil
      else
        assert campaign.end_time == nil
      end
    end
  end

  property "all campaign datetime fields are stored and retrieved in UTC timezone",
           %{tenant1: tenant} do
    check all(
            name <- campaign_name_generator(),
            start_time <- datetime_generator(),
            max_runs: 100
          ) do
      end_time = DateTime.add(start_time, 3600, :second)

      attrs = %{
        name: name,
        start_time: start_time,
        end_time: end_time
      }

      {:ok, campaign} = CampaignManagement.create_campaign(tenant.id, attrs)

      assert campaign.start_time.time_zone == "Etc/UTC",
             "start_time should be stored in UTC timezone"

      assert campaign.end_time.time_zone == "Etc/UTC",
             "end_time should be stored in UTC timezone"

      retrieved_campaign = CampaignManagement.get_campaign(tenant.id, campaign.id)
      assert retrieved_campaign.start_time.time_zone == "Etc/UTC"
      assert retrieved_campaign.end_time.time_zone == "Etc/UTC"

      assert campaign.inserted_at.time_zone == "Etc/UTC"
      assert campaign.updated_at.time_zone == "Etc/UTC"
    end
  end

  property "any tenant cannot access campaigns belonging to other tenants",
           %{tenant1: tenant1, tenant2: tenant2} do
    check all(
            name <- campaign_name_generator(),
            max_runs: 100
          ) do
      {:ok, campaign} = CampaignManagement.create_campaign(tenant1.id, %{name: name})

      assert CampaignManagement.get_campaign(tenant1.id, campaign.id) != nil,
             "tenant1 should be able to retrieve their own campaign"

      assert CampaignManagement.get_campaign(tenant2.id, campaign.id) == nil,
             "tenant2 should not be able to retrieve tenant1's campaign"

      assert {:error, :not_found} =
               CampaignManagement.update_campaign(tenant2.id, campaign.id, %{name: "Updated"}),
             "tenant2 should not be able to update tenant1's campaign"

      assert {:error, :not_found} = CampaignManagement.delete_campaign(tenant2.id, campaign.id),
             "tenant2 should not be able to delete tenant1's campaign"

      assert CampaignManagement.get_campaign(tenant1.id, campaign.id) != nil,
             "campaign should still exist for tenant1 after cross-tenant access attempts"

      tenant2_campaigns = CampaignManagement.list_campaigns(tenant2.id)
      campaign_ids = Enum.map(tenant2_campaigns.data, & &1.id)

      assert campaign.id not in campaign_ids,
             "tenant1's campaign should not appear in tenant2's campaign list"
    end
  end

  property "any tenant's campaign list is ordered by inserted_at descending (most recent first)",
           %{tenant1: tenant} do
    check all(
            campaign_count <- integer(2..10),
            max_runs: 100
          ) do
      Repo.delete_all(from c in Campaign, where: c.tenant_id == ^tenant.id)

      _campaigns =
        Enum.map(1..campaign_count, fn i ->
          {:ok, campaign} =
            CampaignManagement.create_campaign(tenant.id, %{name: "Campaign #{i}"})

          campaign
        end)

      result = CampaignManagement.list_campaigns(tenant.id)

      returned_campaigns = result.data
      assert length(returned_campaigns) == campaign_count

      if length(returned_campaigns) > 1 do
        returned_campaigns
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.each(fn [current, next] ->
          comparison = DateTime.compare(current.inserted_at, next.inserted_at)

          assert comparison in [:gt, :eq],
                 "campaigns should be ordered by inserted_at descending (most recent first), " <>
                   "got #{inspect(current.inserted_at)} vs #{inspect(next.inserted_at)}"
        end)
      end

      first_campaign = hd(returned_campaigns)

      Enum.each(returned_campaigns, fn campaign ->
        comparison = DateTime.compare(first_campaign.inserted_at, campaign.inserted_at)

        assert comparison in [:gt, :eq],
               "first campaign should have the latest inserted_at"
      end)
    end
  end

  property "any campaign list request without cursor returns first page from most recent",
           %{tenant1: tenant} do
    check all(
            campaign_count <- integer(5..15),
            max_runs: 100
          ) do
      Repo.delete_all(from c in Campaign, where: c.tenant_id == ^tenant.id)

      _campaigns =
        Enum.map(1..campaign_count, fn i ->
          {:ok, campaign} =
            CampaignManagement.create_campaign(tenant.id, %{name: "Campaign #{i}"})

          campaign
        end)

      result = CampaignManagement.list_campaigns(tenant.id)

      assert result.data != [], "should return campaigns"

      case result.data do
        [_single] ->
          :ok

        [_ | _] = campaigns ->
          campaigns
          |> Enum.chunk_every(2, 1, :discard)
          |> Enum.each(fn [current, next] ->
            comparison = DateTime.compare(current.inserted_at, next.inserted_at)

            assert comparison in [:gt, :eq],
                   "campaigns should be ordered by inserted_at descending"
          end)

        [] ->
          flunk("should return campaigns")
      end

      first_returned = hd(result.data)

      Enum.each(result.data, fn campaign ->
        comparison = DateTime.compare(first_returned.inserted_at, campaign.inserted_at)

        assert comparison in [:gt, :eq],
               "first campaign should have the latest inserted_at"
      end)
    end
  end

  property "any campaign retrieved or created includes all required fields",
           %{tenant1: tenant} do
    check all(
            name <- campaign_name_generator(),
            max_runs: 100
          ) do
      {:ok, created_campaign} = CampaignManagement.create_campaign(tenant.id, %{name: name})

      assert Map.has_key?(created_campaign, :id), "campaign should have :id field"
      assert Map.has_key?(created_campaign, :tenant_id), "campaign should have :tenant_id field"
      assert Map.has_key?(created_campaign, :name), "campaign should have :name field"

      assert Map.has_key?(created_campaign, :description),
             "campaign should have :description field"

      assert Map.has_key?(created_campaign, :start_time), "campaign should have :start_time field"
      assert Map.has_key?(created_campaign, :end_time), "campaign should have :end_time field"
      assert Map.has_key?(created_campaign, :status), "campaign should have :status field"

      assert Map.has_key?(created_campaign, :inserted_at),
             "campaign should have :inserted_at field"

      assert Map.has_key?(created_campaign, :updated_at),
             "campaign should have :updated_at field"

      retrieved_campaign = CampaignManagement.get_campaign(tenant.id, created_campaign.id)

      assert Map.has_key?(retrieved_campaign, :id)
      assert Map.has_key?(retrieved_campaign, :tenant_id)
      assert Map.has_key?(retrieved_campaign, :name)
      assert Map.has_key?(retrieved_campaign, :description)
      assert Map.has_key?(retrieved_campaign, :start_time)
      assert Map.has_key?(retrieved_campaign, :end_time)
      assert Map.has_key?(retrieved_campaign, :status)
      assert Map.has_key?(retrieved_campaign, :inserted_at)
      assert Map.has_key?(retrieved_campaign, :updated_at)

      assert retrieved_campaign.id == created_campaign.id
      assert retrieved_campaign.tenant_id == created_campaign.tenant_id
      assert retrieved_campaign.name == created_campaign.name
    end
  end

  property "campaign update allows modifying mutable fields while keeping id and tenant_id immutable",
           %{tenant1: tenant} do
    check all(
            original_name <- campaign_name_generator(),
            new_name <- campaign_name_generator(),
            new_description <- string(:alphanumeric, min_length: 1, max_length: 100),
            new_status <- member_of([:active, :paused]),
            max_runs: 100
          ) do
      {:ok, campaign} = CampaignManagement.create_campaign(tenant.id, %{name: original_name})

      original_id = campaign.id
      original_tenant_id = campaign.tenant_id

      update_attrs = %{
        name: new_name,
        description: new_description,
        status: new_status
      }

      {:ok, updated_campaign} =
        CampaignManagement.update_campaign(tenant.id, campaign.id, update_attrs)

      assert updated_campaign.name == new_name, "name should be mutable"
      assert updated_campaign.description == new_description, "description should be mutable"
      assert updated_campaign.status == new_status, "status should be mutable"

      assert updated_campaign.id == original_id, "id should be immutable"

      assert updated_campaign.tenant_id == original_tenant_id,
             "tenant_id should be immutable"

      result =
        CampaignManagement.update_campaign(tenant.id, campaign.id, %{
          tenant_id: "different-tenant"
        })

      case result do
        {:ok, attempt_change_tenant} ->
          assert attempt_change_tenant.tenant_id == original_tenant_id,
                 "tenant_id should remain unchanged even if included in update attrs"

        {:error, _changeset} ->
          :ok
      end
    end
  end

  property "campaign status can be changed between active and paused in any direction",
           %{tenant1: tenant} do
    check all(
            name <- campaign_name_generator(),
            initial_status <- member_of([:active, :paused]),
            target_status <- member_of([:active, :paused]),
            max_runs: 100
          ) do
      # Create campaign with initial status
      {:ok, campaign} =
        CampaignManagement.create_campaign(tenant.id, %{name: name, status: initial_status})

      assert campaign.status == initial_status

      # Update to target status
      {:ok, updated_campaign} =
        CampaignManagement.update_campaign(tenant.id, campaign.id, %{status: target_status})

      assert updated_campaign.status == target_status,
             "status should transition from #{initial_status} to #{target_status}"

      # Verify in database
      db_campaign = CampaignManagement.get_campaign(tenant.id, campaign.id)
      assert db_campaign.status == target_status
    end
  end

  property "any deleted campaign cannot be retrieved and does not appear in list queries",
           %{tenant1: tenant} do
    check all(
            name <- campaign_name_generator(),
            max_runs: 100
          ) do
      {:ok, campaign} = CampaignManagement.create_campaign(tenant.id, %{name: name})
      campaign_id = campaign.id

      assert CampaignManagement.get_campaign(tenant.id, campaign_id) != nil

      {:ok, _deleted} = CampaignManagement.delete_campaign(tenant.id, campaign_id)

      assert CampaignManagement.get_campaign(tenant.id, campaign_id) == nil,
             "deleted campaign should return nil when retrieved"

      result = CampaignManagement.list_campaigns(tenant.id)
      campaign_ids = Enum.map(result.data, & &1.id)

      assert campaign_id not in campaign_ids,
             "deleted campaign should not appear in list queries"

      assert CampaignManagement.get_campaign(tenant.id, campaign_id) == nil

      assert {:error, :not_found} = CampaignManagement.delete_campaign(tenant.id, campaign_id)
    end
  end

  defp campaign_name_generator do
    gen all(
          prefix <- member_of(["Campaign", "Sale", "Promo", "Event", "Reward"]),
          suffix <- string(:alphanumeric, min_length: 1, max_length: 20)
        ) do
      "#{prefix} #{suffix}"
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
      {:ok, datetime} = DateTime.new(Date.new!(year, month, day), Time.new!(hour, minute, second))
      datetime
    end
  end
end
