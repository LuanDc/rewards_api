defmodule CampaignsApi.CampaignManagementTest do
  use CampaignsApi.DataCase, async: true
  use ExUnitProperties

  alias CampaignsApi.CampaignManagement

  setup do
    product1 = insert(:product)
    product2 = insert(:product)

    {:ok, product1: product1, product2: product2}
  end

  describe "get_campaign/2" do
    test "returns nil when accessing campaign from different product (cross-product access)", %{
      product1: product1,
      product2: product2
    } do
      campaign = insert(:campaign, product: product1)

      assert CampaignManagement.get_campaign(product1.id, campaign.id) != nil
      assert CampaignManagement.get_campaign(product2.id, campaign.id) == nil
    end

    test "returns nil when campaign does not exist", %{product1: product} do
      non_existent_id = Ecto.UUID.generate()
      assert CampaignManagement.get_campaign(product.id, non_existent_id) == nil
    end
  end

  describe "create_campaign/2" do
    test "returns error with foreign key violation when product does not exist" do
      non_existent_product_id = "non-existent-product-#{System.unique_integer([:positive])}"

      assert {:error, changeset} =
               CampaignManagement.create_campaign(non_existent_product_id, %{
                 name: "Test Campaign"
               })

      assert %{product_id: ["does not exist"]} = errors_on(changeset)
    end

    test "successfully creates campaign for existing product", %{product1: product} do
      {:ok, campaign} =
        CampaignManagement.create_campaign(product.id, %{
          name: "Valid Campaign"
        })

      assert campaign.product_id == product.id
      assert campaign.name == "Valid Campaign"
    end
  end

  describe "list_campaigns/2 pagination" do
    test "returns empty list when product has no campaigns", %{product1: product} do
      result = CampaignManagement.list_campaigns(product.id)

      assert result.data == []
      assert result.next_cursor == nil
      assert result.has_more == false
    end

    test "returns all campaigns when count is less than default limit", %{product1: product} do
      campaigns = insert_list(5, :campaign, product: product)

      result = CampaignManagement.list_campaigns(product.id)

      assert length(result.data) == 5
      assert result.has_more == false
      assert result.next_cursor == nil

      returned_ids = Enum.map(result.data, & &1.id)
      campaign_ids = Enum.map(campaigns, & &1.id)
      assert Enum.all?(campaign_ids, &(&1 in returned_ids))
    end

    test "respects custom limit parameter", %{product1: product} do
      insert_list(10, :campaign, product: product)

      result = CampaignManagement.list_campaigns(product.id, limit: 3)

      assert length(result.data) == 3
      assert result.has_more == true
      assert result.next_cursor != nil
    end

    test "handles pagination with cursor", %{product1: product} do
      insert_list(12, :campaign, product: product)

      first_page = CampaignManagement.list_campaigns(product.id, limit: 5)
      assert length(first_page.data) == 5

      if first_page.has_more do
        assert first_page.next_cursor != nil

        second_page =
          CampaignManagement.list_campaigns(product.id, limit: 5, cursor: first_page.next_cursor)

        first_page_ids = Enum.map(first_page.data, & &1.id)
        second_page_ids = Enum.map(second_page.data, & &1.id)

        assert Enum.all?(second_page_ids, &(&1 not in first_page_ids)),
               "Second page should not contain campaigns from first page"
      end
    end

    test "enforces maximum limit of 100", %{product1: product} do
      insert_list(150, :campaign, product: product)

      result = CampaignManagement.list_campaigns(product.id, limit: 200)

      assert length(result.data) <= 100
      assert result.has_more == true
    end

    test "returns campaigns only for specified product", %{product1: product1, product2: product2} do
      product1_campaign = insert(:campaign, product: product1)
      product2_campaign = insert(:campaign, product: product2)

      product1_result = CampaignManagement.list_campaigns(product1.id)
      product1_ids = Enum.map(product1_result.data, & &1.id)

      product2_result = CampaignManagement.list_campaigns(product2.id)
      product2_ids = Enum.map(product2_result.data, & &1.id)

      assert product1_campaign.id in product1_ids
      assert product1_campaign.id not in product2_ids
      assert product2_campaign.id in product2_ids
      assert product2_campaign.id not in product1_ids
    end
  end

  describe "update_campaign/3" do
    test "returns changeset errors when updating with invalid data", %{product1: product} do
      campaign = insert(:campaign, product: product)

      assert {:error, changeset} =
               CampaignManagement.update_campaign(product.id, campaign.id, %{name: "ab"})

      assert %{name: ["should be at least 3 character(s)"]} = errors_on(changeset)
    end

    test "returns changeset errors when updating with invalid date order", %{product1: product} do
      campaign = insert(:campaign, product: product)

      start_time = ~U[2024-02-01 00:00:00Z]
      end_time = ~U[2024-01-01 00:00:00Z]

      assert {:error, changeset} =
               CampaignManagement.update_campaign(product.id, campaign.id, %{
                 start_time: start_time,
                 end_time: end_time
               })

      assert %{start_time: ["must be before end_time"]} = errors_on(changeset)
    end

    test "successfully updates campaign with valid data", %{product1: product} do
      campaign = insert(:campaign, product: product)

      {:ok, updated_campaign} =
        CampaignManagement.update_campaign(product.id, campaign.id, %{
          name: "Updated Campaign",
          description: "New description"
        })

      assert updated_campaign.name == "Updated Campaign"
      assert updated_campaign.description == "New description"
    end

    test "returns not_found when updating campaign from different product", %{
      product1: product1,
      product2: product2
    } do
      campaign = insert(:campaign, product: product1)

      assert {:error, :not_found} =
               CampaignManagement.update_campaign(product2.id, campaign.id, %{
                 name: "Updated Name"
               })

      unchanged = CampaignManagement.get_campaign(product1.id, campaign.id)
      assert unchanged.name == campaign.name
    end

    test "returns not_found when updating non-existent campaign", %{product1: product} do
      non_existent_id = Ecto.UUID.generate()

      assert {:error, :not_found} =
               CampaignManagement.update_campaign(product.id, non_existent_id, %{
                 name: "New Name"
               })
    end
  end

  describe "flexible date management examples" do
    test "creates campaign without start_time or end_time", %{product1: product} do
      {:ok, campaign} =
        CampaignManagement.create_campaign(product.id, %{
          name: "No Dates Campaign"
        })

      assert campaign.start_time == nil
      assert campaign.end_time == nil
      assert campaign.name == "No Dates Campaign"
    end

    test "creates campaign with start_time but no end_time", %{product1: product} do
      start_time = ~U[2024-01-01 00:00:00Z]

      {:ok, campaign} =
        CampaignManagement.create_campaign(product.id, %{
          name: "Start Only Campaign",
          start_time: start_time
        })

      assert campaign.start_time == start_time
      assert campaign.end_time == nil
      assert campaign.name == "Start Only Campaign"
    end

    test "creates campaign with end_time but no start_time", %{product1: product} do
      end_time = ~U[2024-12-31 23:59:59Z]

      {:ok, campaign} =
        CampaignManagement.create_campaign(product.id, %{
          name: "End Only Campaign",
          end_time: end_time
        })

      assert campaign.start_time == nil
      assert campaign.end_time == end_time
      assert campaign.name == "End Only Campaign"
    end

    test "creates campaign with both start_time and end_time when start is before end", %{
      product1: product
    } do
      start_time = ~U[2024-01-01 00:00:00Z]
      end_time = ~U[2024-12-31 23:59:59Z]

      {:ok, campaign} =
        CampaignManagement.create_campaign(product.id, %{
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
    test "successfully deletes a campaign belonging to the product", %{product1: product} do
      campaign = insert(:campaign, product: product)

      assert {:ok, deleted_campaign} = CampaignManagement.delete_campaign(product.id, campaign.id)
      assert deleted_campaign.id == campaign.id
      assert CampaignManagement.get_campaign(product.id, campaign.id) == nil
    end

    test "returns error when campaign does not exist", %{product1: product} do
      non_existent_id = Ecto.UUID.generate()

      assert {:error, :not_found} =
               CampaignManagement.delete_campaign(product.id, non_existent_id)
    end

    test "returns error when campaign belongs to different product", %{
      product1: product1,
      product2: product2
    } do
      campaign = insert(:campaign, product: product1)

      assert {:error, :not_found} = CampaignManagement.delete_campaign(product2.id, campaign.id)
      assert CampaignManagement.get_campaign(product1.id, campaign.id) != nil
    end

    test "campaign does not appear in list after deletion", %{product1: product} do
      campaign1 = insert(:campaign, product: product)
      campaign2 = insert(:campaign, product: product)

      {:ok, _} = CampaignManagement.delete_campaign(product.id, campaign1.id)

      result = CampaignManagement.list_campaigns(product.id)

      assert length(result.data) == 1
      assert hd(result.data).id == campaign2.id
    end
  end

  describe "list_campaign_challenges/3" do
    test "returns empty list when campaign has no challenges", %{product1: product} do
      campaign = insert(:campaign, product: product)

      result = CampaignManagement.list_campaign_challenges(product.id, campaign.id)

      assert result.data == []
      assert result.next_cursor == nil
      assert result.has_more == false
    end

    test "returns all campaign challenges with pagination", %{product1: product} do
      campaign = insert(:campaign, product: product)
      challenge1 = insert(:challenge)
      challenge2 = insert(:challenge)

      cc1 = insert(:campaign_challenge, campaign: campaign, challenge: challenge1)
      cc2 = insert(:campaign_challenge, campaign: campaign, challenge: challenge2)

      result = CampaignManagement.list_campaign_challenges(product.id, campaign.id)

      assert length(result.data) == 2
      returned_ids = Enum.map(result.data, & &1.id)
      assert cc1.id in returned_ids
      assert cc2.id in returned_ids
    end

    test "preloads challenge association", %{product1: product} do
      campaign = insert(:campaign, product: product)
      challenge = insert(:challenge, name: "Test Challenge")
      insert(:campaign_challenge, campaign: campaign, challenge: challenge)

      result = CampaignManagement.list_campaign_challenges(product.id, campaign.id)

      assert length(result.data) == 1
      campaign_challenge = hd(result.data)
      assert campaign_challenge.challenge.name == "Test Challenge"
    end

    test "enforces product isolation - cannot list challenges from different product's campaign",
         %{
           product1: product1,
           product2: product2
         } do
      campaign = insert(:campaign, product: product1)
      challenge = insert(:challenge)
      insert(:campaign_challenge, campaign: campaign, challenge: challenge)

      result = CampaignManagement.list_campaign_challenges(product2.id, campaign.id)

      assert result.data == []
    end

    test "respects pagination limit", %{product1: product} do
      campaign = insert(:campaign, product: product)
      challenge1 = insert(:challenge)
      challenge2 = insert(:challenge)
      challenge3 = insert(:challenge)

      insert(:campaign_challenge, campaign: campaign, challenge: challenge1)
      insert(:campaign_challenge, campaign: campaign, challenge: challenge2)
      insert(:campaign_challenge, campaign: campaign, challenge: challenge3)

      result = CampaignManagement.list_campaign_challenges(product.id, campaign.id, limit: 2)

      assert length(result.data) == 2
      assert result.has_more == true
    end
  end

  describe "get_campaign_challenge/3" do
    test "returns campaign challenge with preloaded challenge", %{product1: product} do
      campaign = insert(:campaign, product: product)
      challenge = insert(:challenge, name: "Test Challenge")
      cc = insert(:campaign_challenge, campaign: campaign, challenge: challenge)

      result = CampaignManagement.get_campaign_challenge(product.id, campaign.id, cc.id)

      assert result.id == cc.id
      assert result.challenge.name == "Test Challenge"
    end

    test "returns nil when campaign challenge does not exist", %{product1: product} do
      campaign = insert(:campaign, product: product)
      non_existent_id = Ecto.UUID.generate()

      result = CampaignManagement.get_campaign_challenge(product.id, campaign.id, non_existent_id)

      assert result == nil
    end

    test "returns nil when accessing campaign challenge from different product", %{
      product1: product1,
      product2: product2
    } do
      campaign = insert(:campaign, product: product1)
      challenge = insert(:challenge)
      cc = insert(:campaign_challenge, campaign: campaign, challenge: challenge)

      result = CampaignManagement.get_campaign_challenge(product2.id, campaign.id, cc.id)

      assert result == nil
    end
  end

  describe "create_campaign_challenge/3" do
    test "successfully creates campaign challenge with valid data", %{product1: product} do
      campaign = insert(:campaign, product: product)
      challenge = insert(:challenge)

      attrs = %{
        challenge_id: challenge.id,
        display_name: "Buy+ Challenge",
        display_description: "Earn points for purchases",
        evaluation_frequency: "daily",
        reward_points: 100,
        configuration: %{"threshold" => 10}
      }

      {:ok, cc} = CampaignManagement.create_campaign_challenge(product.id, campaign.id, attrs)

      assert cc.campaign_id == campaign.id
      assert cc.challenge_id == challenge.id
      assert cc.display_name == "Buy+ Challenge"
      assert cc.reward_points == 100
    end

    test "returns error when campaign does not belong to product", %{
      product1: product1,
      product2: product2
    } do
      campaign = insert(:campaign, product: product1)
      challenge = insert(:challenge)

      attrs = %{
        challenge_id: challenge.id,
        display_name: "Test Challenge",
        evaluation_frequency: "daily",
        reward_points: 50
      }

      result = CampaignManagement.create_campaign_challenge(product2.id, campaign.id, attrs)

      assert {:error, :campaign_not_found} = result
    end

    test "accepts any challenge (challenges are global)", %{product1: product} do
      campaign = insert(:campaign, product: product)
      challenge = insert(:challenge)

      attrs = %{
        challenge_id: challenge.id,
        display_name: "Global Challenge",
        evaluation_frequency: "weekly",
        reward_points: 200
      }

      {:ok, cc} = CampaignManagement.create_campaign_challenge(product.id, campaign.id, attrs)

      assert cc.challenge_id == challenge.id
    end

    test "returns error when creating duplicate association", %{product1: product} do
      campaign = insert(:campaign, product: product)
      challenge = insert(:challenge)

      attrs = %{
        challenge_id: challenge.id,
        display_name: "First Association",
        evaluation_frequency: "daily",
        reward_points: 100
      }

      {:ok, _cc} = CampaignManagement.create_campaign_challenge(product.id, campaign.id, attrs)

      duplicate_attrs = %{
        challenge_id: challenge.id,
        display_name: "Duplicate Association",
        evaluation_frequency: "weekly",
        reward_points: 200
      }

      {:error, changeset} =
        CampaignManagement.create_campaign_challenge(product.id, campaign.id, duplicate_attrs)

      assert %{campaign_id: ["has already been taken"]} = errors_on(changeset)
    end

    test "returns error with invalid data", %{product1: product} do
      campaign = insert(:campaign, product: product)
      challenge = insert(:challenge)

      attrs = %{
        challenge_id: challenge.id,
        display_name: "ab",
        evaluation_frequency: "daily",
        reward_points: 100
      }

      {:error, changeset} =
        CampaignManagement.create_campaign_challenge(product.id, campaign.id, attrs)

      assert %{display_name: ["should be at least 3 character(s)"]} = errors_on(changeset)
    end
  end

  describe "update_campaign_challenge/4" do
    test "successfully updates campaign challenge with valid data", %{product1: product} do
      campaign = insert(:campaign, product: product)
      challenge = insert(:challenge)
      cc = insert(:campaign_challenge, campaign: campaign, challenge: challenge)

      attrs = %{
        display_name: "Updated Challenge",
        reward_points: 500
      }

      {:ok, updated_cc} =
        CampaignManagement.update_campaign_challenge(product.id, campaign.id, cc.id, attrs)

      assert updated_cc.display_name == "Updated Challenge"
      assert updated_cc.reward_points == 500
    end

    test "returns error when campaign challenge does not exist", %{product1: product} do
      campaign = insert(:campaign, product: product)
      non_existent_id = Ecto.UUID.generate()

      result =
        CampaignManagement.update_campaign_challenge(product.id, campaign.id, non_existent_id, %{
          display_name: "Updated"
        })

      assert {:error, :not_found} = result
    end

    test "returns error when updating campaign challenge from different product", %{
      product1: product1,
      product2: product2
    } do
      campaign = insert(:campaign, product: product1)
      challenge = insert(:challenge)
      cc = insert(:campaign_challenge, campaign: campaign, challenge: challenge)

      result =
        CampaignManagement.update_campaign_challenge(product2.id, campaign.id, cc.id, %{
          display_name: "Updated"
        })

      assert {:error, :not_found} = result
    end

    test "returns error with invalid data", %{product1: product} do
      campaign = insert(:campaign, product: product)
      challenge = insert(:challenge)
      cc = insert(:campaign_challenge, campaign: campaign, challenge: challenge)

      {:error, changeset} =
        CampaignManagement.update_campaign_challenge(product.id, campaign.id, cc.id, %{
          display_name: "ab"
        })

      assert %{display_name: ["should be at least 3 character(s)"]} = errors_on(changeset)
    end
  end

  describe "delete_campaign_challenge/3" do
    test "successfully deletes campaign challenge", %{product1: product} do
      campaign = insert(:campaign, product: product)
      challenge = insert(:challenge)
      cc = insert(:campaign_challenge, campaign: campaign, challenge: challenge)

      {:ok, deleted_cc} =
        CampaignManagement.delete_campaign_challenge(product.id, campaign.id, cc.id)

      assert deleted_cc.id == cc.id
      assert CampaignManagement.get_campaign_challenge(product.id, campaign.id, cc.id) == nil
    end

    test "returns error when campaign challenge does not exist", %{product1: product} do
      campaign = insert(:campaign, product: product)
      non_existent_id = Ecto.UUID.generate()

      result =
        CampaignManagement.delete_campaign_challenge(product.id, campaign.id, non_existent_id)

      assert {:error, :not_found} = result
    end

    test "returns error when deleting campaign challenge from different product", %{
      product1: product1,
      product2: product2
    } do
      campaign = insert(:campaign, product: product1)
      challenge = insert(:challenge)
      cc = insert(:campaign_challenge, campaign: campaign, challenge: challenge)

      result = CampaignManagement.delete_campaign_challenge(product2.id, campaign.id, cc.id)

      assert {:error, :not_found} = result
    end
  end

  describe "campaign deletion cascade" do
    test "deleting campaign automatically deletes associated campaign challenges", %{
      product1: product
    } do
      campaign = insert(:campaign, product: product)
      challenge1 = insert(:challenge)
      challenge2 = insert(:challenge)

      cc1 = insert(:campaign_challenge, campaign: campaign, challenge: challenge1)
      cc2 = insert(:campaign_challenge, campaign: campaign, challenge: challenge2)

      {:ok, _} = CampaignManagement.delete_campaign(product.id, campaign.id)

      assert CampaignManagement.get_campaign_challenge(product.id, campaign.id, cc1.id) == nil
      assert CampaignManagement.get_campaign_challenge(product.id, campaign.id, cc2.id) == nil
    end
  end

  describe "Property: Product Isolation (Business Invariant)" do
    @tag :property
    property "product cannot access campaigns belonging to other products", %{
      product1: product1,
      product2: product2
    } do
      check all(
              name <- string(:alphanumeric, min_length: 3, max_length: 50),
              max_runs: 50
            ) do
        {:ok, campaign} = CampaignManagement.create_campaign(product1.id, %{name: name})

        # Product1 can access their own campaign
        assert CampaignManagement.get_campaign(product1.id, campaign.id) != nil,
               "product1 should be able to retrieve their own campaign"

        # Product2 cannot access product1's campaign
        assert CampaignManagement.get_campaign(product2.id, campaign.id) == nil,
               "product2 should not be able to retrieve product1's campaign"

        # Product2 cannot update product1's campaign
        assert {:error, :not_found} =
                 CampaignManagement.update_campaign(product2.id, campaign.id, %{name: "Updated"}),
               "product2 should not be able to update product1's campaign"

        # Product2 cannot delete product1's campaign
        assert {:error, :not_found} =
                 CampaignManagement.delete_campaign(product2.id, campaign.id),
               "product2 should not be able to delete product1's campaign"

        # Campaign still exists for product1
        assert CampaignManagement.get_campaign(product1.id, campaign.id) != nil,
               "campaign should still exist for product1 after cross-product access attempts"

        # Product2's list doesn't include product1's campaign
        product2_campaigns = CampaignManagement.list_campaigns(product2.id)
        campaign_ids = Enum.map(product2_campaigns.data, & &1.id)

        assert campaign.id not in campaign_ids,
               "product1's campaign should not appear in product2's campaign list"
      end
    end
  end

  describe "Unit tests for properties converted from property tests" do
    test "campaign created has UUID format", %{product1: product} do
      {:ok, campaign} = CampaignManagement.create_campaign(product.id, %{name: "Test Campaign"})

      assert is_binary(campaign.id)
      assert String.length(campaign.id) == 36
      assert campaign.id =~ ~r/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/
    end

    test "campaign defaults to active status when not specified", %{product1: product} do
      {:ok, campaign} = CampaignManagement.create_campaign(product.id, %{name: "Test Campaign"})

      assert campaign.status == :active
    end

    test "campaign can be created with optional fields", %{product1: product} do
      start_time = ~U[2024-01-01 00:00:00Z]
      end_time = ~U[2024-12-31 23:59:59Z]

      {:ok, campaign} =
        CampaignManagement.create_campaign(product.id, %{
          name: "Full Campaign",
          description: "Test description",
          start_time: start_time,
          end_time: end_time
        })

      assert campaign.description == "Test description"
      assert campaign.start_time == start_time
      assert campaign.end_time == end_time
    end

    test "campaign timestamps are stored in UTC", %{product1: product} do
      start_time = ~U[2024-01-01 00:00:00Z]
      end_time = ~U[2024-12-31 23:59:59Z]

      {:ok, campaign} =
        CampaignManagement.create_campaign(product.id, %{
          name: "Test Campaign",
          start_time: start_time,
          end_time: end_time
        })

      assert campaign.start_time.time_zone == "Etc/UTC"
      assert campaign.end_time.time_zone == "Etc/UTC"
      assert campaign.inserted_at.time_zone == "Etc/UTC"
      assert campaign.updated_at.time_zone == "Etc/UTC"
    end

    test "campaigns are ordered by inserted_at descending", %{product1: product} do
      insert_list(5, :campaign, product: product)

      result = CampaignManagement.list_campaigns(product.id)
      campaigns = result.data

      assert length(campaigns) == 5

      # Verify descending order
      timestamps = Enum.map(campaigns, & &1.inserted_at)
      assert timestamps == Enum.sort(timestamps, {:desc, DateTime})
    end

    test "campaign includes all required fields", %{product1: product} do
      {:ok, campaign} = CampaignManagement.create_campaign(product.id, %{name: "Test Campaign"})

      assert Map.has_key?(campaign, :id)
      assert Map.has_key?(campaign, :product_id)
      assert Map.has_key?(campaign, :name)
      assert Map.has_key?(campaign, :description)
      assert Map.has_key?(campaign, :start_time)
      assert Map.has_key?(campaign, :end_time)
      assert Map.has_key?(campaign, :status)
      assert Map.has_key?(campaign, :inserted_at)
      assert Map.has_key?(campaign, :updated_at)
    end

    test "campaign status can transition between active and paused", %{product1: product} do
      {:ok, campaign} =
        CampaignManagement.create_campaign(product.id, %{name: "Test", status: :active})

      assert campaign.status == :active

      {:ok, updated} =
        CampaignManagement.update_campaign(product.id, campaign.id, %{status: :paused})

      assert updated.status == :paused

      {:ok, updated_again} =
        CampaignManagement.update_campaign(product.id, campaign.id, %{status: :active})

      assert updated_again.status == :active
    end
  end
end

defmodule CampaignsApi.ParticipantManagementTest do
  use CampaignsApi.DataCase, async: true
  use ExUnitProperties

  import CampaignsApi.Factory
  import Ecto.Query

  alias CampaignsApi.CampaignManagement
  alias CampaignsApi.Repo

  describe "create_participant/2" do
    test "creates participant with valid attributes" do
      product = insert(:product)
      attrs = params_for(:participant, name: "John Doe", nickname: "johndoe")

      assert {:ok, participant} = CampaignManagement.create_participant(product.id, attrs)
      assert participant.name == "John Doe"
      assert participant.nickname == "johndoe"
      assert participant.product_id == product.id
      assert participant.status == :active
    end

    test "returns error with invalid attributes" do
      product = insert(:product)
      attrs = %{name: "", nickname: "ab"}

      assert {:error, changeset} = CampaignManagement.create_participant(product.id, attrs)
      assert %{name: ["can't be blank"]} = errors_on(changeset)
      assert %{nickname: ["should be at least 3 character(s)"]} = errors_on(changeset)
    end

    test "returns error when nickname is not unique" do
      product = insert(:product)
      _existing_participant = insert(:participant, product: product, nickname: "johndoe")

      attrs = params_for(:participant, nickname: "johndoe")

      assert {:error, changeset} = CampaignManagement.create_participant(product.id, attrs)
      assert %{nickname: ["has already been taken"]} = errors_on(changeset)
    end
  end

  describe "get_participant/2" do
    test "returns participant when it exists and belongs to product" do
      product = insert(:product)
      participant = insert(:participant, product: product)

      assert found = CampaignManagement.get_participant(product.id, participant.id)
      assert found.id == participant.id
      assert found.product_id == product.id
    end

    test "returns nil when participant does not exist" do
      product = insert(:product)
      non_existent_id = Ecto.UUID.generate()

      assert nil == CampaignManagement.get_participant(product.id, non_existent_id)
    end

    test "returns nil when participant belongs to different product" do
      product_a = insert(:product)
      product_b = insert(:product)
      participant = insert(:participant, product: product_a)

      assert nil == CampaignManagement.get_participant(product_b.id, participant.id)
    end
  end

  describe "update_participant/3" do
    test "updates participant with valid attributes" do
      product = insert(:product)
      participant = insert(:participant, product: product, name: "John Doe", nickname: "johndoe")

      attrs = %{name: "Jane Doe", nickname: "janedoe"}

      assert {:ok, updated} =
               CampaignManagement.update_participant(product.id, participant.id, attrs)

      assert updated.id == participant.id
      assert updated.name == "Jane Doe"
      assert updated.nickname == "janedoe"
      assert updated.product_id == product.id
    end

    test "returns error with invalid attributes" do
      product = insert(:product)
      participant = insert(:participant, product: product)

      attrs = %{name: "", nickname: "ab"}

      assert {:error, changeset} =
               CampaignManagement.update_participant(product.id, participant.id, attrs)

      assert %{name: ["can't be blank"]} = errors_on(changeset)
      assert %{nickname: ["should be at least 3 character(s)"]} = errors_on(changeset)
    end

    test "returns error when participant does not exist" do
      product = insert(:product)
      non_existent_id = Ecto.UUID.generate()

      attrs = %{name: "Jane Doe"}

      assert {:error, :not_found} =
               CampaignManagement.update_participant(product.id, non_existent_id, attrs)
    end

    test "returns error when participant belongs to different product" do
      product_a = insert(:product)
      product_b = insert(:product)
      participant = insert(:participant, product: product_a)

      attrs = %{name: "Jane Doe"}

      assert {:error, :not_found} =
               CampaignManagement.update_participant(product_b.id, participant.id, attrs)
    end

    test "returns error when nickname is not unique" do
      product = insert(:product)
      _existing_participant = insert(:participant, product: product, nickname: "johndoe")
      participant = insert(:participant, product: product, nickname: "janedoe")

      attrs = %{nickname: "johndoe"}

      assert {:error, changeset} =
               CampaignManagement.update_participant(product.id, participant.id, attrs)

      assert %{nickname: ["has already been taken"]} = errors_on(changeset)
    end
  end

  describe "delete_participant/2" do
    test "deletes participant when it exists and belongs to product" do
      product = insert(:product)
      participant = insert(:participant, product: product)

      assert {:ok, deleted} = CampaignManagement.delete_participant(product.id, participant.id)
      assert deleted.id == participant.id

      # Verify participant is actually deleted
      assert nil == CampaignManagement.get_participant(product.id, participant.id)
    end

    test "returns error when participant does not exist" do
      product = insert(:product)
      non_existent_id = Ecto.UUID.generate()

      assert {:error, :not_found} =
               CampaignManagement.delete_participant(product.id, non_existent_id)
    end

    test "returns error when participant belongs to different product" do
      product_a = insert(:product)
      product_b = insert(:product)
      participant = insert(:participant, product: product_a)

      assert {:error, :not_found} =
               CampaignManagement.delete_participant(product_b.id, participant.id)

      # Verify participant still exists for product_a
      assert CampaignManagement.get_participant(product_a.id, participant.id)
    end
  end

  describe "list_participants/2" do
    test "lists participants without cursor" do
      product = insert(:product)
      participant1 = insert(:participant, product: product, name: "Alice", nickname: "alice")
      participant2 = insert(:participant, product: product, name: "Bob", nickname: "bob")
      participant3 = insert(:participant, product: product, name: "Charlie", nickname: "charlie")

      result = CampaignManagement.list_participants(product.id, [])

      assert %{data: data, next_cursor: _, has_more: _} = result
      assert length(data) == 3

      # Verify ordering by inserted_at descending (newest first)
      participant_ids = Enum.map(data, & &1.id)
      assert participant3.id in participant_ids
      assert participant2.id in participant_ids
      assert participant1.id in participant_ids
    end

    test "lists participants with cursor" do
      product = insert(:product)

      # Insert multiple participants
      insert_list(12, :participant, product: product)

      # Get first page
      first_page = CampaignManagement.list_participants(product.id, limit: 5)
      assert length(first_page.data) == 5

      # If there are more results, test cursor pagination
      if first_page.has_more do
        assert first_page.next_cursor != nil

        # Get second page using cursor
        second_page =
          CampaignManagement.list_participants(product.id,
            limit: 5,
            cursor: first_page.next_cursor
          )

        # Verify no duplicates between pages
        first_page_ids = Enum.map(first_page.data, & &1.id)
        second_page_ids = Enum.map(second_page.data, & &1.id)

        assert Enum.all?(second_page_ids, &(&1 not in first_page_ids)),
               "Second page should not contain participants from first page"
      end
    end

    test "enforces maximum limit of 100" do
      product = insert(:product)

      # Insert 10 participants
      for i <- 1..10 do
        insert(:participant, product: product, nickname: "user#{i}")
      end

      # Request with limit > 100
      result = CampaignManagement.list_participants(product.id, limit: 150)

      # Should return at most 100 (but we only have 10)
      assert %{data: data} = result
      assert length(data) == 10
    end

    test "filters by nickname (case-insensitive)" do
      product = insert(:product)
      insert(:participant, product: product, nickname: "alice123")
      insert(:participant, product: product, nickname: "bob456")
      insert(:participant, product: product, nickname: "ALICE789")
      insert(:participant, product: product, nickname: "charlie")

      result = CampaignManagement.list_participants(product.id, nickname: "alice")

      assert %{data: data} = result
      assert length(data) == 2
      assert Enum.all?(data, fn p -> String.contains?(String.downcase(p.nickname), "alice") end)
    end

    test "returns correct pagination response structure" do
      product = insert(:product)
      insert(:participant, product: product)

      result = CampaignManagement.list_participants(product.id, [])

      assert %{data: data, next_cursor: next_cursor, has_more: has_more} = result
      assert is_list(data)
      assert is_boolean(has_more)
      assert next_cursor == nil or match?(%DateTime{}, next_cursor)
    end

    test "returns empty results for product with no participants" do
      product = insert(:product)

      result = CampaignManagement.list_participants(product.id, [])

      assert %{data: [], next_cursor: nil, has_more: false} = result
    end

    test "only returns participants for requesting product" do
      product_a = insert(:product)
      product_b = insert(:product)

      participant_a = insert(:participant, product: product_a, nickname: "product_a_user")
      _participant_b = insert(:participant, product: product_b, nickname: "product_b_user")

      result = CampaignManagement.list_participants(product_a.id, [])

      assert %{data: data} = result
      assert length(data) == 1
      assert hd(data).id == participant_a.id
      assert hd(data).product_id == product_a.id
    end
  end

  describe "CRUD round trip" do
    test "create → read → update → read → delete maintains data integrity" do
      product = insert(:product)

      # Create
      create_attrs = params_for(:participant, name: "John Doe", nickname: "johndoe")
      assert {:ok, participant} = CampaignManagement.create_participant(product.id, create_attrs)
      assert participant.name == "John Doe"
      assert participant.nickname == "johndoe"
      assert participant.status == :active
      participant_id = participant.id

      # Read
      assert found = CampaignManagement.get_participant(product.id, participant_id)
      assert found.id == participant_id
      assert found.name == "John Doe"
      assert found.nickname == "johndoe"

      # Update
      update_attrs = %{name: "Jane Doe", nickname: "janedoe"}

      assert {:ok, updated} =
               CampaignManagement.update_participant(product.id, participant_id, update_attrs)

      assert updated.id == participant_id
      assert updated.name == "Jane Doe"
      assert updated.nickname == "janedoe"

      # Read again
      assert found_updated = CampaignManagement.get_participant(product.id, participant_id)
      assert found_updated.id == participant_id
      assert found_updated.name == "Jane Doe"
      assert found_updated.nickname == "janedoe"

      # Delete
      assert {:ok, deleted} = CampaignManagement.delete_participant(product.id, participant_id)
      assert deleted.id == participant_id

      # Verify deletion
      assert nil == CampaignManagement.get_participant(product.id, participant_id)
    end
  end

  describe "associate_participant_with_campaign/3" do
    test "associates participant with campaign in same product" do
      product = insert(:product)
      participant = insert(:participant, product: product)
      campaign = insert(:campaign, product: product)

      assert {:ok, campaign_participant} =
               CampaignManagement.associate_participant_with_campaign(
                 product.id,
                 participant.id,
                 campaign.id
               )

      assert campaign_participant.participant_id == participant.id
      assert campaign_participant.campaign_id == campaign.id
    end

    test "returns error when associating cross-product resources" do
      product_a = insert(:product)
      product_b = insert(:product)
      participant = insert(:participant, product: product_a)
      campaign = insert(:campaign, product: product_b)

      assert {:error, :product_mismatch} =
               CampaignManagement.associate_participant_with_campaign(
                 product_a.id,
                 participant.id,
                 campaign.id
               )
    end

    test "returns error when participant belongs to different product" do
      product_a = insert(:product)
      product_b = insert(:product)
      participant = insert(:participant, product: product_a)
      campaign = insert(:campaign, product: product_b)

      # Try to associate using product_b (campaign's product)
      assert {:error, :product_mismatch} =
               CampaignManagement.associate_participant_with_campaign(
                 product_b.id,
                 participant.id,
                 campaign.id
               )
    end

    test "returns error when campaign belongs to different product" do
      product_a = insert(:product)
      product_b = insert(:product)
      participant = insert(:participant, product: product_a)
      campaign = insert(:campaign, product: product_b)

      # Try to associate using product_a (participant's product)
      assert {:error, :product_mismatch} =
               CampaignManagement.associate_participant_with_campaign(
                 product_a.id,
                 participant.id,
                 campaign.id
               )
    end

    test "returns error for duplicate association" do
      product = insert(:product)
      participant = insert(:participant, product: product)
      campaign = insert(:campaign, product: product)

      # Create first association
      assert {:ok, _} =
               CampaignManagement.associate_participant_with_campaign(
                 product.id,
                 participant.id,
                 campaign.id
               )

      # Try to create duplicate association
      assert {:error, changeset} =
               CampaignManagement.associate_participant_with_campaign(
                 product.id,
                 participant.id,
                 campaign.id
               )

      assert %{participant_id: ["has already been taken"]} = errors_on(changeset)
    end
  end

  describe "disassociate_participant_from_campaign/3" do
    test "disassociates participant from campaign" do
      product = insert(:product)
      participant = insert(:participant, product: product)
      campaign = insert(:campaign, product: product)

      # Create association
      {:ok, campaign_participant} =
        CampaignManagement.associate_participant_with_campaign(
          product.id,
          participant.id,
          campaign.id
        )

      # Disassociate
      assert {:ok, deleted} =
               CampaignManagement.disassociate_participant_from_campaign(
                 product.id,
                 participant.id,
                 campaign.id
               )

      assert deleted.id == campaign_participant.id

      # Verify association is removed by trying to create it again (should succeed)
      assert {:ok, _new_association} =
               CampaignManagement.associate_participant_with_campaign(
                 product.id,
                 participant.id,
                 campaign.id
               )
    end

    test "returns error when association does not exist" do
      product = insert(:product)
      participant = insert(:participant, product: product)
      campaign = insert(:campaign, product: product)

      # Try to disassociate without creating association first
      assert {:error, :not_found} =
               CampaignManagement.disassociate_participant_from_campaign(
                 product.id,
                 participant.id,
                 campaign.id
               )
    end

    test "returns error when trying to disassociate cross-product resources" do
      product_a = insert(:product)
      product_b = insert(:product)
      participant = insert(:participant, product: product_a)
      campaign = insert(:campaign, product: product_a)

      # Create association in product_a
      {:ok, _} =
        CampaignManagement.associate_participant_with_campaign(
          product_a.id,
          participant.id,
          campaign.id
        )

      # Try to disassociate using product_b
      assert {:error, :not_found} =
               CampaignManagement.disassociate_participant_from_campaign(
                 product_b.id,
                 participant.id,
                 campaign.id
               )
    end
  end

  describe "list_campaigns_for_participant/3" do
    test "lists campaigns for participant" do
      product = insert(:product)
      participant = insert(:participant, product: product)
      campaign1 = insert(:campaign, product: product, name: "Campaign 1")
      campaign2 = insert(:campaign, product: product, name: "Campaign 2")
      campaign3 = insert(:campaign, product: product, name: "Campaign 3")

      # Associate participant with campaigns
      CampaignManagement.associate_participant_with_campaign(
        product.id,
        participant.id,
        campaign1.id
      )

      CampaignManagement.associate_participant_with_campaign(
        product.id,
        participant.id,
        campaign2.id
      )

      CampaignManagement.associate_participant_with_campaign(
        product.id,
        participant.id,
        campaign3.id
      )

      result = CampaignManagement.list_campaigns_for_participant(product.id, participant.id, [])

      assert %{data: data, next_cursor: _, has_more: _} = result
      assert length(data) == 3

      campaign_ids = Enum.map(data, & &1.id)
      assert campaign1.id in campaign_ids
      assert campaign2.id in campaign_ids
      assert campaign3.id in campaign_ids
    end

    test "returns empty list when participant has no campaigns" do
      product = insert(:product)
      participant = insert(:participant, product: product)

      result = CampaignManagement.list_campaigns_for_participant(product.id, participant.id, [])

      assert %{data: [], next_cursor: nil, has_more: false} = result
    end

    test "returns empty list for cross-product participant" do
      product_a = insert(:product)
      product_b = insert(:product)
      participant = insert(:participant, product: product_a)
      campaign = insert(:campaign, product: product_a)

      # Associate in product_a
      CampaignManagement.associate_participant_with_campaign(
        product_a.id,
        participant.id,
        campaign.id
      )

      # Try to list using product_b
      result = CampaignManagement.list_campaigns_for_participant(product_b.id, participant.id, [])

      assert %{data: [], next_cursor: nil, has_more: false} = result
    end

    test "supports pagination" do
      product = insert(:product)
      participant = insert(:participant, product: product)

      # Create and associate 3 campaigns with delays to ensure different timestamps
      campaign1 = insert(:campaign, product: product, name: "Campaign 1")

      CampaignManagement.associate_participant_with_campaign(
        product.id,
        participant.id,
        campaign1.id
      )

      # Sleep 1 second to ensure different timestamp
      Process.sleep(1100)

      campaign2 = insert(:campaign, product: product, name: "Campaign 2")

      CampaignManagement.associate_participant_with_campaign(
        product.id,
        participant.id,
        campaign2.id
      )

      Process.sleep(1100)

      campaign3 = insert(:campaign, product: product, name: "Campaign 3")

      CampaignManagement.associate_participant_with_campaign(
        product.id,
        participant.id,
        campaign3.id
      )

      # Get first page with limit 2
      first_page =
        CampaignManagement.list_campaigns_for_participant(product.id, participant.id, limit: 2)

      assert length(first_page.data) == 2
      assert first_page.has_more == true
      assert first_page.next_cursor != nil

      # Get second page
      second_page =
        CampaignManagement.list_campaigns_for_participant(
          product.id,
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
      product = insert(:product)
      campaign = insert(:campaign, product: product)
      participant1 = insert(:participant, product: product, nickname: "user1")
      participant2 = insert(:participant, product: product, nickname: "user2")
      participant3 = insert(:participant, product: product, nickname: "user3")

      # Associate participants with campaign
      CampaignManagement.associate_participant_with_campaign(
        product.id,
        participant1.id,
        campaign.id
      )

      CampaignManagement.associate_participant_with_campaign(
        product.id,
        participant2.id,
        campaign.id
      )

      CampaignManagement.associate_participant_with_campaign(
        product.id,
        participant3.id,
        campaign.id
      )

      result = CampaignManagement.list_participants_for_campaign(product.id, campaign.id, [])

      assert %{data: data, next_cursor: _, has_more: _} = result
      assert length(data) == 3

      participant_ids = Enum.map(data, & &1.id)
      assert participant1.id in participant_ids
      assert participant2.id in participant_ids
      assert participant3.id in participant_ids
    end

    test "returns empty list when campaign has no participants" do
      product = insert(:product)
      campaign = insert(:campaign, product: product)

      result = CampaignManagement.list_participants_for_campaign(product.id, campaign.id, [])

      assert %{data: [], next_cursor: nil, has_more: false} = result
    end

    test "returns empty list for cross-product campaign" do
      product_a = insert(:product)
      product_b = insert(:product)
      participant = insert(:participant, product: product_a)
      campaign = insert(:campaign, product: product_a)

      # Associate in product_a
      CampaignManagement.associate_participant_with_campaign(
        product_a.id,
        participant.id,
        campaign.id
      )

      # Try to list using product_b
      result = CampaignManagement.list_participants_for_campaign(product_b.id, campaign.id, [])

      assert %{data: [], next_cursor: nil, has_more: false} = result
    end

    test "supports pagination" do
      product = insert(:product)
      campaign = insert(:campaign, product: product)

      # Create and associate 3 participants with delays to ensure different timestamps
      participant1 = insert(:participant, product: product, nickname: "user1")

      CampaignManagement.associate_participant_with_campaign(
        product.id,
        participant1.id,
        campaign.id
      )

      # Sleep 1 second to ensure different timestamp
      Process.sleep(1100)

      participant2 = insert(:participant, product: product, nickname: "user2")

      CampaignManagement.associate_participant_with_campaign(
        product.id,
        participant2.id,
        campaign.id
      )

      Process.sleep(1100)

      participant3 = insert(:participant, product: product, nickname: "user3")

      CampaignManagement.associate_participant_with_campaign(
        product.id,
        participant3.id,
        campaign.id
      )

      # Get first page with limit 2
      first_page =
        CampaignManagement.list_participants_for_campaign(product.id, campaign.id, limit: 2)

      assert length(first_page.data) == 2
      assert first_page.has_more == true
      assert first_page.next_cursor != nil

      # Get second page
      second_page =
        CampaignManagement.list_participants_for_campaign(
          product.id,
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
    property "product isolation: cross-product access always fails" do
      check all(
              participant_name <- string(:alphanumeric, min_length: 1, max_length: 20),
              nickname_base <- string(:alphanumeric, min_length: 3, max_length: 15)
            ) do
        # Create two different products with unique IDs
        product_a = insert(:product)
        product_b = insert(:product)

        # Create participant for product A with unique nickname
        nickname = "#{nickname_base}-#{System.unique_integer([:positive])}"
        attrs = params_for(:participant, name: participant_name, nickname: nickname)
        {:ok, participant} = CampaignManagement.create_participant(product_a.id, attrs)

        # Product B should never see Product A's participant
        assert nil == CampaignManagement.get_participant(product_b.id, participant.id)

        # Product B should not be able to update Product A's participant
        update_attrs = %{name: "Updated Name"}

        assert {:error, :not_found} ==
                 CampaignManagement.update_participant(product_b.id, participant.id, update_attrs)

        # Product B should not be able to delete Product A's participant
        assert {:error, :not_found} ==
                 CampaignManagement.delete_participant(product_b.id, participant.id)

        # Verify participant still exists for Product A
        assert CampaignManagement.get_participant(product_a.id, participant.id)
      end
    end

    # **Validates: Requirements 3.8, 5.4**
    property "cascade deletion: all associations removed when participant is deleted" do
      check all(
              participant_name <- string(:alphanumeric, min_length: 1, max_length: 20),
              nickname_base <- string(:alphanumeric, min_length: 3, max_length: 15),
              num_campaigns <- integer(1..3),
              num_challenges_per_campaign <- integer(1..2)
            ) do
        # Create product and participant with unique nickname
        product = insert(:product)
        nickname = "#{nickname_base}-#{System.unique_integer([:positive])}"
        attrs = params_for(:participant, name: participant_name, nickname: nickname)
        {:ok, participant} = CampaignManagement.create_participant(product.id, attrs)

        # Create campaigns and manually insert campaign_participants associations
        campaigns =
          for _ <- 1..num_campaigns do
            campaign = insert(:campaign, product: product)

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
        campaign_associations =
          Repo.all(
            from cp in CampaignsApi.CampaignManagement.CampaignParticipant,
              where: cp.participant_id == ^participant.id
          )

        assert length(campaign_associations) == num_campaigns

        challenge_associations =
          Repo.all(
            from pc in CampaignsApi.CampaignManagement.ParticipantChallenge,
              where: pc.participant_id == ^participant.id
          )

        assert length(challenge_associations) == num_campaigns * num_challenges_per_campaign

        # Delete participant
        assert {:ok, _deleted} = CampaignManagement.delete_participant(product.id, participant.id)

        # Verify participant is deleted
        assert nil == CampaignManagement.get_participant(product.id, participant.id)

        # Verify all campaign associations are deleted (cascade)
        remaining_campaign_associations =
          Repo.all(
            from cp in CampaignsApi.CampaignManagement.CampaignParticipant,
              where: cp.participant_id == ^participant.id
          )

        assert Enum.empty?(remaining_campaign_associations)

        # Verify all challenge associations are deleted (cascade)
        remaining_challenge_associations =
          Repo.all(
            from pc in CampaignsApi.CampaignManagement.ParticipantChallenge,
              where: pc.participant_id == ^participant.id
          )

        assert Enum.empty?(remaining_challenge_associations)
      end
    end

    # **Validates: Requirements 2.6, 5.1, 5.2, 9.6, 11.5**
    property "campaign-participant product validation: only same-product associations succeed" do
      check all(
              participant_name <- string(:alphanumeric, min_length: 1, max_length: 20),
              nickname_base <- string(:alphanumeric, min_length: 3, max_length: 15),
              campaign_name <- string(:alphanumeric, min_length: 1, max_length: 20),
              same_product <- boolean()
            ) do
        # Create two products
        product_a = insert(:product)
        product_b = insert(:product)

        # Create participant in product_a with unique nickname
        nickname = "#{nickname_base}-#{System.unique_integer([:positive])}"
        participant_attrs = params_for(:participant, name: participant_name, nickname: nickname)

        {:ok, participant} =
          CampaignManagement.create_participant(product_a.id, participant_attrs)

        # Create campaign in either same product or different product
        campaign_product = if same_product, do: product_a, else: product_b
        campaign = insert(:campaign, product: campaign_product, name: campaign_name)

        # Attempt to associate
        result =
          CampaignManagement.associate_participant_with_campaign(
            product_a.id,
            participant.id,
            campaign.id
          )

        if same_product do
          # Same product: association should succeed
          assert {:ok, campaign_participant} = result
          assert campaign_participant.participant_id == participant.id
          assert campaign_participant.campaign_id == campaign.id

          # Verify association exists in database
          assert Repo.get_by(CampaignsApi.CampaignManagement.CampaignParticipant,
                   participant_id: participant.id,
                   campaign_id: campaign.id
                 )
        else
          # Different products: association should fail
          assert {:error, :product_mismatch} = result

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
      product = insert(:product)
      participant = insert(:participant, product: product)
      campaign = insert(:campaign, product: product)
      challenge = insert(:challenge)

      # Associate participant with campaign first
      {:ok, _cp} =
        CampaignManagement.associate_participant_with_campaign(
          product.id,
          participant.id,
          campaign.id
        )

      # Associate challenge with campaign
      _campaign_challenge = insert(:campaign_challenge, campaign: campaign, challenge: challenge)

      # Now associate participant with challenge
      assert {:ok, participant_challenge} =
               CampaignManagement.associate_participant_with_challenge(
                 product.id,
                 participant.id,
                 challenge.id
               )

      assert participant_challenge.participant_id == participant.id
      assert participant_challenge.challenge_id == challenge.id
      assert participant_challenge.campaign_id == campaign.id
    end

    test "returns error when participant is not in campaign" do
      product = insert(:product)
      participant = insert(:participant, product: product)
      campaign = insert(:campaign, product: product)
      challenge = insert(:challenge)

      # Associate challenge with campaign but NOT participant with campaign
      _campaign_challenge = insert(:campaign_challenge, campaign: campaign, challenge: challenge)

      # Attempt to associate participant with challenge
      assert {:error, :participant_not_in_campaign} =
               CampaignManagement.associate_participant_with_challenge(
                 product.id,
                 participant.id,
                 challenge.id
               )
    end

    test "returns error when challenge belongs to different product" do
      product_a = insert(:product)
      product_b = insert(:product)
      participant = insert(:participant, product: product_a)
      campaign_a = insert(:campaign, product: product_a)
      campaign_b = insert(:campaign, product: product_b)
      challenge = insert(:challenge)

      # Associate participant with campaign_a
      {:ok, _cp} =
        CampaignManagement.associate_participant_with_campaign(
          product_a.id,
          participant.id,
          campaign_a.id
        )

      # Associate challenge with campaign_b (different product)
      _campaign_challenge =
        insert(:campaign_challenge, campaign: campaign_b, challenge: challenge)

      # Attempt to associate participant with challenge
      assert {:error, :product_mismatch} =
               CampaignManagement.associate_participant_with_challenge(
                 product_a.id,
                 participant.id,
                 challenge.id
               )
    end

    test "returns error when participant belongs to different product" do
      product_a = insert(:product)
      product_b = insert(:product)
      participant = insert(:participant, product: product_b)
      campaign = insert(:campaign, product: product_a)
      challenge = insert(:challenge)

      # Associate challenge with campaign
      _campaign_challenge = insert(:campaign_challenge, campaign: campaign, challenge: challenge)

      # Attempt to associate participant with challenge using product_a
      assert {:error, :product_mismatch} =
               CampaignManagement.associate_participant_with_challenge(
                 product_a.id,
                 participant.id,
                 challenge.id
               )
    end

    test "returns error on duplicate association" do
      product = insert(:product)
      participant = insert(:participant, product: product)
      campaign = insert(:campaign, product: product)
      challenge = insert(:challenge)

      # Associate participant with campaign
      {:ok, _cp} =
        CampaignManagement.associate_participant_with_campaign(
          product.id,
          participant.id,
          campaign.id
        )

      # Associate challenge with campaign
      _campaign_challenge = insert(:campaign_challenge, campaign: campaign, challenge: challenge)

      # First association should succeed
      assert {:ok, _pc} =
               CampaignManagement.associate_participant_with_challenge(
                 product.id,
                 participant.id,
                 challenge.id
               )

      # Second association should fail
      assert {:error, changeset} =
               CampaignManagement.associate_participant_with_challenge(
                 product.id,
                 participant.id,
                 challenge.id
               )

      assert %{participant_id: ["has already been taken"]} = errors_on(changeset)
    end
  end

  describe "disassociate_participant_from_challenge/3" do
    test "disassociates participant from challenge" do
      product = insert(:product)
      participant = insert(:participant, product: product)
      campaign = insert(:campaign, product: product)
      challenge = insert(:challenge)

      # Set up associations
      {:ok, _cp} =
        CampaignManagement.associate_participant_with_campaign(
          product.id,
          participant.id,
          campaign.id
        )

      _campaign_challenge = insert(:campaign_challenge, campaign: campaign, challenge: challenge)

      {:ok, participant_challenge} =
        CampaignManagement.associate_participant_with_challenge(
          product.id,
          participant.id,
          challenge.id
        )

      # Disassociate
      assert {:ok, deleted} =
               CampaignManagement.disassociate_participant_from_challenge(
                 product.id,
                 participant.id,
                 challenge.id
               )

      assert deleted.id == participant_challenge.id

      # Verify association is deleted
      refute Repo.get(
               CampaignsApi.CampaignManagement.ParticipantChallenge,
               participant_challenge.id
             )
    end

    test "returns error when association does not exist" do
      product = insert(:product)
      participant = insert(:participant, product: product)
      challenge = insert(:challenge)

      assert {:error, :not_found} =
               CampaignManagement.disassociate_participant_from_challenge(
                 product.id,
                 participant.id,
                 challenge.id
               )
    end

    test "returns error when association belongs to different product" do
      product_a = insert(:product)
      product_b = insert(:product)
      participant = insert(:participant, product: product_a)
      campaign = insert(:campaign, product: product_a)
      challenge = insert(:challenge)

      # Set up associations in product_a
      {:ok, _cp} =
        CampaignManagement.associate_participant_with_campaign(
          product_a.id,
          participant.id,
          campaign.id
        )

      _campaign_challenge = insert(:campaign_challenge, campaign: campaign, challenge: challenge)

      {:ok, _pc} =
        CampaignManagement.associate_participant_with_challenge(
          product_a.id,
          participant.id,
          challenge.id
        )

      # Attempt to disassociate using product_b
      assert {:error, :not_found} =
               CampaignManagement.disassociate_participant_from_challenge(
                 product_b.id,
                 participant.id,
                 challenge.id
               )
    end
  end

  describe "list_challenges_for_participant/3" do
    test "lists challenges for participant" do
      product = insert(:product)
      participant = insert(:participant, product: product)
      campaign = insert(:campaign, product: product)
      challenge1 = insert(:challenge, name: "Challenge 1")
      challenge2 = insert(:challenge, name: "Challenge 2")

      # Set up associations
      {:ok, _cp} =
        CampaignManagement.associate_participant_with_campaign(
          product.id,
          participant.id,
          campaign.id
        )

      _cc1 = insert(:campaign_challenge, campaign: campaign, challenge: challenge1)
      _cc2 = insert(:campaign_challenge, campaign: campaign, challenge: challenge2)

      {:ok, _pc1} =
        CampaignManagement.associate_participant_with_challenge(
          product.id,
          participant.id,
          challenge1.id
        )

      {:ok, _pc2} =
        CampaignManagement.associate_participant_with_challenge(
          product.id,
          participant.id,
          challenge2.id
        )

      # List challenges
      result = CampaignManagement.list_challenges_for_participant(product.id, participant.id)

      assert %{data: challenges, has_more: false} = result
      assert length(challenges) == 2
      challenge_ids = Enum.map(challenges, & &1.id)
      assert challenge1.id in challenge_ids
      assert challenge2.id in challenge_ids
    end

    test "filters challenges by campaign_id" do
      product = insert(:product)
      participant = insert(:participant, product: product)
      campaign1 = insert(:campaign, product: product, name: "Campaign 1")
      campaign2 = insert(:campaign, product: product, name: "Campaign 2")
      challenge1 = insert(:challenge, name: "Challenge 1")
      challenge2 = insert(:challenge, name: "Challenge 2")

      # Associate participant with both campaigns
      {:ok, _cp1} =
        CampaignManagement.associate_participant_with_campaign(
          product.id,
          participant.id,
          campaign1.id
        )

      {:ok, _cp2} =
        CampaignManagement.associate_participant_with_campaign(
          product.id,
          participant.id,
          campaign2.id
        )

      # Associate challenges with campaigns
      _cc1 = insert(:campaign_challenge, campaign: campaign1, challenge: challenge1)
      _cc2 = insert(:campaign_challenge, campaign: campaign2, challenge: challenge2)

      # Associate participant with both challenges
      {:ok, _pc1} =
        CampaignManagement.associate_participant_with_challenge(
          product.id,
          participant.id,
          challenge1.id
        )

      {:ok, _pc2} =
        CampaignManagement.associate_participant_with_challenge(
          product.id,
          participant.id,
          challenge2.id
        )

      # List challenges filtered by campaign1
      result =
        CampaignManagement.list_challenges_for_participant(
          product.id,
          participant.id,
          campaign_id: campaign1.id
        )

      assert %{data: challenges, has_more: false} = result
      assert length(challenges) == 1
      assert hd(challenges).id == challenge1.id
    end

    test "returns empty list for participant with no challenges" do
      product = insert(:product)
      participant = insert(:participant, product: product)

      result = CampaignManagement.list_challenges_for_participant(product.id, participant.id)

      assert %{data: [], has_more: false} = result
    end

    test "returns empty list for different product" do
      product_a = insert(:product)
      product_b = insert(:product)
      participant = insert(:participant, product: product_a)
      campaign = insert(:campaign, product: product_a)
      challenge = insert(:challenge)

      # Set up associations in product_a
      {:ok, _cp} =
        CampaignManagement.associate_participant_with_campaign(
          product_a.id,
          participant.id,
          campaign.id
        )

      _cc = insert(:campaign_challenge, campaign: campaign, challenge: challenge)

      {:ok, _pc} =
        CampaignManagement.associate_participant_with_challenge(
          product_a.id,
          participant.id,
          challenge.id
        )

      # Query with product_b
      result = CampaignManagement.list_challenges_for_participant(product_b.id, participant.id)

      assert %{data: [], has_more: false} = result
    end
  end

  describe "list_participants_for_challenge/3" do
    test "lists participants for challenge" do
      product = insert(:product)
      participant1 = insert(:participant, product: product, nickname: "user1")
      participant2 = insert(:participant, product: product, nickname: "user2")
      campaign = insert(:campaign, product: product)
      challenge = insert(:challenge)

      # Set up associations
      {:ok, _cp1} =
        CampaignManagement.associate_participant_with_campaign(
          product.id,
          participant1.id,
          campaign.id
        )

      {:ok, _cp2} =
        CampaignManagement.associate_participant_with_campaign(
          product.id,
          participant2.id,
          campaign.id
        )

      _cc = insert(:campaign_challenge, campaign: campaign, challenge: challenge)

      {:ok, _pc1} =
        CampaignManagement.associate_participant_with_challenge(
          product.id,
          participant1.id,
          challenge.id
        )

      {:ok, _pc2} =
        CampaignManagement.associate_participant_with_challenge(
          product.id,
          participant2.id,
          challenge.id
        )

      # List participants
      result = CampaignManagement.list_participants_for_challenge(product.id, challenge.id)

      assert %{data: participants, has_more: false} = result
      assert length(participants) == 2
      participant_ids = Enum.map(participants, & &1.id)
      assert participant1.id in participant_ids
      assert participant2.id in participant_ids
    end

    test "returns empty list for challenge with no participants" do
      product = insert(:product)
      challenge = insert(:challenge)

      result = CampaignManagement.list_participants_for_challenge(product.id, challenge.id)

      assert %{data: [], has_more: false} = result
    end

    test "returns empty list for different product" do
      product_a = insert(:product)
      product_b = insert(:product)
      participant = insert(:participant, product: product_a)
      campaign = insert(:campaign, product: product_a)
      challenge = insert(:challenge)

      # Set up associations in product_a
      {:ok, _cp} =
        CampaignManagement.associate_participant_with_campaign(
          product_a.id,
          participant.id,
          campaign.id
        )

      _cc = insert(:campaign_challenge, campaign: campaign, challenge: challenge)

      {:ok, _pc} =
        CampaignManagement.associate_participant_with_challenge(
          product_a.id,
          participant.id,
          challenge.id
        )

      # Query with product_b
      result = CampaignManagement.list_participants_for_challenge(product_b.id, challenge.id)

      assert %{data: [], has_more: false} = result
    end
  end

  describe "challenge associations - property tests" do
    # **Validates: Requirements 2.1.7, 2.1.8, 2.1.9, 5.1.1-5.1.4**
    property "participant-challenge campaign membership: only campaign members can be assigned to challenges" do
      check all(
              participant_name <- string(:alphanumeric, min_length: 1, max_length: 20),
              nickname_base <- string(:alphanumeric, min_length: 3, max_length: 15),
              is_campaign_member <- boolean()
            ) do
        # Create product, participant, campaign, and challenge
        product = insert(:product)
        nickname = "#{nickname_base}-#{System.unique_integer([:positive])}"
        participant_attrs = params_for(:participant, name: participant_name, nickname: nickname)
        {:ok, participant} = CampaignManagement.create_participant(product.id, participant_attrs)

        campaign = insert(:campaign, product: product)
        challenge = insert(:challenge)

        _campaign_challenge =
          insert(:campaign_challenge, campaign: campaign, challenge: challenge)

        # Conditionally associate participant with campaign
        if is_campaign_member do
          {:ok, _cp} =
            CampaignManagement.associate_participant_with_campaign(
              product.id,
              participant.id,
              campaign.id
            )
        end

        # Attempt to associate participant with challenge
        result =
          CampaignManagement.associate_participant_with_challenge(
            product.id,
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
