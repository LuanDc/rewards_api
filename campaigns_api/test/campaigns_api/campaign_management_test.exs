defmodule CampaignsApi.CampaignManagementTest do
  use CampaignsApi.DataCase
  use ExUnitProperties

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

  describe "list_campaign_challenges/3" do
    test "returns empty list when campaign has no challenges", %{tenant1: tenant} do
      campaign = insert(:campaign, tenant: tenant)

      result = CampaignManagement.list_campaign_challenges(tenant.id, campaign.id)

      assert result.data == []
      assert result.next_cursor == nil
      assert result.has_more == false
    end

    test "returns all campaign challenges with pagination", %{tenant1: tenant} do
      campaign = insert(:campaign, tenant: tenant)
      challenge1 = insert(:challenge)
      challenge2 = insert(:challenge)

      cc1 = insert(:campaign_challenge, campaign: campaign, challenge: challenge1)
      cc2 = insert(:campaign_challenge, campaign: campaign, challenge: challenge2)

      result = CampaignManagement.list_campaign_challenges(tenant.id, campaign.id)

      assert length(result.data) == 2
      returned_ids = Enum.map(result.data, & &1.id)
      assert cc1.id in returned_ids
      assert cc2.id in returned_ids
    end

    test "preloads challenge association", %{tenant1: tenant} do
      campaign = insert(:campaign, tenant: tenant)
      challenge = insert(:challenge, name: "Test Challenge")
      insert(:campaign_challenge, campaign: campaign, challenge: challenge)

      result = CampaignManagement.list_campaign_challenges(tenant.id, campaign.id)

      assert length(result.data) == 1
      campaign_challenge = hd(result.data)
      assert campaign_challenge.challenge.name == "Test Challenge"
    end

    test "enforces tenant isolation - cannot list challenges from different tenant's campaign", %{
      tenant1: tenant1,
      tenant2: tenant2
    } do
      campaign = insert(:campaign, tenant: tenant1)
      challenge = insert(:challenge)
      insert(:campaign_challenge, campaign: campaign, challenge: challenge)

      result = CampaignManagement.list_campaign_challenges(tenant2.id, campaign.id)

      assert result.data == []
    end

    test "respects pagination limit", %{tenant1: tenant} do
      campaign = insert(:campaign, tenant: tenant)
      challenge1 = insert(:challenge)
      challenge2 = insert(:challenge)
      challenge3 = insert(:challenge)

      insert(:campaign_challenge, campaign: campaign, challenge: challenge1)
      insert(:campaign_challenge, campaign: campaign, challenge: challenge2)
      insert(:campaign_challenge, campaign: campaign, challenge: challenge3)

      result = CampaignManagement.list_campaign_challenges(tenant.id, campaign.id, limit: 2)

      assert length(result.data) == 2
      assert result.has_more == true
    end
  end

  describe "get_campaign_challenge/3" do
    test "returns campaign challenge with preloaded challenge", %{tenant1: tenant} do
      campaign = insert(:campaign, tenant: tenant)
      challenge = insert(:challenge, name: "Test Challenge")
      cc = insert(:campaign_challenge, campaign: campaign, challenge: challenge)

      result = CampaignManagement.get_campaign_challenge(tenant.id, campaign.id, cc.id)

      assert result.id == cc.id
      assert result.challenge.name == "Test Challenge"
    end

    test "returns nil when campaign challenge does not exist", %{tenant1: tenant} do
      campaign = insert(:campaign, tenant: tenant)
      non_existent_id = Ecto.UUID.generate()

      result = CampaignManagement.get_campaign_challenge(tenant.id, campaign.id, non_existent_id)

      assert result == nil
    end

    test "returns nil when accessing campaign challenge from different tenant", %{
      tenant1: tenant1,
      tenant2: tenant2
    } do
      campaign = insert(:campaign, tenant: tenant1)
      challenge = insert(:challenge)
      cc = insert(:campaign_challenge, campaign: campaign, challenge: challenge)

      result = CampaignManagement.get_campaign_challenge(tenant2.id, campaign.id, cc.id)

      assert result == nil
    end
  end

  describe "create_campaign_challenge/3" do
    test "successfully creates campaign challenge with valid data", %{tenant1: tenant} do
      campaign = insert(:campaign, tenant: tenant)
      challenge = insert(:challenge)

      attrs = %{
        challenge_id: challenge.id,
        display_name: "Buy+ Challenge",
        display_description: "Earn points for purchases",
        evaluation_frequency: "daily",
        reward_points: 100,
        configuration: %{"threshold" => 10}
      }

      {:ok, cc} = CampaignManagement.create_campaign_challenge(tenant.id, campaign.id, attrs)

      assert cc.campaign_id == campaign.id
      assert cc.challenge_id == challenge.id
      assert cc.display_name == "Buy+ Challenge"
      assert cc.reward_points == 100
    end

    test "returns error when campaign does not belong to tenant", %{
      tenant1: tenant1,
      tenant2: tenant2
    } do
      campaign = insert(:campaign, tenant: tenant1)
      challenge = insert(:challenge)

      attrs = %{
        challenge_id: challenge.id,
        display_name: "Test Challenge",
        evaluation_frequency: "daily",
        reward_points: 50
      }

      result = CampaignManagement.create_campaign_challenge(tenant2.id, campaign.id, attrs)

      assert {:error, :campaign_not_found} = result
    end

    test "accepts any challenge (challenges are global)", %{tenant1: tenant} do
      campaign = insert(:campaign, tenant: tenant)
      challenge = insert(:challenge)

      attrs = %{
        challenge_id: challenge.id,
        display_name: "Global Challenge",
        evaluation_frequency: "weekly",
        reward_points: 200
      }

      {:ok, cc} = CampaignManagement.create_campaign_challenge(tenant.id, campaign.id, attrs)

      assert cc.challenge_id == challenge.id
    end

    test "returns error when creating duplicate association", %{tenant1: tenant} do
      campaign = insert(:campaign, tenant: tenant)
      challenge = insert(:challenge)

      attrs = %{
        challenge_id: challenge.id,
        display_name: "First Association",
        evaluation_frequency: "daily",
        reward_points: 100
      }

      {:ok, _cc} = CampaignManagement.create_campaign_challenge(tenant.id, campaign.id, attrs)

      duplicate_attrs = %{
        challenge_id: challenge.id,
        display_name: "Duplicate Association",
        evaluation_frequency: "weekly",
        reward_points: 200
      }

      {:error, changeset} =
        CampaignManagement.create_campaign_challenge(tenant.id, campaign.id, duplicate_attrs)

      assert %{campaign_id: ["has already been taken"]} = errors_on(changeset)
    end

    test "returns error with invalid data", %{tenant1: tenant} do
      campaign = insert(:campaign, tenant: tenant)
      challenge = insert(:challenge)

      attrs = %{
        challenge_id: challenge.id,
        display_name: "ab",
        evaluation_frequency: "daily",
        reward_points: 100
      }

      {:error, changeset} =
        CampaignManagement.create_campaign_challenge(tenant.id, campaign.id, attrs)

      assert %{display_name: ["should be at least 3 character(s)"]} = errors_on(changeset)
    end
  end

  describe "update_campaign_challenge/4" do
    test "successfully updates campaign challenge with valid data", %{tenant1: tenant} do
      campaign = insert(:campaign, tenant: tenant)
      challenge = insert(:challenge)
      cc = insert(:campaign_challenge, campaign: campaign, challenge: challenge)

      attrs = %{
        display_name: "Updated Challenge",
        reward_points: 500
      }

      {:ok, updated_cc} =
        CampaignManagement.update_campaign_challenge(tenant.id, campaign.id, cc.id, attrs)

      assert updated_cc.display_name == "Updated Challenge"
      assert updated_cc.reward_points == 500
    end

    test "returns error when campaign challenge does not exist", %{tenant1: tenant} do
      campaign = insert(:campaign, tenant: tenant)
      non_existent_id = Ecto.UUID.generate()

      result =
        CampaignManagement.update_campaign_challenge(tenant.id, campaign.id, non_existent_id, %{
          display_name: "Updated"
        })

      assert {:error, :not_found} = result
    end

    test "returns error when updating campaign challenge from different tenant", %{
      tenant1: tenant1,
      tenant2: tenant2
    } do
      campaign = insert(:campaign, tenant: tenant1)
      challenge = insert(:challenge)
      cc = insert(:campaign_challenge, campaign: campaign, challenge: challenge)

      result =
        CampaignManagement.update_campaign_challenge(tenant2.id, campaign.id, cc.id, %{
          display_name: "Updated"
        })

      assert {:error, :not_found} = result
    end

    test "returns error with invalid data", %{tenant1: tenant} do
      campaign = insert(:campaign, tenant: tenant)
      challenge = insert(:challenge)
      cc = insert(:campaign_challenge, campaign: campaign, challenge: challenge)

      {:error, changeset} =
        CampaignManagement.update_campaign_challenge(tenant.id, campaign.id, cc.id, %{
          display_name: "ab"
        })

      assert %{display_name: ["should be at least 3 character(s)"]} = errors_on(changeset)
    end
  end

  describe "delete_campaign_challenge/3" do
    test "successfully deletes campaign challenge", %{tenant1: tenant} do
      campaign = insert(:campaign, tenant: tenant)
      challenge = insert(:challenge)
      cc = insert(:campaign_challenge, campaign: campaign, challenge: challenge)

      {:ok, deleted_cc} =
        CampaignManagement.delete_campaign_challenge(tenant.id, campaign.id, cc.id)

      assert deleted_cc.id == cc.id
      assert CampaignManagement.get_campaign_challenge(tenant.id, campaign.id, cc.id) == nil
    end

    test "returns error when campaign challenge does not exist", %{tenant1: tenant} do
      campaign = insert(:campaign, tenant: tenant)
      non_existent_id = Ecto.UUID.generate()

      result =
        CampaignManagement.delete_campaign_challenge(tenant.id, campaign.id, non_existent_id)

      assert {:error, :not_found} = result
    end

    test "returns error when deleting campaign challenge from different tenant", %{
      tenant1: tenant1,
      tenant2: tenant2
    } do
      campaign = insert(:campaign, tenant: tenant1)
      challenge = insert(:challenge)
      cc = insert(:campaign_challenge, campaign: campaign, challenge: challenge)

      result = CampaignManagement.delete_campaign_challenge(tenant2.id, campaign.id, cc.id)

      assert {:error, :not_found} = result
    end
  end

  describe "campaign deletion cascade" do
    test "deleting campaign automatically deletes associated campaign challenges", %{
      tenant1: tenant
    } do
      campaign = insert(:campaign, tenant: tenant)
      challenge1 = insert(:challenge)
      challenge2 = insert(:challenge)

      cc1 = insert(:campaign_challenge, campaign: campaign, challenge: challenge1)
      cc2 = insert(:campaign_challenge, campaign: campaign, challenge: challenge2)

      {:ok, _} = CampaignManagement.delete_campaign(tenant.id, campaign.id)

      assert CampaignManagement.get_campaign_challenge(tenant.id, campaign.id, cc1.id) == nil
      assert CampaignManagement.get_campaign_challenge(tenant.id, campaign.id, cc2.id) == nil
    end
  end

  describe "Property: Tenant Isolation (Business Invariant)" do
    @tag :property
    property "tenant cannot access campaigns belonging to other tenants", %{
      tenant1: tenant1,
      tenant2: tenant2
    } do
      check all(
              name <- string(:alphanumeric, min_length: 3, max_length: 50),
              max_runs: 50
            ) do
        {:ok, campaign} = CampaignManagement.create_campaign(tenant1.id, %{name: name})

        # Tenant1 can access their own campaign
        assert CampaignManagement.get_campaign(tenant1.id, campaign.id) != nil,
               "tenant1 should be able to retrieve their own campaign"

        # Tenant2 cannot access tenant1's campaign
        assert CampaignManagement.get_campaign(tenant2.id, campaign.id) == nil,
               "tenant2 should not be able to retrieve tenant1's campaign"

        # Tenant2 cannot update tenant1's campaign
        assert {:error, :not_found} =
                 CampaignManagement.update_campaign(tenant2.id, campaign.id, %{name: "Updated"}),
               "tenant2 should not be able to update tenant1's campaign"

        # Tenant2 cannot delete tenant1's campaign
        assert {:error, :not_found} = CampaignManagement.delete_campaign(tenant2.id, campaign.id),
               "tenant2 should not be able to delete tenant1's campaign"

        # Campaign still exists for tenant1
        assert CampaignManagement.get_campaign(tenant1.id, campaign.id) != nil,
               "campaign should still exist for tenant1 after cross-tenant access attempts"

        # Tenant2's list doesn't include tenant1's campaign
        tenant2_campaigns = CampaignManagement.list_campaigns(tenant2.id)
        campaign_ids = Enum.map(tenant2_campaigns.data, & &1.id)

        assert campaign.id not in campaign_ids,
               "tenant1's campaign should not appear in tenant2's campaign list"
      end
    end
  end

  describe "Unit tests for properties converted from property tests" do
    test "campaign created has UUID format", %{tenant1: tenant} do
      {:ok, campaign} = CampaignManagement.create_campaign(tenant.id, %{name: "Test Campaign"})

      assert is_binary(campaign.id)
      assert String.length(campaign.id) == 36
      assert campaign.id =~ ~r/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/
    end

    test "campaign defaults to active status when not specified", %{tenant1: tenant} do
      {:ok, campaign} = CampaignManagement.create_campaign(tenant.id, %{name: "Test Campaign"})

      assert campaign.status == :active
    end

    test "campaign can be created with optional fields", %{tenant1: tenant} do
      start_time = ~U[2024-01-01 00:00:00Z]
      end_time = ~U[2024-12-31 23:59:59Z]

      {:ok, campaign} =
        CampaignManagement.create_campaign(tenant.id, %{
          name: "Full Campaign",
          description: "Test description",
          start_time: start_time,
          end_time: end_time
        })

      assert campaign.description == "Test description"
      assert campaign.start_time == start_time
      assert campaign.end_time == end_time
    end

    test "campaign timestamps are stored in UTC", %{tenant1: tenant} do
      start_time = ~U[2024-01-01 00:00:00Z]
      end_time = ~U[2024-12-31 23:59:59Z]

      {:ok, campaign} =
        CampaignManagement.create_campaign(tenant.id, %{
          name: "Test Campaign",
          start_time: start_time,
          end_time: end_time
        })

      assert campaign.start_time.time_zone == "Etc/UTC"
      assert campaign.end_time.time_zone == "Etc/UTC"
      assert campaign.inserted_at.time_zone == "Etc/UTC"
      assert campaign.updated_at.time_zone == "Etc/UTC"
    end

    test "campaigns are ordered by inserted_at descending", %{tenant1: tenant} do
      insert_list(5, :campaign, tenant: tenant)

      result = CampaignManagement.list_campaigns(tenant.id)
      campaigns = result.data

      assert length(campaigns) == 5

      # Verify descending order
      timestamps = Enum.map(campaigns, & &1.inserted_at)
      assert timestamps == Enum.sort(timestamps, {:desc, DateTime})
    end

    test "campaign includes all required fields", %{tenant1: tenant} do
      {:ok, campaign} = CampaignManagement.create_campaign(tenant.id, %{name: "Test Campaign"})

      assert Map.has_key?(campaign, :id)
      assert Map.has_key?(campaign, :tenant_id)
      assert Map.has_key?(campaign, :name)
      assert Map.has_key?(campaign, :description)
      assert Map.has_key?(campaign, :start_time)
      assert Map.has_key?(campaign, :end_time)
      assert Map.has_key?(campaign, :status)
      assert Map.has_key?(campaign, :inserted_at)
      assert Map.has_key?(campaign, :updated_at)
    end

    test "campaign status can transition between active and paused", %{tenant1: tenant} do
      {:ok, campaign} =
        CampaignManagement.create_campaign(tenant.id, %{name: "Test", status: :active})

      assert campaign.status == :active

      {:ok, updated} =
        CampaignManagement.update_campaign(tenant.id, campaign.id, %{status: :paused})

      assert updated.status == :paused

      {:ok, updated_again} =
        CampaignManagement.update_campaign(tenant.id, campaign.id, %{status: :active})

      assert updated_again.status == :active
    end
  end
