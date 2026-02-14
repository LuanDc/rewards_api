defmodule CampaignsApi.CampaignManagementTest do
  use CampaignsApi.DataCase

  alias CampaignsApi.CampaignManagement

  setup do
    tenant1 = insert(:tenant)
    tenant2 = insert(:tenant)

    {:ok, tenant1: tenant1, tenant2: tenant2}
  end

  describe "get_campaign/2" do
    test "returns nil when accessing campaign from different tenant (cross-tenant access)", %{
      tenant1: tenant1,
      tenant2: tenant2
    } do
      campaign = insert(:campaign, tenant: tenant1)

      assert CampaignManagement.get_campaign(tenant1.id, campaign.id) != nil
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

      assert {:error, changeset} =
               CampaignManagement.create_campaign(non_existent_tenant_id, %{
                 name: "Test Campaign"
               })

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
      campaigns = insert_list(5, :campaign, tenant: tenant)

      result = CampaignManagement.list_campaigns(tenant.id)

      assert length(result.data) == 5
      assert result.has_more == false
      assert result.next_cursor == nil

      returned_ids = Enum.map(result.data, & &1.id)
      campaign_ids = Enum.map(campaigns, & &1.id)
      assert Enum.all?(campaign_ids, &(&1 in returned_ids))
    end

    test "respects custom limit parameter", %{tenant1: tenant} do
      insert_list(10, :campaign, tenant: tenant)

      result = CampaignManagement.list_campaigns(tenant.id, limit: 3)

      assert length(result.data) == 3
      assert result.has_more == true
      assert result.next_cursor != nil
    end

    test "handles pagination with cursor", %{tenant1: tenant} do
      insert_list(12, :campaign, tenant: tenant)

      first_page = CampaignManagement.list_campaigns(tenant.id, limit: 5)
      assert length(first_page.data) == 5

      if first_page.has_more do
        assert first_page.next_cursor != nil

        second_page =
          CampaignManagement.list_campaigns(tenant.id, limit: 5, cursor: first_page.next_cursor)

        first_page_ids = Enum.map(first_page.data, & &1.id)
        second_page_ids = Enum.map(second_page.data, & &1.id)

        assert Enum.all?(second_page_ids, &(&1 not in first_page_ids)),
               "Second page should not contain campaigns from first page"
      end
    end

    test "enforces maximum limit of 100", %{tenant1: tenant} do
      insert_list(150, :campaign, tenant: tenant)

      result = CampaignManagement.list_campaigns(tenant.id, limit: 200)

      assert length(result.data) <= 100
      assert result.has_more == true
    end

    test "returns campaigns only for specified tenant", %{tenant1: tenant1, tenant2: tenant2} do
      tenant1_campaign = insert(:campaign, tenant: tenant1)
      tenant2_campaign = insert(:campaign, tenant: tenant2)

      tenant1_result = CampaignManagement.list_campaigns(tenant1.id)
      tenant1_ids = Enum.map(tenant1_result.data, & &1.id)

      tenant2_result = CampaignManagement.list_campaigns(tenant2.id)
      tenant2_ids = Enum.map(tenant2_result.data, & &1.id)

      assert tenant1_campaign.id in tenant1_ids
      assert tenant1_campaign.id not in tenant2_ids
      assert tenant2_campaign.id in tenant2_ids
      assert tenant2_campaign.id not in tenant1_ids
    end
  end

  describe "update_campaign/3" do
    test "returns changeset errors when updating with invalid data", %{tenant1: tenant} do
      campaign = insert(:campaign, tenant: tenant)

      assert {:error, changeset} =
               CampaignManagement.update_campaign(tenant.id, campaign.id, %{name: "ab"})

      assert %{name: ["should be at least 3 character(s)"]} = errors_on(changeset)
    end

    test "returns changeset errors when updating with invalid date order", %{tenant1: tenant} do
      campaign = insert(:campaign, tenant: tenant)

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
      campaign = insert(:campaign, tenant: tenant)

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
      campaign = insert(:campaign, tenant: tenant1)

      assert {:error, :not_found} =
               CampaignManagement.update_campaign(tenant2.id, campaign.id, %{
                 name: "Updated Name"
               })

      unchanged = CampaignManagement.get_campaign(tenant1.id, campaign.id)
      assert unchanged.name == campaign.name
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
    test "creates campaign without start_time or end_time", %{tenant1: tenant} do
      {:ok, campaign} =
        CampaignManagement.create_campaign(tenant.id, %{
          name: "No Dates Campaign"
        })

      assert campaign.start_time == nil
      assert campaign.end_time == nil
      assert campaign.name == "No Dates Campaign"
    end

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
      campaign = insert(:campaign, tenant: tenant)

      assert {:ok, deleted_campaign} = CampaignManagement.delete_campaign(tenant.id, campaign.id)
      assert deleted_campaign.id == campaign.id
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
      campaign = insert(:campaign, tenant: tenant1)

      assert {:error, :not_found} = CampaignManagement.delete_campaign(tenant2.id, campaign.id)
      assert CampaignManagement.get_campaign(tenant1.id, campaign.id) != nil
    end

    test "campaign does not appear in list after deletion", %{tenant1: tenant} do
      campaign1 = insert(:campaign, tenant: tenant)
      campaign2 = insert(:campaign, tenant: tenant)

      {:ok, _} = CampaignManagement.delete_campaign(tenant.id, campaign1.id)

      result = CampaignManagement.list_campaigns(tenant.id)

      assert length(result.data) == 1
      assert hd(result.data).id == campaign2.id
    end
  end
end
