defmodule CampaignsApi.CampaignManagementTest do
  use CampaignsApi.DataCase

  alias CampaignsApi.CampaignManagement
  alias CampaignsApi.Tenants

  setup do
    # Create test tenants
    {:ok, tenant1} = Tenants.create_tenant("test-tenant-1-#{System.unique_integer([:positive])}")
    {:ok, tenant2} = Tenants.create_tenant("test-tenant-2-#{System.unique_integer([:positive])}")

    {:ok, tenant1: tenant1, tenant2: tenant2}
  end

  describe "get_campaign/2" do
    test "returns nil when accessing campaign from different tenant (cross-tenant access)", %{
      tenant1: tenant1,
      tenant2: tenant2
    } do
      # Create campaign for tenant1
      {:ok, campaign} =
        CampaignManagement.create_campaign(tenant1.id, %{
          name: "Tenant 1 Campaign"
        })

      # Verify tenant1 can access their campaign
      assert CampaignManagement.get_campaign(tenant1.id, campaign.id) != nil

      # Verify tenant2 cannot access tenant1's campaign (returns nil, not error)
      assert CampaignManagement.get_campaign(tenant2.id, campaign.id) == nil
    end

    test "returns nil when campaign does not exist", %{tenant1: tenant} do
      non_existent_id = Ecto.UUID.generate()
      assert CampaignManagement.get_campaign(tenant.id, non_existent_id) == nil
    end
  end

  describe "create_campaign/2" do
    test "returns error with foreign key violation when tenant does not exist" do
      non_existent_tenant_id = "non-existent-tenant-#{System.unique_integer([:positive])}"

      # Attempt to create campaign for non-existent tenant
      assert {:error, changeset} =
               CampaignManagement.create_campaign(non_existent_tenant_id, %{
                 name: "Test Campaign"
               })

      # Verify it's a foreign key constraint error
      assert %{tenant_id: ["does not exist"]} = errors_on(changeset)
    end

    test "successfully creates campaign for existing tenant", %{tenant1: tenant} do
      {:ok, campaign} =
        CampaignManagement.create_campaign(tenant.id, %{
          name: "Valid Campaign"
        })

      assert campaign.tenant_id == tenant.id
      assert campaign.name == "Valid Campaign"
    end
  end

  describe "list_campaigns/2 pagination" do
    test "returns empty list when tenant has no campaigns", %{tenant1: tenant} do
      result = CampaignManagement.list_campaigns(tenant.id)

      assert result.data == []
      assert result.next_cursor == nil
      assert result.has_more == false
    end

    test "returns all campaigns when count is less than default limit", %{tenant1: tenant} do
      # Create 5 campaigns (less than default limit of 50)
      campaigns =
        Enum.map(1..5, fn i ->
          {:ok, campaign} =
            CampaignManagement.create_campaign(tenant.id, %{name: "Campaign #{i}"})

          campaign
        end)

      result = CampaignManagement.list_campaigns(tenant.id)

      assert length(result.data) == 5
      assert result.has_more == false
      assert result.next_cursor == nil

      # Verify all campaigns are present
      returned_ids = Enum.map(result.data, & &1.id)
      campaign_ids = Enum.map(campaigns, & &1.id)
      assert Enum.all?(campaign_ids, &(&1 in returned_ids))
    end

    test "respects custom limit parameter", %{tenant1: tenant} do
      # Create 10 campaigns
      Enum.each(1..10, fn i ->
        CampaignManagement.create_campaign(tenant.id, %{name: "Campaign #{i}"})
      end)

      # Request with limit of 3
      result = CampaignManagement.list_campaigns(tenant.id, limit: 3)

      assert length(result.data) == 3
      assert result.has_more == true
      assert result.next_cursor != nil
    end

    test "handles pagination with cursor", %{tenant1: tenant} do
      # Create 12 campaigns
      # Note: In tests, campaigns may have identical timestamps due to fast execution
      Enum.each(1..12, fn i ->
        CampaignManagement.create_campaign(tenant.id, %{name: "Campaign #{i}"})
      end)

      # Get first page with limit 5
      first_page = CampaignManagement.list_campaigns(tenant.id, limit: 5)
      assert length(first_page.data) == 5

      # If there are more campaigns, test cursor pagination
      if first_page.has_more do
        assert first_page.next_cursor != nil

        # Get second page using cursor
        second_page =
          CampaignManagement.list_campaigns(tenant.id, limit: 5, cursor: first_page.next_cursor)

        # Verify no overlap between pages (campaigns with different IDs)
        first_page_ids = Enum.map(first_page.data, & &1.id)
        second_page_ids = Enum.map(second_page.data, & &1.id)

        # All second page IDs should be different from first page IDs
        assert Enum.all?(second_page_ids, &(&1 not in first_page_ids)),
               "Second page should not contain campaigns from first page"
      end
    end

    test "enforces maximum limit of 100", %{tenant1: tenant} do
      # Create 150 campaigns
      Enum.each(1..150, fn i ->
        CampaignManagement.create_campaign(tenant.id, %{name: "Campaign #{i}"})
      end)

      # Request with limit > 100
      result = CampaignManagement.list_campaigns(tenant.id, limit: 200)

      # Should return at most 100
      assert length(result.data) <= 100
      assert result.has_more == true
    end

    test "returns campaigns only for specified tenant", %{tenant1: tenant1, tenant2: tenant2} do
      # Create campaigns for both tenants
      {:ok, tenant1_campaign} =
        CampaignManagement.create_campaign(tenant1.id, %{name: "Tenant 1 Campaign"})

      {:ok, tenant2_campaign} =
        CampaignManagement.create_campaign(tenant2.id, %{name: "Tenant 2 Campaign"})

      # List campaigns for tenant1
      tenant1_result = CampaignManagement.list_campaigns(tenant1.id)
      tenant1_ids = Enum.map(tenant1_result.data, & &1.id)

      # List campaigns for tenant2
      tenant2_result = CampaignManagement.list_campaigns(tenant2.id)
      tenant2_ids = Enum.map(tenant2_result.data, & &1.id)

      # Verify isolation
      assert tenant1_campaign.id in tenant1_ids
      assert tenant1_campaign.id not in tenant2_ids
      assert tenant2_campaign.id in tenant2_ids
      assert tenant2_campaign.id not in tenant1_ids
    end
  end

  describe "update_campaign/3" do
    test "returns changeset errors when updating with invalid data", %{tenant1: tenant} do
      # Create a campaign
      {:ok, campaign} =
        CampaignManagement.create_campaign(tenant.id, %{
          name: "Original Campaign"
        })

      # Try to update with invalid name (less than 3 characters)
      assert {:error, changeset} =
               CampaignManagement.update_campaign(tenant.id, campaign.id, %{name: "ab"})

      assert %{name: ["should be at least 3 character(s)"]} = errors_on(changeset)
    end

    test "returns changeset errors when updating with invalid date order", %{tenant1: tenant} do
      # Create a campaign
      {:ok, campaign} =
        CampaignManagement.create_campaign(tenant.id, %{
          name: "Test Campaign"
        })

      # Try to update with start_time after end_time
      start_time = ~U[2024-02-01 00:00:00Z]
      end_time = ~U[2024-01-01 00:00:00Z]

      assert {:error, changeset} =
               CampaignManagement.update_campaign(tenant.id, campaign.id, %{
                 start_time: start_time,
                 end_time: end_time
               })

      assert %{start_time: ["must be before end_time"]} = errors_on(changeset)
    end

    test "successfully updates campaign with valid data", %{tenant1: tenant} do
      # Create a campaign
      {:ok, campaign} =
        CampaignManagement.create_campaign(tenant.id, %{
          name: "Original Campaign"
        })

      # Update with valid data
      {:ok, updated_campaign} =
        CampaignManagement.update_campaign(tenant.id, campaign.id, %{
          name: "Updated Campaign",
          description: "New description"
        })

      assert updated_campaign.name == "Updated Campaign"
      assert updated_campaign.description == "New description"
    end

    test "returns not_found when updating campaign from different tenant", %{
      tenant1: tenant1,
      tenant2: tenant2
    } do
      # Create campaign for tenant1
      {:ok, campaign} =
        CampaignManagement.create_campaign(tenant1.id, %{
          name: "Tenant 1 Campaign"
        })

      # Try to update with tenant2's ID
      assert {:error, :not_found} =
               CampaignManagement.update_campaign(tenant2.id, campaign.id, %{
                 name: "Updated Name"
               })

      # Verify campaign unchanged for tenant1
      unchanged = CampaignManagement.get_campaign(tenant1.id, campaign.id)
      assert unchanged.name == "Tenant 1 Campaign"
    end

    test "returns not_found when updating non-existent campaign", %{tenant1: tenant} do
      non_existent_id = Ecto.UUID.generate()

      assert {:error, :not_found} =
               CampaignManagement.update_campaign(tenant.id, non_existent_id, %{
                 name: "New Name"
               })
    end
  end

  describe "flexible date management examples" do
    # Example 1: Campaign without dates
    # Validates: Requirements 9.1
    test "creates campaign without start_time or end_time", %{tenant1: tenant} do
      {:ok, campaign} =
        CampaignManagement.create_campaign(tenant.id, %{
          name: "No Dates Campaign"
        })

      assert campaign.start_time == nil
      assert campaign.end_time == nil
      assert campaign.name == "No Dates Campaign"
    end

    # Example 2: Campaign with start_time only
    # Validates: Requirements 9.2
    test "creates campaign with start_time but no end_time", %{tenant1: tenant} do
      start_time = ~U[2024-01-01 00:00:00Z]

      {:ok, campaign} =
        CampaignManagement.create_campaign(tenant.id, %{
          name: "Start Only Campaign",
          start_time: start_time
        })

      assert campaign.start_time == start_time
      assert campaign.end_time == nil
      assert campaign.name == "Start Only Campaign"
    end

    # Example 3: Campaign with end_time only
    # Validates: Requirements 9.3
    test "creates campaign with end_time but no start_time", %{tenant1: tenant} do
      end_time = ~U[2024-12-31 23:59:59Z]

      {:ok, campaign} =
        CampaignManagement.create_campaign(tenant.id, %{
          name: "End Only Campaign",
          end_time: end_time
        })

      assert campaign.start_time == nil
      assert campaign.end_time == end_time
      assert campaign.name == "End Only Campaign"
    end

    # Example 4: Campaign with both dates
    # Validates: Requirements 9.4
    test "creates campaign with both start_time and end_time when start is before end", %{
      tenant1: tenant
    } do
      start_time = ~U[2024-01-01 00:00:00Z]
      end_time = ~U[2024-12-31 23:59:59Z]

      {:ok, campaign} =
        CampaignManagement.create_campaign(tenant.id, %{
          name: "Both Dates Campaign",
          start_time: start_time,
          end_time: end_time
        })

      assert campaign.start_time == start_time
      assert campaign.end_time == end_time
      assert campaign.name == "Both Dates Campaign"
      assert DateTime.compare(campaign.start_time, campaign.end_time) == :lt
    end
  end

  describe "delete_campaign/2" do
    test "successfully deletes a campaign belonging to the tenant", %{tenant1: tenant} do
      # Create a campaign
      {:ok, campaign} =
        CampaignManagement.create_campaign(tenant.id, %{
          name: "Test Campaign"
        })

      # Delete the campaign
      assert {:ok, deleted_campaign} = CampaignManagement.delete_campaign(tenant.id, campaign.id)
      assert deleted_campaign.id == campaign.id

      # Verify campaign is deleted
      assert CampaignManagement.get_campaign(tenant.id, campaign.id) == nil
    end

    test "returns error when campaign does not exist", %{tenant1: tenant} do
      non_existent_id = Ecto.UUID.generate()

      assert {:error, :not_found} = CampaignManagement.delete_campaign(tenant.id, non_existent_id)
    end

    test "returns error when campaign belongs to different tenant", %{
      tenant1: tenant1,
      tenant2: tenant2
    } do
      # Create campaign for tenant1
      {:ok, campaign} =
        CampaignManagement.create_campaign(tenant1.id, %{
          name: "Tenant 1 Campaign"
        })

      # Try to delete with tenant2's ID
      assert {:error, :not_found} = CampaignManagement.delete_campaign(tenant2.id, campaign.id)

      # Verify campaign still exists for tenant1
      assert CampaignManagement.get_campaign(tenant1.id, campaign.id) != nil
    end

    test "campaign does not appear in list after deletion", %{tenant1: tenant} do
      # Create multiple campaigns
      {:ok, campaign1} =
        CampaignManagement.create_campaign(tenant.id, %{name: "Campaign 1"})

      {:ok, campaign2} =
        CampaignManagement.create_campaign(tenant.id, %{name: "Campaign 2"})

      # Delete one campaign
      {:ok, _} = CampaignManagement.delete_campaign(tenant.id, campaign1.id)

      # List campaigns
      result = CampaignManagement.list_campaigns(tenant.id)

      # Only campaign2 should remain
      assert length(result.data) == 1
      assert hd(result.data).id == campaign2.id
    end
  end
end