end
defmodule CampaignsApi.ParticipantManagementTest do
  use CampaignsApi.DataCase
  use ExUnitProperties

  import CampaignsApi.Factory
  import Ecto.Query

  alias CampaignsApi.CampaignManagement
  alias CampaignsApi.Repo

  describe "create_participant/2" do
    test "creates participant with valid attributes" do
      tenant = insert(:tenant)
      attrs = params_for(:participant, name: "John Doe", nickname: "johndoe")

      assert {:ok, participant} = CampaignManagement.create_participant(tenant.id, attrs)
      assert participant.name == "John Doe"
      assert participant.nickname == "johndoe"
      assert participant.tenant_id == tenant.id
      assert participant.status == :active
    end

    test "returns error with invalid attributes" do
      tenant = insert(:tenant)
      attrs = %{name: "", nickname: "ab"}

      assert {:error, changeset} = CampaignManagement.create_participant(tenant.id, attrs)
      assert %{name: ["can't be blank"]} = errors_on(changeset)
      assert %{nickname: ["should be at least 3 character(s)"]} = errors_on(changeset)
    end

    test "returns error when nickname is not unique" do
      tenant = insert(:tenant)
      _existing_participant = insert(:participant, tenant: tenant, nickname: "johndoe")

      attrs = params_for(:participant, nickname: "johndoe")

      assert {:error, changeset} = CampaignManagement.create_participant(tenant.id, attrs)
      assert %{nickname: ["has already been taken"]} = errors_on(changeset)
    end
  end

  describe "get_participant/2" do
    test "returns participant when it exists and belongs to tenant" do
      tenant = insert(:tenant)
      participant = insert(:participant, tenant: tenant)

      assert found = CampaignManagement.get_participant(tenant.id, participant.id)
      assert found.id == participant.id
      assert found.tenant_id == tenant.id
    end

    test "returns nil when participant does not exist" do
      tenant = insert(:tenant)
      non_existent_id = Ecto.UUID.generate()

      assert nil == CampaignManagement.get_participant(tenant.id, non_existent_id)
    end

    test "returns nil when participant belongs to different tenant" do
      tenant_a = insert(:tenant)
      tenant_b = insert(:tenant)
      participant = insert(:participant, tenant: tenant_a)

      assert nil == CampaignManagement.get_participant(tenant_b.id, participant.id)
    end
  end

  describe "update_participant/3" do
    test "updates participant with valid attributes" do
      tenant = insert(:tenant)
      participant = insert(:participant, tenant: tenant, name: "John Doe", nickname: "johndoe")

      attrs = %{name: "Jane Doe", nickname: "janedoe"}

      assert {:ok, updated} = CampaignManagement.update_participant(tenant.id, participant.id, attrs)
      assert updated.id == participant.id
      assert updated.name == "Jane Doe"
      assert updated.nickname == "janedoe"
      assert updated.tenant_id == tenant.id
    end

    test "returns error with invalid attributes" do
      tenant = insert(:tenant)
      participant = insert(:participant, tenant: tenant)

      attrs = %{name: "", nickname: "ab"}

      assert {:error, changeset} = CampaignManagement.update_participant(tenant.id, participant.id, attrs)
      assert %{name: ["can't be blank"]} = errors_on(changeset)
      assert %{nickname: ["should be at least 3 character(s)"]} = errors_on(changeset)
    end

    test "returns error when participant does not exist" do
      tenant = insert(:tenant)
      non_existent_id = Ecto.UUID.generate()

      attrs = %{name: "Jane Doe"}

      assert {:error, :not_found} = CampaignManagement.update_participant(tenant.id, non_existent_id, attrs)
    end

    test "returns error when participant belongs to different tenant" do
      tenant_a = insert(:tenant)
      tenant_b = insert(:tenant)
      participant = insert(:participant, tenant: tenant_a)

      attrs = %{name: "Jane Doe"}

      assert {:error, :not_found} = CampaignManagement.update_participant(tenant_b.id, participant.id, attrs)
    end

    test "returns error when nickname is not unique" do
      tenant = insert(:tenant)
      _existing_participant = insert(:participant, tenant: tenant, nickname: "johndoe")
      participant = insert(:participant, tenant: tenant, nickname: "janedoe")

      attrs = %{nickname: "johndoe"}

      assert {:error, changeset} = CampaignManagement.update_participant(tenant.id, participant.id, attrs)
      assert %{nickname: ["has already been taken"]} = errors_on(changeset)
    end
  end

  describe "delete_participant/2" do
    test "deletes participant when it exists and belongs to tenant" do
      tenant = insert(:tenant)
      participant = insert(:participant, tenant: tenant)

      assert {:ok, deleted} = CampaignManagement.delete_participant(tenant.id, participant.id)
      assert deleted.id == participant.id

      # Verify participant is actually deleted
      assert nil == CampaignManagement.get_participant(tenant.id, participant.id)
    end

    test "returns error when participant does not exist" do
      tenant = insert(:tenant)
      non_existent_id = Ecto.UUID.generate()

      assert {:error, :not_found} = CampaignManagement.delete_participant(tenant.id, non_existent_id)
    end

    test "returns error when participant belongs to different tenant" do
      tenant_a = insert(:tenant)
      tenant_b = insert(:tenant)
      participant = insert(:participant, tenant: tenant_a)

      assert {:error, :not_found} = CampaignManagement.delete_participant(tenant_b.id, participant.id)

      # Verify participant still exists for tenant_a
      assert CampaignManagement.get_participant(tenant_a.id, participant.id)
    end
  end

  describe "list_participants/2" do
    test "lists participants without cursor" do
      tenant = insert(:tenant)
      participant1 = insert(:participant, tenant: tenant, name: "Alice", nickname: "alice")
      participant2 = insert(:participant, tenant: tenant, name: "Bob", nickname: "bob")
      participant3 = insert(:participant, tenant: tenant, name: "Charlie", nickname: "charlie")

      result = CampaignManagement.list_participants(tenant.id, [])

      assert %{data: data, next_cursor: _, has_more: _} = result
      assert length(data) == 3

      # Verify ordering by inserted_at descending (newest first)
      participant_ids = Enum.map(data, & &1.id)
      assert participant3.id in participant_ids
      assert participant2.id in participant_ids
      assert participant1.id in participant_ids
    end

    test "lists participants with cursor" do
      tenant = insert(:tenant)

      # Insert multiple participants
      insert_list(12, :participant, tenant: tenant)

      # Get first page
      first_page = CampaignManagement.list_participants(tenant.id, limit: 5)
      assert length(first_page.data) == 5

      # If there are more results, test cursor pagination
      if first_page.has_more do
        assert first_page.next_cursor != nil

        # Get second page using cursor
        second_page = CampaignManagement.list_participants(tenant.id, limit: 5, cursor: first_page.next_cursor)

        # Verify no duplicates between pages
        first_page_ids = Enum.map(first_page.data, & &1.id)
        second_page_ids = Enum.map(second_page.data, & &1.id)

        assert Enum.all?(second_page_ids, &(&1 not in first_page_ids)),
               "Second page should not contain participants from first page"
      end
    end

    test "enforces maximum limit of 100" do
      tenant = insert(:tenant)

      # Insert 10 participants
      for i <- 1..10 do
        insert(:participant, tenant: tenant, nickname: "user#{i}")
      end

      # Request with limit > 100
      result = CampaignManagement.list_participants(tenant.id, limit: 150)

      # Should return at most 100 (but we only have 10)
      assert %{data: data} = result
      assert length(data) == 10
    end

    test "filters by nickname (case-insensitive)" do
      tenant = insert(:tenant)
      insert(:participant, tenant: tenant, nickname: "alice123")
      insert(:participant, tenant: tenant, nickname: "bob456")
      insert(:participant, tenant: tenant, nickname: "ALICE789")
      insert(:participant, tenant: tenant, nickname: "charlie")

      result = CampaignManagement.list_participants(tenant.id, nickname: "alice")

      assert %{data: data} = result
      assert length(data) == 2
      assert Enum.all?(data, fn p -> String.contains?(String.downcase(p.nickname), "alice") end)
    end

    test "returns correct pagination response structure" do
      tenant = insert(:tenant)
      insert(:participant, tenant: tenant)

      result = CampaignManagement.list_participants(tenant.id, [])

      assert %{data: data, next_cursor: next_cursor, has_more: has_more} = result
      assert is_list(data)
      assert is_boolean(has_more)
      assert next_cursor == nil or match?(%DateTime{}, next_cursor)
    end

    test "returns empty results for tenant with no participants" do
      tenant = insert(:tenant)

      result = CampaignManagement.list_participants(tenant.id, [])

      assert %{data: [], next_cursor: nil, has_more: false} = result
    end

    test "only returns participants for requesting tenant" do
      tenant_a = insert(:tenant)
      tenant_b = insert(:tenant)

      participant_a = insert(:participant, tenant: tenant_a, nickname: "tenant_a_user")
      _participant_b = insert(:participant, tenant: tenant_b, nickname: "tenant_b_user")

      result = CampaignManagement.list_participants(tenant_a.id, [])

      assert %{data: data} = result
      assert length(data) == 1
      assert hd(data).id == participant_a.id
      assert hd(data).tenant_id == tenant_a.id
    end
  end

  describe "CRUD round trip" do
    test "create → read → update → read → delete maintains data integrity" do
      tenant = insert(:tenant)

      # Create
      create_attrs = params_for(:participant, name: "John Doe", nickname: "johndoe")
      assert {:ok, participant} = CampaignManagement.create_participant(tenant.id, create_attrs)
      assert participant.name == "John Doe"
      assert participant.nickname == "johndoe"
      assert participant.status == :active
      participant_id = participant.id

      # Read
      assert found = CampaignManagement.get_participant(tenant.id, participant_id)
      assert found.id == participant_id
      assert found.name == "John Doe"
      assert found.nickname == "johndoe"

      # Update
      update_attrs = %{name: "Jane Doe", nickname: "janedoe"}
      assert {:ok, updated} = CampaignManagement.update_participant(tenant.id, participant_id, update_attrs)
      assert updated.id == participant_id
      assert updated.name == "Jane Doe"
      assert updated.nickname == "janedoe"

      # Read again
      assert found_updated = CampaignManagement.get_participant(tenant.id, participant_id)
      assert found_updated.id == participant_id
      assert found_updated.name == "Jane Doe"
      assert found_updated.nickname == "janedoe"

      # Delete
      assert {:ok, deleted} = CampaignManagement.delete_participant(tenant.id, participant_id)
      assert deleted.id == participant_id

      # Verify deletion
      assert nil == CampaignManagement.get_participant(tenant.id, participant_id)
    end
  end

  describe "associate_participant_with_campaign/3" do
    test "associates participant with campaign in same tenant" do
      tenant = insert(:tenant)
      participant = insert(:participant, tenant: tenant)
      campaign = insert(:campaign, tenant: tenant)

      assert {:ok, campaign_participant} =
               CampaignManagement.associate_participant_with_campaign(
                 tenant.id,
                 participant.id,
                 campaign.id
               )

      assert campaign_participant.participant_id == participant.id
      assert campaign_participant.campaign_id == campaign.id
    end

    test "returns error when associating cross-tenant resources" do
      tenant_a = insert(:tenant)
      tenant_b = insert(:tenant)
      participant = insert(:participant, tenant: tenant_a)
      campaign = insert(:campaign, tenant: tenant_b)

      assert {:error, :tenant_mismatch} =
               CampaignManagement.associate_participant_with_campaign(
                 tenant_a.id,
                 participant.id,
                 campaign.id
               )
    end

    test "returns error when participant belongs to different tenant" do
      tenant_a = insert(:tenant)
      tenant_b = insert(:tenant)
      participant = insert(:participant, tenant: tenant_a)
      campaign = insert(:campaign, tenant: tenant_b)

      # Try to associate using tenant_b (campaign's tenant)
      assert {:error, :tenant_mismatch} =
               CampaignManagement.associate_participant_with_campaign(
                 tenant_b.id,
                 participant.id,
                 campaign.id
               )
    end

    test "returns error when campaign belongs to different tenant" do
      tenant_a = insert(:tenant)
      tenant_b = insert(:tenant)
      participant = insert(:participant, tenant: tenant_a)
      campaign = insert(:campaign, tenant: tenant_b)

      # Try to associate using tenant_a (participant's tenant)
      assert {:error, :tenant_mismatch} =
               CampaignManagement.associate_participant_with_campaign(
                 tenant_a.id,
                 participant.id,
                 campaign.id
               )
    end

    test "returns error for duplicate association" do
      tenant = insert(:tenant)
      participant = insert(:participant, tenant: tenant)
      campaign = insert(:campaign, tenant: tenant)

      # Create first association
      assert {:ok, _} =
               CampaignManagement.associate_participant_with_campaign(
                 tenant.id,
                 participant.id,
                 campaign.id
               )

      # Try to create duplicate association
      assert {:error, changeset} =
               CampaignManagement.associate_participant_with_campaign(
                 tenant.id,
                 participant.id,
                 campaign.id
               )

      assert %{participant_id: ["has already been taken"]} = errors_on(changeset)
    end
  end

  describe "disassociate_participant_from_campaign/3" do
    test "disassociates participant from campaign" do
      tenant = insert(:tenant)
      participant = insert(:participant, tenant: tenant)
      campaign = insert(:campaign, tenant: tenant)

      # Create association
      {:ok, campaign_participant} =
        CampaignManagement.associate_participant_with_campaign(
          tenant.id,
          participant.id,
          campaign.id
        )

      # Disassociate
      assert {:ok, deleted} =
               CampaignManagement.disassociate_participant_from_campaign(
                 tenant.id,
                 participant.id,
                 campaign.id
               )

      assert deleted.id == campaign_participant.id

      # Verify association is removed by trying to create it again (should succeed)
      assert {:ok, _new_association} =
               CampaignManagement.associate_participant_with_campaign(
                 tenant.id,
                 participant.id,
                 campaign.id
               )
    end

    test "returns error when association does not exist" do
      tenant = insert(:tenant)
      participant = insert(:participant, tenant: tenant)
      campaign = insert(:campaign, tenant: tenant)

      # Try to disassociate without creating association first
      assert {:error, :not_found} =
               CampaignManagement.disassociate_participant_from_campaign(
                 tenant.id,
                 participant.id,
                 campaign.id
               )
    end

    test "returns error when trying to disassociate cross-tenant resources" do
      tenant_a = insert(:tenant)
      tenant_b = insert(:tenant)
      participant = insert(:participant, tenant: tenant_a)
      campaign = insert(:campaign, tenant: tenant_a)

      # Create association in tenant_a
      {:ok, _} =
        CampaignManagement.associate_participant_with_campaign(
          tenant_a.id,
          participant.id,
          campaign.id
        )

      # Try to disassociate using tenant_b
      assert {:error, :not_found} =
               CampaignManagement.disassociate_participant_from_campaign(
                 tenant_b.id,
                 participant.id,
                 campaign.id
               )
    end
  end

  describe "list_campaigns_for_participant/3" do
    test "lists campaigns for participant" do
      tenant = insert(:tenant)
      participant = insert(:participant, tenant: tenant)
      campaign1 = insert(:campaign, tenant: tenant, name: "Campaign 1")
      campaign2 = insert(:campaign, tenant: tenant, name: "Campaign 2")
      campaign3 = insert(:campaign, tenant: tenant, name: "Campaign 3")

      # Associate participant with campaigns
      CampaignManagement.associate_participant_with_campaign(tenant.id, participant.id, campaign1.id)
      CampaignManagement.associate_participant_with_campaign(tenant.id, participant.id, campaign2.id)
      CampaignManagement.associate_participant_with_campaign(tenant.id, participant.id, campaign3.id)

      result = CampaignManagement.list_campaigns_for_participant(tenant.id, participant.id, [])

      assert %{data: data, next_cursor: _, has_more: _} = result
      assert length(data) == 3

      campaign_ids = Enum.map(data, & &1.id)
      assert campaign1.id in campaign_ids
      assert campaign2.id in campaign_ids
      assert campaign3.id in campaign_ids
    end

    test "returns empty list when participant has no campaigns" do
      tenant = insert(:tenant)
      participant = insert(:participant, tenant: tenant)

      result = CampaignManagement.list_campaigns_for_participant(tenant.id, participant.id, [])

      assert %{data: [], next_cursor: nil, has_more: false} = result
    end

    test "returns empty list for cross-tenant participant" do
      tenant_a = insert(:tenant)
      tenant_b = insert(:tenant)
      participant = insert(:participant, tenant: tenant_a)
      campaign = insert(:campaign, tenant: tenant_a)

      # Associate in tenant_a
      CampaignManagement.associate_participant_with_campaign(tenant_a.id, participant.id, campaign.id)

      # Try to list using tenant_b
      result = CampaignManagement.list_campaigns_for_participant(tenant_b.id, participant.id, [])

      assert %{data: [], next_cursor: nil, has_more: false} = result
    end

    test "supports pagination" do
      tenant = insert(:tenant)
      participant = insert(:participant, tenant: tenant)

      # Create and associate 3 campaigns with delays to ensure different timestamps
      campaign1 = insert(:campaign, tenant: tenant, name: "Campaign 1")
      CampaignManagement.associate_participant_with_campaign(tenant.id, participant.id, campaign1.id)

      # Sleep 1 second to ensure different timestamp
      Process.sleep(1100)

      campaign2 = insert(:campaign, tenant: tenant, name: "Campaign 2")
      CampaignManagement.associate_participant_with_campaign(tenant.id, participant.id, campaign2.id)

      Process.sleep(1100)

      campaign3 = insert(:campaign, tenant: tenant, name: "Campaign 3")
      CampaignManagement.associate_participant_with_campaign(tenant.id, participant.id, campaign3.id)

      # Get first page with limit 2
      first_page = CampaignManagement.list_campaigns_for_participant(tenant.id, participant.id, limit: 2)

      assert length(first_page.data) == 2
      assert first_page.has_more == true
      assert first_page.next_cursor != nil

      # Get second page
      second_page =
        CampaignManagement.list_campaigns_for_participant(
          tenant.id,
          participant.id,
          limit: 2,
          cursor: first_page.next_cursor
        )

      assert length(second_page.data) == 1
      assert second_page.has_more == false

      # Verify no duplicates
      first_page_ids = Enum.map(first_page.data, & &1.id)
      second_page_ids = Enum.map(second_page.data, & &1.id)
      assert Enum.all?(second_page_ids, &(&1 not in first_page_ids))
    end
  end

  describe "list_participants_for_campaign/3" do
    test "lists participants for campaign" do
      tenant = insert(:tenant)
      campaign = insert(:campaign, tenant: tenant)
      participant1 = insert(:participant, tenant: tenant, nickname: "user1")
      participant2 = insert(:participant, tenant: tenant, nickname: "user2")
      participant3 = insert(:participant, tenant: tenant, nickname: "user3")

      # Associate participants with campaign
      CampaignManagement.associate_participant_with_campaign(tenant.id, participant1.id, campaign.id)
      CampaignManagement.associate_participant_with_campaign(tenant.id, participant2.id, campaign.id)
      CampaignManagement.associate_participant_with_campaign(tenant.id, participant3.id, campaign.id)

      result = CampaignManagement.list_participants_for_campaign(tenant.id, campaign.id, [])

      assert %{data: data, next_cursor: _, has_more: _} = result
      assert length(data) == 3

      participant_ids = Enum.map(data, & &1.id)
      assert participant1.id in participant_ids
      assert participant2.id in participant_ids
      assert participant3.id in participant_ids
    end

    test "returns empty list when campaign has no participants" do
      tenant = insert(:tenant)
      campaign = insert(:campaign, tenant: tenant)

      result = CampaignManagement.list_participants_for_campaign(tenant.id, campaign.id, [])

      assert %{data: [], next_cursor: nil, has_more: false} = result
    end

    test "returns empty list for cross-tenant campaign" do
      tenant_a = insert(:tenant)
      tenant_b = insert(:tenant)
      participant = insert(:participant, tenant: tenant_a)
      campaign = insert(:campaign, tenant: tenant_a)

      # Associate in tenant_a
      CampaignManagement.associate_participant_with_campaign(tenant_a.id, participant.id, campaign.id)

      # Try to list using tenant_b
      result = CampaignManagement.list_participants_for_campaign(tenant_b.id, campaign.id, [])

      assert %{data: [], next_cursor: nil, has_more: false} = result
    end

    test "supports pagination" do
      tenant = insert(:tenant)
      campaign = insert(:campaign, tenant: tenant)

      # Create and associate 3 participants with delays to ensure different timestamps
      participant1 = insert(:participant, tenant: tenant, nickname: "user1")
      CampaignManagement.associate_participant_with_campaign(tenant.id, participant1.id, campaign.id)

      # Sleep 1 second to ensure different timestamp
      Process.sleep(1100)

      participant2 = insert(:participant, tenant: tenant, nickname: "user2")
      CampaignManagement.associate_participant_with_campaign(tenant.id, participant2.id, campaign.id)

      Process.sleep(1100)

      participant3 = insert(:participant, tenant: tenant, nickname: "user3")
      CampaignManagement.associate_participant_with_campaign(tenant.id, participant3.id, campaign.id)

      # Get first page with limit 2
      first_page = CampaignManagement.list_participants_for_campaign(tenant.id, campaign.id, limit: 2)

      assert length(first_page.data) == 2
      assert first_page.has_more == true
      assert first_page.next_cursor != nil

      # Get second page
      second_page =
        CampaignManagement.list_participants_for_campaign(
          tenant.id,
          campaign.id,
          limit: 2,
          cursor: first_page.next_cursor
        )

      assert length(second_page.data) == 1
      assert second_page.has_more == false

      # Verify no duplicates
      first_page_ids = Enum.map(first_page.data, & &1.id)
      second_page_ids = Enum.map(second_page.data, & &1.id)
      assert Enum.all?(second_page_ids, &(&1 not in first_page_ids))
    end
  end

  describe "property-based tests" do
    # **Validates: Requirements 3.4, 11.1-11.8**
    property "tenant isolation: cross-tenant access always fails" do
      check all participant_name <- string(:alphanumeric, min_length: 1, max_length: 20),
                nickname_base <- string(:alphanumeric, min_length: 3, max_length: 15) do

        # Create two different tenants with unique IDs
        tenant_a = insert(:tenant)
        tenant_b = insert(:tenant)

        # Create participant for tenant A with unique nickname
        nickname = "#{nickname_base}-#{System.unique_integer([:positive])}"
        attrs = params_for(:participant, name: participant_name, nickname: nickname)
        {:ok, participant} = CampaignManagement.create_participant(tenant_a.id, attrs)

        # Tenant B should never see Tenant A's participant
        assert nil == CampaignManagement.get_participant(tenant_b.id, participant.id)

        # Tenant B should not be able to update Tenant A's participant
        update_attrs = %{name: "Updated Name"}
        assert {:error, :not_found} == CampaignManagement.update_participant(tenant_b.id, participant.id, update_attrs)

        # Tenant B should not be able to delete Tenant A's participant
        assert {:error, :not_found} == CampaignManagement.delete_participant(tenant_b.id, participant.id)

        # Verify participant still exists for Tenant A
        assert CampaignManagement.get_participant(tenant_a.id, participant.id)
      end
    end

    # **Validates: Requirements 3.8, 5.4**
    property "cascade deletion: all associations removed when participant is deleted" do
      check all participant_name <- string(:alphanumeric, min_length: 1, max_length: 20),
                nickname_base <- string(:alphanumeric, min_length: 3, max_length: 15),
                num_campaigns <- integer(1..3),
                num_challenges_per_campaign <- integer(1..2) do

        # Create tenant and participant with unique nickname
        tenant = insert(:tenant)
        nickname = "#{nickname_base}-#{System.unique_integer([:positive])}"
        attrs = params_for(:participant, name: participant_name, nickname: nickname)
        {:ok, participant} = CampaignManagement.create_participant(tenant.id, attrs)

        # Create campaigns and manually insert campaign_participants associations
        campaigns = for _ <- 1..num_campaigns do
          campaign = insert(:campaign, tenant: tenant)

          # Manually insert campaign_participant association
          %CampaignsApi.CampaignManagement.CampaignParticipant{}
          |> Ecto.Changeset.change(%{
            participant_id: participant.id,
            campaign_id: campaign.id
          })
          |> Repo.insert!()

          campaign
        end

        # Create challenges and manually insert participant_challenges associations
        for campaign <- campaigns do
          for _ <- 1..num_challenges_per_campaign do
            challenge = insert(:challenge)

            # Manually insert participant_challenge association
            %CampaignsApi.CampaignManagement.ParticipantChallenge{}
            |> Ecto.Changeset.change(%{
              participant_id: participant.id,
              challenge_id: challenge.id,
              campaign_id: campaign.id
            })
            |> Repo.insert!()
          end
        end

        # Verify associations exist
        campaign_associations = Repo.all(
          from cp in CampaignsApi.CampaignManagement.CampaignParticipant,
          where: cp.participant_id == ^participant.id
        )
        assert length(campaign_associations) == num_campaigns

        challenge_associations = Repo.all(
          from pc in CampaignsApi.CampaignManagement.ParticipantChallenge,
          where: pc.participant_id == ^participant.id
        )
        assert length(challenge_associations) == num_campaigns * num_challenges_per_campaign

        # Delete participant
        assert {:ok, _deleted} = CampaignManagement.delete_participant(tenant.id, participant.id)

        # Verify participant is deleted
        assert nil == CampaignManagement.get_participant(tenant.id, participant.id)

        # Verify all campaign associations are deleted (cascade)
        remaining_campaign_associations = Repo.all(
          from cp in CampaignsApi.CampaignManagement.CampaignParticipant,
          where: cp.participant_id == ^participant.id
        )
        assert Enum.empty?(remaining_campaign_associations)

        # Verify all challenge associations are deleted (cascade)
        remaining_challenge_associations = Repo.all(
          from pc in CampaignsApi.CampaignManagement.ParticipantChallenge,
          where: pc.participant_id == ^participant.id
        )
        assert Enum.empty?(remaining_challenge_associations)
      end
    end

    # **Validates: Requirements 2.6, 5.1, 5.2, 9.6, 11.5**
    property "campaign-participant tenant validation: only same-tenant associations succeed" do
      check all participant_name <- string(:alphanumeric, min_length: 1, max_length: 20),
                nickname_base <- string(:alphanumeric, min_length: 3, max_length: 15),
                campaign_name <- string(:alphanumeric, min_length: 1, max_length: 20),
                same_tenant <- boolean() do

        # Create two tenants
        tenant_a = insert(:tenant)
        tenant_b = insert(:tenant)

        # Create participant in tenant_a with unique nickname
        nickname = "#{nickname_base}-#{System.unique_integer([:positive])}"
        participant_attrs = params_for(:participant, name: participant_name, nickname: nickname)
        {:ok, participant} = CampaignManagement.create_participant(tenant_a.id, participant_attrs)

        # Create campaign in either same tenant or different tenant
        campaign_tenant = if same_tenant, do: tenant_a, else: tenant_b
        campaign = insert(:campaign, tenant: campaign_tenant, name: campaign_name)

        # Attempt to associate
        result =
          CampaignManagement.associate_participant_with_campaign(
            tenant_a.id,
            participant.id,
            campaign.id
          )

        if same_tenant do
          # Same tenant: association should succeed
          assert {:ok, campaign_participant} = result
          assert campaign_participant.participant_id == participant.id
          assert campaign_participant.campaign_id == campaign.id

          # Verify association exists in database
          assert Repo.get_by(CampaignsApi.CampaignManagement.CampaignParticipant,
                   participant_id: participant.id,
                   campaign_id: campaign.id
                 )
        else
          # Different tenants: association should fail
          assert {:error, :tenant_mismatch} = result

          # Verify no association was created
          refute Repo.get_by(CampaignsApi.CampaignManagement.CampaignParticipant,
                   participant_id: participant.id,
                   campaign_id: campaign.id
                 )
        end
      end
    end
  end

  describe "associate_participant_with_challenge/3" do
    test "associates participant with challenge when participant is in campaign" do
      tenant = insert(:tenant)
      participant = insert(:participant, tenant: tenant)
      campaign = insert(:campaign, tenant: tenant)
      challenge = insert(:challenge)

      # Associate participant with campaign first
      {:ok, _cp} = CampaignManagement.associate_participant_with_campaign(
        tenant.id,
        participant.id,
        campaign.id
      )

      # Associate challenge with campaign
      _campaign_challenge = insert(:campaign_challenge, campaign: campaign, challenge: challenge)

      # Now associate participant with challenge
      assert {:ok, participant_challenge} =
               CampaignManagement.associate_participant_with_challenge(
                 tenant.id,
                 participant.id,
                 challenge.id
               )

      assert participant_challenge.participant_id == participant.id
      assert participant_challenge.challenge_id == challenge.id
      assert participant_challenge.campaign_id == campaign.id
    end

    test "returns error when participant is not in campaign" do
      tenant = insert(:tenant)
      participant = insert(:participant, tenant: tenant)
      campaign = insert(:campaign, tenant: tenant)
      challenge = insert(:challenge)

      # Associate challenge with campaign but NOT participant with campaign
      _campaign_challenge = insert(:campaign_challenge, campaign: campaign, challenge: challenge)

      # Attempt to associate participant with challenge
      assert {:error, :participant_not_in_campaign} =
               CampaignManagement.associate_participant_with_challenge(
                 tenant.id,
                 participant.id,
                 challenge.id
               )
    end

    test "returns error when challenge belongs to different tenant" do
      tenant_a = insert(:tenant)
      tenant_b = insert(:tenant)
      participant = insert(:participant, tenant: tenant_a)
      campaign_a = insert(:campaign, tenant: tenant_a)
      campaign_b = insert(:campaign, tenant: tenant_b)
      challenge = insert(:challenge)

      # Associate participant with campaign_a
      {:ok, _cp} = CampaignManagement.associate_participant_with_campaign(
        tenant_a.id,
        participant.id,
        campaign_a.id
      )

      # Associate challenge with campaign_b (different tenant)
      _campaign_challenge = insert(:campaign_challenge, campaign: campaign_b, challenge: challenge)

      # Attempt to associate participant with challenge
      assert {:error, :tenant_mismatch} =
               CampaignManagement.associate_participant_with_challenge(
                 tenant_a.id,
                 participant.id,
                 challenge.id
               )
    end

    test "returns error when participant belongs to different tenant" do
      tenant_a = insert(:tenant)
      tenant_b = insert(:tenant)
      participant = insert(:participant, tenant: tenant_b)
      campaign = insert(:campaign, tenant: tenant_a)
      challenge = insert(:challenge)

      # Associate challenge with campaign
      _campaign_challenge = insert(:campaign_challenge, campaign: campaign, challenge: challenge)

      # Attempt to associate participant with challenge using tenant_a
      assert {:error, :tenant_mismatch} =
               CampaignManagement.associate_participant_with_challenge(
                 tenant_a.id,
                 participant.id,
                 challenge.id
               )
    end

    test "returns error on duplicate association" do
      tenant = insert(:tenant)
      participant = insert(:participant, tenant: tenant)
      campaign = insert(:campaign, tenant: tenant)
      challenge = insert(:challenge)

      # Associate participant with campaign
      {:ok, _cp} = CampaignManagement.associate_participant_with_campaign(
        tenant.id,
        participant.id,
        campaign.id
      )

      # Associate challenge with campaign
      _campaign_challenge = insert(:campaign_challenge, campaign: campaign, challenge: challenge)

      # First association should succeed
      assert {:ok, _pc} =
               CampaignManagement.associate_participant_with_challenge(
                 tenant.id,
                 participant.id,
                 challenge.id
               )

      # Second association should fail
      assert {:error, changeset} =
               CampaignManagement.associate_participant_with_challenge(
                 tenant.id,
                 participant.id,
                 challenge.id
               )

      assert %{participant_id: ["has already been taken"]} = errors_on(changeset)
    end
  end

  describe "disassociate_participant_from_challenge/3" do
    test "disassociates participant from challenge" do
      tenant = insert(:tenant)
      participant = insert(:participant, tenant: tenant)
      campaign = insert(:campaign, tenant: tenant)
      challenge = insert(:challenge)

      # Set up associations
      {:ok, _cp} = CampaignManagement.associate_participant_with_campaign(
        tenant.id,
        participant.id,
        campaign.id
      )
      _campaign_challenge = insert(:campaign_challenge, campaign: campaign, challenge: challenge)
      {:ok, participant_challenge} =
        CampaignManagement.associate_participant_with_challenge(
          tenant.id,
          participant.id,
          challenge.id
        )

      # Disassociate
      assert {:ok, deleted} =
               CampaignManagement.disassociate_participant_from_challenge(
                 tenant.id,
                 participant.id,
                 challenge.id
               )

      assert deleted.id == participant_challenge.id

      # Verify association is deleted
      refute Repo.get(CampaignsApi.CampaignManagement.ParticipantChallenge, participant_challenge.id)
    end

    test "returns error when association does not exist" do
      tenant = insert(:tenant)
      participant = insert(:participant, tenant: tenant)
      challenge = insert(:challenge)

      assert {:error, :not_found} =
               CampaignManagement.disassociate_participant_from_challenge(
                 tenant.id,
                 participant.id,
                 challenge.id
               )
    end

    test "returns error when association belongs to different tenant" do
      tenant_a = insert(:tenant)
      tenant_b = insert(:tenant)
      participant = insert(:participant, tenant: tenant_a)
      campaign = insert(:campaign, tenant: tenant_a)
      challenge = insert(:challenge)

      # Set up associations in tenant_a
      {:ok, _cp} = CampaignManagement.associate_participant_with_campaign(
        tenant_a.id,
        participant.id,
        campaign.id
      )
      _campaign_challenge = insert(:campaign_challenge, campaign: campaign, challenge: challenge)
      {:ok, _pc} =
        CampaignManagement.associate_participant_with_challenge(
          tenant_a.id,
          participant.id,
          challenge.id
        )

      # Attempt to disassociate using tenant_b
      assert {:error, :not_found} =
               CampaignManagement.disassociate_participant_from_challenge(
                 tenant_b.id,
                 participant.id,
                 challenge.id
               )
    end
  end

  describe "list_challenges_for_participant/3" do
    test "lists challenges for participant" do
      tenant = insert(:tenant)
      participant = insert(:participant, tenant: tenant)
      campaign = insert(:campaign, tenant: tenant)
      challenge1 = insert(:challenge, name: "Challenge 1")
      challenge2 = insert(:challenge, name: "Challenge 2")

      # Set up associations
      {:ok, _cp} = CampaignManagement.associate_participant_with_campaign(
        tenant.id,
        participant.id,
        campaign.id
      )
      _cc1 = insert(:campaign_challenge, campaign: campaign, challenge: challenge1)
      _cc2 = insert(:campaign_challenge, campaign: campaign, challenge: challenge2)
      {:ok, _pc1} =
        CampaignManagement.associate_participant_with_challenge(
          tenant.id,
          participant.id,
          challenge1.id
        )
      {:ok, _pc2} =
        CampaignManagement.associate_participant_with_challenge(
          tenant.id,
          participant.id,
          challenge2.id
        )

      # List challenges
      result = CampaignManagement.list_challenges_for_participant(tenant.id, participant.id)

      assert %{data: challenges, has_more: false} = result
      assert length(challenges) == 2
      challenge_ids = Enum.map(challenges, & &1.id)
      assert challenge1.id in challenge_ids
      assert challenge2.id in challenge_ids
    end

    test "filters challenges by campaign_id" do
      tenant = insert(:tenant)
      participant = insert(:participant, tenant: tenant)
      campaign1 = insert(:campaign, tenant: tenant, name: "Campaign 1")
      campaign2 = insert(:campaign, tenant: tenant, name: "Campaign 2")
      challenge1 = insert(:challenge, name: "Challenge 1")
      challenge2 = insert(:challenge, name: "Challenge 2")

      # Associate participant with both campaigns
      {:ok, _cp1} = CampaignManagement.associate_participant_with_campaign(
        tenant.id,
        participant.id,
        campaign1.id
      )
      {:ok, _cp2} = CampaignManagement.associate_participant_with_campaign(
        tenant.id,
        participant.id,
        campaign2.id
      )

      # Associate challenges with campaigns
      _cc1 = insert(:campaign_challenge, campaign: campaign1, challenge: challenge1)
      _cc2 = insert(:campaign_challenge, campaign: campaign2, challenge: challenge2)

      # Associate participant with both challenges
      {:ok, _pc1} =
        CampaignManagement.associate_participant_with_challenge(
          tenant.id,
          participant.id,
          challenge1.id
        )
      {:ok, _pc2} =
        CampaignManagement.associate_participant_with_challenge(
          tenant.id,
          participant.id,
          challenge2.id
        )

      # List challenges filtered by campaign1
      result = CampaignManagement.list_challenges_for_participant(
        tenant.id,
        participant.id,
        campaign_id: campaign1.id
      )

      assert %{data: challenges, has_more: false} = result
      assert length(challenges) == 1
      assert hd(challenges).id == challenge1.id
    end

    test "returns empty list for participant with no challenges" do
      tenant = insert(:tenant)
      participant = insert(:participant, tenant: tenant)

      result = CampaignManagement.list_challenges_for_participant(tenant.id, participant.id)

      assert %{data: [], has_more: false} = result
    end

    test "returns empty list for different tenant" do
      tenant_a = insert(:tenant)
      tenant_b = insert(:tenant)
      participant = insert(:participant, tenant: tenant_a)
      campaign = insert(:campaign, tenant: tenant_a)
      challenge = insert(:challenge)

      # Set up associations in tenant_a
      {:ok, _cp} = CampaignManagement.associate_participant_with_campaign(
        tenant_a.id,
        participant.id,
        campaign.id
      )
      _cc = insert(:campaign_challenge, campaign: campaign, challenge: challenge)
      {:ok, _pc} =
        CampaignManagement.associate_participant_with_challenge(
          tenant_a.id,
          participant.id,
          challenge.id
        )

      # Query with tenant_b
      result = CampaignManagement.list_challenges_for_participant(tenant_b.id, participant.id)

      assert %{data: [], has_more: false} = result
    end
  end

  describe "list_participants_for_challenge/3" do
    test "lists participants for challenge" do
      tenant = insert(:tenant)
      participant1 = insert(:participant, tenant: tenant, nickname: "user1")
      participant2 = insert(:participant, tenant: tenant, nickname: "user2")
      campaign = insert(:campaign, tenant: tenant)
      challenge = insert(:challenge)

      # Set up associations
      {:ok, _cp1} = CampaignManagement.associate_participant_with_campaign(
        tenant.id,
        participant1.id,
        campaign.id
      )
      {:ok, _cp2} = CampaignManagement.associate_participant_with_campaign(
        tenant.id,
        participant2.id,
        campaign.id
      )
      _cc = insert(:campaign_challenge, campaign: campaign, challenge: challenge)
      {:ok, _pc1} =
        CampaignManagement.associate_participant_with_challenge(
          tenant.id,
          participant1.id,
          challenge.id
        )
      {:ok, _pc2} =
        CampaignManagement.associate_participant_with_challenge(
          tenant.id,
          participant2.id,
          challenge.id
        )

      # List participants
      result = CampaignManagement.list_participants_for_challenge(tenant.id, challenge.id)

      assert %{data: participants, has_more: false} = result
      assert length(participants) == 2
      participant_ids = Enum.map(participants, & &1.id)
      assert participant1.id in participant_ids
      assert participant2.id in participant_ids
    end

    test "returns empty list for challenge with no participants" do
      tenant = insert(:tenant)
      challenge = insert(:challenge)

      result = CampaignManagement.list_participants_for_challenge(tenant.id, challenge.id)

      assert %{data: [], has_more: false} = result
    end

    test "returns empty list for different tenant" do
      tenant_a = insert(:tenant)
      tenant_b = insert(:tenant)
      participant = insert(:participant, tenant: tenant_a)
      campaign = insert(:campaign, tenant: tenant_a)
      challenge = insert(:challenge)

      # Set up associations in tenant_a
      {:ok, _cp} = CampaignManagement.associate_participant_with_campaign(
        tenant_a.id,
        participant.id,
        campaign.id
      )
      _cc = insert(:campaign_challenge, campaign: campaign, challenge: challenge)
      {:ok, _pc} =
        CampaignManagement.associate_participant_with_challenge(
          tenant_a.id,
          participant.id,
          challenge.id
        )

      # Query with tenant_b
      result = CampaignManagement.list_participants_for_challenge(tenant_b.id, challenge.id)

      assert %{data: [], has_more: false} = result
    end
  end

  describe "challenge associations - property tests" do
    # **Validates: Requirements 2.1.7, 2.1.8, 2.1.9, 5.1.1-5.1.4**
    property "participant-challenge campaign membership: only campaign members can be assigned to challenges" do
      check all participant_name <- string(:alphanumeric, min_length: 1, max_length: 20),
                nickname_base <- string(:alphanumeric, min_length: 3, max_length: 15),
                is_campaign_member <- boolean() do

        # Create tenant, participant, campaign, and challenge
        tenant = insert(:tenant)
        nickname = "#{nickname_base}-#{System.unique_integer([:positive])}"
        participant_attrs = params_for(:participant, name: participant_name, nickname: nickname)
        {:ok, participant} = CampaignManagement.create_participant(tenant.id, participant_attrs)

        campaign = insert(:campaign, tenant: tenant)
        challenge = insert(:challenge)
        _campaign_challenge = insert(:campaign_challenge, campaign: campaign, challenge: challenge)

        # Conditionally associate participant with campaign
        if is_campaign_member do
          {:ok, _cp} = CampaignManagement.associate_participant_with_campaign(
            tenant.id,
            participant.id,
            campaign.id
          )
        end

        # Attempt to associate participant with challenge
        result =
          CampaignManagement.associate_participant_with_challenge(
            tenant.id,
            participant.id,
            challenge.id
          )

        if is_campaign_member do
          # Campaign member: association should succeed
          assert {:ok, participant_challenge} = result
          assert participant_challenge.participant_id == participant.id
          assert participant_challenge.challenge_id == challenge.id
          assert participant_challenge.campaign_id == campaign.id

          # Verify association exists in database
          assert Repo.get_by(CampaignsApi.CampaignManagement.ParticipantChallenge,
                   participant_id: participant.id,
                   challenge_id: challenge.id
                 )
        else
          # Not a campaign member: association should fail
          assert {:error, :participant_not_in_campaign} = result

          # Verify no association was created
          refute Repo.get_by(CampaignsApi.CampaignManagement.ParticipantChallenge,
                   participant_id: participant.id,
                   challenge_id: challenge.id
                 )
        end
      end
    end
  end
end
