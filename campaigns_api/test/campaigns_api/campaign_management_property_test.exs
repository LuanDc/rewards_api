defmodule CampaignsApi.CampaignManagementPropertyTest do
  use CampaignsApi.DataCase
  use ExUnitProperties

  import Ecto.Query

  alias CampaignsApi.CampaignManagement
  alias CampaignsApi.CampaignManagement.Campaign
  alias CampaignsApi.Repo
  alias CampaignsApi.Tenants

  setup do
    # Create test tenants for campaign tests
    {:ok, tenant1} = Tenants.create_tenant("test-tenant-1-#{System.unique_integer([:positive])}")
    {:ok, tenant2} = Tenants.create_tenant("test-tenant-2-#{System.unique_integer([:positive])}")

    {:ok, tenant1: tenant1, tenant2: tenant2}
  end

  # Feature: campaign-management-api, Property 7: Campaign Creation with Tenant Association
  # **Validates: Requirements 4.1, 4.2, 4.4**
  property "any authenticated client with valid campaign data creates campaign with tenant association and UUID",
           %{tenant1: tenant} do
    check all(
            name <- campaign_name_generator(),
            max_runs: 100
          ) do
      attrs = %{name: name}

      {:ok, campaign} = CampaignManagement.create_campaign(tenant.id, attrs)

      # Verify campaign is associated with the tenant
      assert campaign.tenant_id == tenant.id,
             "campaign should be associated with the client's tenant_id"

      # Verify campaign has a UUID
      assert is_binary(campaign.id), "campaign id should be a binary (UUID)"
      assert String.length(campaign.id) == 36, "campaign id should be a valid UUID format"

      # Verify UUID format (8-4-4-4-12 pattern)
      assert campaign.id =~ ~r/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/,
             "campaign id should match UUID format"

      # Verify campaign exists in database with correct tenant association
      db_campaign = Repo.get(Campaign, campaign.id)
      assert db_campaign != nil, "campaign should be persisted in database"
      assert db_campaign.tenant_id == tenant.id, "persisted campaign should have correct tenant_id"
    end
  end

  # Feature: campaign-management-api, Property 8: Campaign Default Status
  # **Validates: Requirements 4.3**
  property "any campaign created without explicit status has status active", %{tenant1: tenant} do
    check all(
            name <- campaign_name_generator(),
            max_runs: 100
          ) do
      # Create campaign without status field
      attrs = %{name: name}

      {:ok, campaign} = CampaignManagement.create_campaign(tenant.id, attrs)

      # Verify default status is :active
      assert campaign.status == :active,
             "campaign created without status should default to :active"

      # Verify in database
      db_campaign = Repo.get(Campaign, campaign.id)
      assert db_campaign.status == :active, "persisted campaign should have :active status"
    end
  end

  # Feature: campaign-management-api, Property 10: Optional Campaign Fields
  # **Validates: Requirements 4.6, 4.7, 4.8**
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
      # Build attrs with optional fields based on flags
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
          # Ensure end_time is after start_time if both are present
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

      # Campaign should be valid regardless of which optional fields are present
      {:ok, campaign} = CampaignManagement.create_campaign(tenant.id, attrs)

      assert campaign.name == name, "campaign should have the provided name"

      # Verify optional fields match what was provided
      # Note: Empty strings are stored as nil by Ecto
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

  # Feature: campaign-management-api, Property 12: UTC Timezone Storage
  # **Validates: Requirements 4.10**
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

      # Verify stored datetimes are in UTC
      assert campaign.start_time.time_zone == "Etc/UTC",
             "start_time should be stored in UTC timezone"

      assert campaign.end_time.time_zone == "Etc/UTC",
             "end_time should be stored in UTC timezone"

      # Verify retrieved datetimes are in UTC
      retrieved_campaign = CampaignManagement.get_campaign(tenant.id, campaign.id)
      assert retrieved_campaign.start_time.time_zone == "Etc/UTC"
      assert retrieved_campaign.end_time.time_zone == "Etc/UTC"

      # Verify timestamps are also in UTC
      assert campaign.inserted_at.time_zone == "Etc/UTC"
      assert campaign.updated_at.time_zone == "Etc/UTC"
    end
  end

  # Feature: campaign-management-api, Property 13: Tenant Data Isolation
  # **Validates: Requirements 5.1, 5.7, 5.8, 6.1, 6.4, 7.1, 7.2, 8.2**
  property "any tenant cannot access campaigns belonging to other tenants",
           %{tenant1: tenant1, tenant2: tenant2} do
    check all(
            name <- campaign_name_generator(),
            max_runs: 100
          ) do
      # Create campaign for tenant1
      {:ok, campaign} = CampaignManagement.create_campaign(tenant1.id, %{name: name})

      # Verify tenant1 can access their campaign
      assert CampaignManagement.get_campaign(tenant1.id, campaign.id) != nil,
             "tenant1 should be able to retrieve their own campaign"

      # Verify tenant2 cannot access tenant1's campaign (returns nil, not error)
      assert CampaignManagement.get_campaign(tenant2.id, campaign.id) == nil,
             "tenant2 should not be able to retrieve tenant1's campaign"

      # Verify tenant2 cannot update tenant1's campaign
      assert {:error, :not_found} =
               CampaignManagement.update_campaign(tenant2.id, campaign.id, %{name: "Updated"}),
             "tenant2 should not be able to update tenant1's campaign"

      # Verify tenant2 cannot delete tenant1's campaign
      assert {:error, :not_found} = CampaignManagement.delete_campaign(tenant2.id, campaign.id),
             "tenant2 should not be able to delete tenant1's campaign"

      # Verify campaign still exists for tenant1 after failed cross-tenant operations
      assert CampaignManagement.get_campaign(tenant1.id, campaign.id) != nil,
             "campaign should still exist for tenant1 after cross-tenant access attempts"

      # Verify tenant2's list does not include tenant1's campaigns
      tenant2_campaigns = CampaignManagement.list_campaigns(tenant2.id)
      campaign_ids = Enum.map(tenant2_campaigns.data, & &1.id)

      assert campaign.id not in campaign_ids,
             "tenant1's campaign should not appear in tenant2's campaign list"
    end
  end

  # Feature: campaign-management-api, Property 14: Campaign List Ordering
  # **Validates: Requirements 5.2**
  property "any tenant's campaign list is ordered by inserted_at descending (most recent first)",
           %{tenant1: tenant} do
    check all(
            campaign_count <- integer(2..10),
            max_runs: 100
          ) do
      # Clean up existing campaigns for this tenant
      Repo.delete_all(from c in Campaign, where: c.tenant_id == ^tenant.id)

      # Create multiple campaigns
      # Note: We don't rely on Process.sleep as database timestamp precision may vary
      _campaigns =
        Enum.map(1..campaign_count, fn i ->
          {:ok, campaign} =
            CampaignManagement.create_campaign(tenant.id, %{name: "Campaign #{i}"})

          campaign
        end)

      # List campaigns
      result = CampaignManagement.list_campaigns(tenant.id)

      # Verify we got all campaigns
      returned_campaigns = result.data
      assert length(returned_campaigns) == campaign_count

      # Check that campaigns are ordered by inserted_at descending
      # Each campaign's inserted_at should be >= the next one's inserted_at
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

      # Verify the first campaign has the latest or equal inserted_at compared to all others
      first_campaign = hd(returned_campaigns)

      Enum.each(returned_campaigns, fn campaign ->
        comparison = DateTime.compare(first_campaign.inserted_at, campaign.inserted_at)

        assert comparison in [:gt, :eq],
               "first campaign should have the latest inserted_at"
      end)
    end
  end

  # Feature: campaign-management-api, Property 18: Default Pagination Behavior
  # **Validates: Requirements 5.6**
  property "any campaign list request without cursor returns first page from most recent",
           %{tenant1: tenant} do
    check all(
            campaign_count <- integer(5..15),
            max_runs: 100
          ) do
      # Clean up existing campaigns
      Repo.delete_all(from c in Campaign, where: c.tenant_id == ^tenant.id)

      # Create campaigns
      _campaigns =
        Enum.map(1..campaign_count, fn i ->
          {:ok, campaign} =
            CampaignManagement.create_campaign(tenant.id, %{name: "Campaign #{i}"})

          campaign
        end)

      # Request without cursor (default pagination)
      result = CampaignManagement.list_campaigns(tenant.id)

      # Should return campaigns starting from most recent
      assert result.data != [], "should return campaigns"

      # Verify ordering is descending by inserted_at
      # Each campaign should have inserted_at >= next campaign's inserted_at
      case result.data do
        [_single] ->
          # Single campaign, no ordering to verify
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

      # Verify the first campaign has the latest inserted_at
      first_returned = hd(result.data)

      Enum.each(result.data, fn campaign ->
        comparison = DateTime.compare(first_returned.inserted_at, campaign.inserted_at)

        assert comparison in [:gt, :eq],
               "first campaign should have the latest inserted_at"
      end)
    end
  end

  # Feature: campaign-management-api, Property 19: Campaign Response Schema
  # **Validates: Requirements 5.10, 10.2**
  property "any campaign retrieved or created includes all required fields",
           %{tenant1: tenant} do
    check all(
            name <- campaign_name_generator(),
            max_runs: 100
          ) do
      # Create campaign
      {:ok, created_campaign} = CampaignManagement.create_campaign(tenant.id, %{name: name})

      # Verify created campaign has all required fields
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

      # Retrieve campaign and verify same fields
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

      # Verify field values match
      assert retrieved_campaign.id == created_campaign.id
      assert retrieved_campaign.tenant_id == created_campaign.tenant_id
      assert retrieved_campaign.name == created_campaign.name
    end
  end

  # Feature: campaign-management-api, Property 20: Campaign Field Mutability
  # **Validates: Requirements 6.2**
  property "campaign update allows modifying mutable fields while keeping id and tenant_id immutable",
           %{tenant1: tenant} do
    check all(
            original_name <- campaign_name_generator(),
            new_name <- campaign_name_generator(),
            new_description <- string(:alphanumeric, min_length: 1, max_length: 100),
            new_status <- member_of([:active, :paused]),
            max_runs: 100
          ) do
      # Create campaign
      {:ok, campaign} = CampaignManagement.create_campaign(tenant.id, %{name: original_name})

      original_id = campaign.id
      original_tenant_id = campaign.tenant_id

      # Update mutable fields
      update_attrs = %{
        name: new_name,
        description: new_description,
        status: new_status
      }

      {:ok, updated_campaign} =
        CampaignManagement.update_campaign(tenant.id, campaign.id, update_attrs)

      # Verify mutable fields were updated
      assert updated_campaign.name == new_name, "name should be mutable"
      assert updated_campaign.description == new_description, "description should be mutable"
      assert updated_campaign.status == new_status, "status should be mutable"

      # Verify immutable fields remain unchanged
      assert updated_campaign.id == original_id, "id should be immutable"

      assert updated_campaign.tenant_id == original_tenant_id,
             "tenant_id should be immutable"

      # Verify attempting to change tenant_id in attrs doesn't change it
      # Note: This may fail with foreign key constraint if the tenant doesn't exist,
      # but the important thing is that tenant_id doesn't change
      result =
        CampaignManagement.update_campaign(tenant.id, campaign.id, %{
          tenant_id: "different-tenant"
        })

      case result do
        {:ok, attempt_change_tenant} ->
          # If update succeeds, tenant_id should remain unchanged
          assert attempt_change_tenant.tenant_id == original_tenant_id,
                 "tenant_id should remain unchanged even if included in update attrs"

        {:error, _changeset} ->
          # If update fails due to foreign key constraint, that's also acceptable
          # The important thing is tenant_id is protected
          :ok
      end
    end
  end

  # Feature: campaign-management-api, Property 21: Campaign Status Transitions
  # **Validates: Requirements 6.6**
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

  # Feature: campaign-management-api, Property 22: Hard Delete Behavior
  # **Validates: Requirements 7.1**
  property "any deleted campaign cannot be retrieved and does not appear in list queries",
           %{tenant1: tenant} do
    check all(
            name <- campaign_name_generator(),
            max_runs: 100
          ) do
      # Create campaign
      {:ok, campaign} = CampaignManagement.create_campaign(tenant.id, %{name: name})
      campaign_id = campaign.id

      # Verify campaign exists
      assert CampaignManagement.get_campaign(tenant.id, campaign_id) != nil

      # Delete campaign
      {:ok, _deleted} = CampaignManagement.delete_campaign(tenant.id, campaign_id)

      # Verify campaign cannot be retrieved (returns nil, indicating 404)
      assert CampaignManagement.get_campaign(tenant.id, campaign_id) == nil,
             "deleted campaign should return nil when retrieved"

      # Verify campaign does not appear in list queries
      result = CampaignManagement.list_campaigns(tenant.id)
      campaign_ids = Enum.map(result.data, & &1.id)

      assert campaign_id not in campaign_ids,
             "deleted campaign should not appear in list queries"

      # Verify subsequent attempts to retrieve return nil
      assert CampaignManagement.get_campaign(tenant.id, campaign_id) == nil

      # Verify subsequent attempts to delete return not_found
      assert {:error, :not_found} = CampaignManagement.delete_campaign(tenant.id, campaign_id)
    end
  end

  # Generator for valid campaign names (minimum 3 characters)
  defp campaign_name_generator do
    gen all(
          prefix <- member_of(["Campaign", "Sale", "Promo", "Event", "Reward"]),
          suffix <- string(:alphanumeric, min_length: 1, max_length: 20)
        ) do
      "#{prefix} #{suffix}"
    end
  end

  # Generator for valid UTC datetimes
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
