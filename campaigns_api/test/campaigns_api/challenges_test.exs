defmodule CampaignsApi.ChallengesTest do
  use CampaignsApi.DataCase, async: true

  alias CampaignsApi.CampaignManagement
  alias CampaignsApi.Challenges

  describe "list_challenges/1" do
    test "returns empty list when no challenges exist" do
      result = Challenges.list_challenges()

      assert result.data == []
      assert result.next_cursor == nil
      assert result.has_more == false
    end

    test "returns all challenges when count is less than default limit" do
      challenges = insert_list(5, :challenge)

      result = Challenges.list_challenges()

      assert length(result.data) == 5
      assert result.has_more == false
      assert result.next_cursor == nil

      returned_ids = Enum.map(result.data, & &1.id)
      challenge_ids = Enum.map(challenges, & &1.id)
      assert Enum.all?(challenge_ids, &(&1 in returned_ids))
    end

    test "respects custom limit parameter" do
      insert_list(10, :challenge)

      result = Challenges.list_challenges(limit: 3)

      assert length(result.data) == 3
      assert result.has_more == true
      assert result.next_cursor != nil
    end

    test "handles pagination with cursor" do
      insert_list(12, :challenge)

      first_page = Challenges.list_challenges(limit: 5)
      assert length(first_page.data) == 5

      if first_page.has_more do
        assert first_page.next_cursor != nil

        second_page = Challenges.list_challenges(limit: 5, cursor: first_page.next_cursor)

        first_page_ids = Enum.map(first_page.data, & &1.id)
        second_page_ids = Enum.map(second_page.data, & &1.id)

        assert Enum.all?(second_page_ids, &(&1 not in first_page_ids)),
               "Second page should not contain challenges from first page"
      end
    end

    test "enforces maximum limit of 100" do
      insert_list(150, :challenge)

      result = Challenges.list_challenges(limit: 200)

      assert length(result.data) <= 100
      assert result.has_more == true
    end
  end

  describe "get_challenge/1" do
    test "returns challenge when it exists" do
      challenge = insert(:challenge)

      result = Challenges.get_challenge(challenge.id)

      assert result.id == challenge.id
      assert result.name == challenge.name
    end

    test "returns nil when challenge does not exist" do
      non_existent_id = Ecto.UUID.generate()

      assert Challenges.get_challenge(non_existent_id) == nil
    end

    test "any tenant can retrieve any challenge (global availability)" do
      _tenant1 = insert(:tenant)
      _tenant2 = insert(:tenant)
      challenge = insert(:challenge)

      # Both tenants can access the same challenge
      result1 = Challenges.get_challenge(challenge.id)
      result2 = Challenges.get_challenge(challenge.id)

      assert result1.id == challenge.id
      assert result2.id == challenge.id
      assert result1.id == result2.id
    end
  end

  describe "create_challenge/1" do
    test "successfully creates challenge with valid data" do
      attrs = %{
        name: "TransactionsChecker",
        description: "Checks transaction behavior",
        metadata: %{"type" => "evaluation", "version" => 1}
      }

      {:ok, challenge} = Challenges.create_challenge(attrs)

      assert challenge.name == "TransactionsChecker"
      assert challenge.description == "Checks transaction behavior"
      assert challenge.metadata == %{"type" => "evaluation", "version" => 1}
      assert challenge.id != nil
    end

    test "successfully creates challenge with minimal data" do
      attrs = %{name: "MinimalChallenge"}

      {:ok, challenge} = Challenges.create_challenge(attrs)

      assert challenge.name == "MinimalChallenge"
      assert challenge.description == nil
      assert challenge.metadata == nil
    end

    test "returns error when name is missing" do
      attrs = %{description: "No name provided"}

      assert {:error, changeset} = Challenges.create_challenge(attrs)
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "returns error when name is too short" do
      attrs = %{name: "ab"}

      assert {:error, changeset} = Challenges.create_challenge(attrs)
      assert %{name: ["should be at least 3 character(s)"]} = errors_on(changeset)
    end

    test "accepts valid JSON in metadata field" do
      attrs = %{
        name: "MetadataChallenge",
        metadata: %{
          "config" => %{"threshold" => 100},
          "tags" => ["important", "daily"]
        }
      }

      {:ok, challenge} = Challenges.create_challenge(attrs)

      assert challenge.metadata["config"]["threshold"] == 100
      assert challenge.metadata["tags"] == ["important", "daily"]
    end
  end

  describe "update_challenge/2" do
    test "successfully updates challenge with valid data" do
      challenge = insert(:challenge, name: "OriginalName")

      {:ok, updated} = Challenges.update_challenge(challenge.id, %{name: "UpdatedName"})

      assert updated.id == challenge.id
      assert updated.name == "UpdatedName"
    end

    test "returns error when challenge does not exist" do
      non_existent_id = Ecto.UUID.generate()

      assert {:error, :not_found} =
               Challenges.update_challenge(non_existent_id, %{name: "NewName"})
    end

    test "returns error when update data is invalid" do
      challenge = insert(:challenge)

      assert {:error, changeset} = Challenges.update_challenge(challenge.id, %{name: "ab"})
      assert %{name: ["should be at least 3 character(s)"]} = errors_on(changeset)
    end

    test "can update metadata field" do
      challenge = insert(:challenge, metadata: %{"version" => 1})

      {:ok, updated} = Challenges.update_challenge(challenge.id, %{metadata: %{"version" => 2}})

      assert updated.metadata == %{"version" => 2}
    end
  end

  describe "delete_challenge/1" do
    test "successfully deletes challenge without associations" do
      challenge = insert(:challenge)

      assert {:ok, deleted} = Challenges.delete_challenge(challenge.id)
      assert deleted.id == challenge.id
      assert Challenges.get_challenge(challenge.id) == nil
    end

    test "returns error when challenge does not exist" do
      non_existent_id = Ecto.UUID.generate()

      assert {:error, :not_found} = Challenges.delete_challenge(non_existent_id)
    end

    test "returns error when challenge has campaign associations" do
      challenge = insert(:challenge)
      campaign = insert(:campaign)
      insert(:campaign_challenge, challenge: challenge, campaign: campaign)

      assert {:error, :has_associations} = Challenges.delete_challenge(challenge.id)

      # Challenge should still exist
      assert Challenges.get_challenge(challenge.id) != nil
    end

    test "challenge does not appear in list after deletion" do
      challenge1 = insert(:challenge)
      challenge2 = insert(:challenge)

      {:ok, _} = Challenges.delete_challenge(challenge1.id)

      result = Challenges.list_challenges()

      assert length(result.data) == 1
      assert hd(result.data).id == challenge2.id
    end
  end

  describe "list_campaign_challenges/3" do
    test "returns empty list when no campaign challenges exist" do
      tenant = insert(:tenant)
      campaign = insert(:campaign, tenant: tenant)

      result = CampaignManagement.list_campaign_challenges(tenant.id, campaign.id)

      assert result.data == []
      assert result.next_cursor == nil
      assert result.has_more == false
    end

    test "returns all campaign challenges for a specific campaign" do
      tenant = insert(:tenant)
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

    test "preloads challenge association" do
      tenant = insert(:tenant)
      campaign = insert(:campaign, tenant: tenant)
      challenge = insert(:challenge, name: "TestChallenge")

      insert(:campaign_challenge, campaign: campaign, challenge: challenge)

      result = CampaignManagement.list_campaign_challenges(tenant.id, campaign.id)

      assert length(result.data) == 1
      cc = hd(result.data)
      assert cc.challenge.name == "TestChallenge"
    end

    test "respects tenant isolation - does not return other tenant's campaign challenges" do
      tenant1 = insert(:tenant)
      tenant2 = insert(:tenant)
      campaign1 = insert(:campaign, tenant: tenant1)
      campaign2 = insert(:campaign, tenant: tenant2)
      challenge = insert(:challenge)

      insert(:campaign_challenge, campaign: campaign1, challenge: challenge)
      insert(:campaign_challenge, campaign: campaign2, challenge: challenge)

      result1 = CampaignManagement.list_campaign_challenges(tenant1.id, campaign1.id)
      result2 = CampaignManagement.list_campaign_challenges(tenant2.id, campaign2.id)

      assert length(result1.data) == 1
      assert length(result2.data) == 1
      assert hd(result1.data).campaign_id == campaign1.id
      assert hd(result2.data).campaign_id == campaign2.id
    end

    test "returns empty list when querying with wrong tenant_id" do
      tenant1 = insert(:tenant)
      tenant2 = insert(:tenant)
      campaign = insert(:campaign, tenant: tenant1)
      challenge = insert(:challenge)

      insert(:campaign_challenge, campaign: campaign, challenge: challenge)

      result = CampaignManagement.list_campaign_challenges(tenant2.id, campaign.id)

      assert result.data == []
    end

    test "respects pagination limit" do
      tenant = insert(:tenant)
      campaign = insert(:campaign, tenant: tenant)

      Enum.each(1..10, fn _ ->
        challenge = insert(:challenge)
        insert(:campaign_challenge, campaign: campaign, challenge: challenge)
      end)

      result = CampaignManagement.list_campaign_challenges(tenant.id, campaign.id, limit: 3)

      assert length(result.data) == 3
      assert result.has_more == true
      assert result.next_cursor != nil
    end

    test "handles pagination with cursor" do
      tenant = insert(:tenant)
      campaign = insert(:campaign, tenant: tenant)

      Enum.each(1..12, fn _ ->
        challenge = insert(:challenge)
        insert(:campaign_challenge, campaign: campaign, challenge: challenge)
      end)

      first_page = CampaignManagement.list_campaign_challenges(tenant.id, campaign.id, limit: 5)
      assert length(first_page.data) == 5

      if first_page.has_more do
        second_page =
          CampaignManagement.list_campaign_challenges(tenant.id, campaign.id,
            limit: 5,
            cursor: first_page.next_cursor
          )

        first_page_ids = Enum.map(first_page.data, & &1.id)
        second_page_ids = Enum.map(second_page.data, & &1.id)

        assert Enum.all?(second_page_ids, &(&1 not in first_page_ids))
      end
    end
  end

  describe "get_campaign_challenge/3" do
    test "returns campaign challenge when it exists" do
      tenant = insert(:tenant)
      campaign = insert(:campaign, tenant: tenant)
      challenge = insert(:challenge)
      cc = insert(:campaign_challenge, campaign: campaign, challenge: challenge)

      result = CampaignManagement.get_campaign_challenge(tenant.id, campaign.id, cc.id)

      assert result.id == cc.id
      assert result.campaign_id == campaign.id
      assert result.challenge_id == challenge.id
    end

    test "preloads challenge association" do
      tenant = insert(:tenant)
      campaign = insert(:campaign, tenant: tenant)
      challenge = insert(:challenge, name: "PreloadTest")
      cc = insert(:campaign_challenge, campaign: campaign, challenge: challenge)

      result = CampaignManagement.get_campaign_challenge(tenant.id, campaign.id, cc.id)

      assert result.challenge.name == "PreloadTest"
    end

    test "returns nil when campaign challenge does not exist" do
      tenant = insert(:tenant)
      campaign = insert(:campaign, tenant: tenant)
      non_existent_id = Ecto.UUID.generate()

      result = CampaignManagement.get_campaign_challenge(tenant.id, campaign.id, non_existent_id)

      assert result == nil
    end

    test "returns nil when querying with wrong tenant_id" do
      tenant1 = insert(:tenant)
      tenant2 = insert(:tenant)
      campaign = insert(:campaign, tenant: tenant1)
      challenge = insert(:challenge)
      cc = insert(:campaign_challenge, campaign: campaign, challenge: challenge)

      result = CampaignManagement.get_campaign_challenge(tenant2.id, campaign.id, cc.id)

      assert result == nil
    end

    test "returns nil when querying with wrong campaign_id" do
      tenant = insert(:tenant)
      campaign1 = insert(:campaign, tenant: tenant)
      campaign2 = insert(:campaign, tenant: tenant)
      challenge = insert(:challenge)
      cc = insert(:campaign_challenge, campaign: campaign1, challenge: challenge)

      result = CampaignManagement.get_campaign_challenge(tenant.id, campaign2.id, cc.id)

      assert result == nil
    end
  end

  describe "create_campaign_challenge/3" do
    test "successfully creates campaign challenge with valid data" do
      tenant = insert(:tenant)
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
      assert cc.evaluation_frequency == "daily"
      assert cc.reward_points == 100
    end

    test "returns error when campaign does not belong to tenant" do
      tenant1 = insert(:tenant)
      tenant2 = insert(:tenant)
      campaign = insert(:campaign, tenant: tenant1)
      challenge = insert(:challenge)

      attrs = %{
        challenge_id: challenge.id,
        display_name: "Cross-tenant Challenge",
        evaluation_frequency: "daily",
        reward_points: 100
      }

      result = CampaignManagement.create_campaign_challenge(tenant2.id, campaign.id, attrs)

      assert {:error, :campaign_not_found} = result
    end

    test "returns error when campaign does not exist" do
      tenant = insert(:tenant)
      challenge = insert(:challenge)
      non_existent_campaign_id = Ecto.UUID.generate()

      attrs = %{
        challenge_id: challenge.id,
        display_name: "Invalid Campaign",
        evaluation_frequency: "daily",
        reward_points: 100
      }

      result =
        CampaignManagement.create_campaign_challenge(tenant.id, non_existent_campaign_id, attrs)

      assert {:error, :campaign_not_found} = result
    end

    test "successfully creates with any valid challenge (challenges are global)" do
      tenant = insert(:tenant)
      campaign = insert(:campaign, tenant: tenant)
      challenge = insert(:challenge)

      attrs = %{
        challenge_id: challenge.id,
        display_name: "Global Challenge",
        evaluation_frequency: "daily",
        reward_points: 100
      }

      {:ok, cc} = CampaignManagement.create_campaign_challenge(tenant.id, campaign.id, attrs)

      assert cc.challenge_id == challenge.id
    end

    test "returns error when creating duplicate association" do
      tenant = insert(:tenant)
      campaign = insert(:campaign, tenant: tenant)
      challenge = insert(:challenge)

      attrs = %{
        challenge_id: challenge.id,
        display_name: "First Association",
        evaluation_frequency: "daily",
        reward_points: 100
      }

      {:ok, _first} = CampaignManagement.create_campaign_challenge(tenant.id, campaign.id, attrs)

      result = CampaignManagement.create_campaign_challenge(tenant.id, campaign.id, attrs)

      assert {:error, changeset} = result
      assert %{campaign_id: ["has already been taken"]} = errors_on(changeset)
    end

    test "returns error when validation fails" do
      tenant = insert(:tenant)
      campaign = insert(:campaign, tenant: tenant)
      challenge = insert(:challenge)

      attrs = %{
        challenge_id: challenge.id,
        display_name: "ab",
        evaluation_frequency: "daily",
        reward_points: 100
      }

      result = CampaignManagement.create_campaign_challenge(tenant.id, campaign.id, attrs)

      assert {:error, changeset} = result
      assert %{display_name: ["should be at least 3 character(s)"]} = errors_on(changeset)
    end
  end

  describe "update_campaign_challenge/4" do
    test "successfully updates campaign challenge with valid data" do
      tenant = insert(:tenant)
      campaign = insert(:campaign, tenant: tenant)
      challenge = insert(:challenge)

      cc =
        insert(:campaign_challenge, campaign: campaign, challenge: challenge, reward_points: 100)

      {:ok, updated} =
        CampaignManagement.update_campaign_challenge(tenant.id, campaign.id, cc.id, %{
          reward_points: 200
        })

      assert updated.id == cc.id
      assert updated.reward_points == 200
    end

    test "returns error when campaign challenge does not exist" do
      tenant = insert(:tenant)
      campaign = insert(:campaign, tenant: tenant)
      non_existent_id = Ecto.UUID.generate()

      result =
        CampaignManagement.update_campaign_challenge(tenant.id, campaign.id, non_existent_id, %{
          reward_points: 200
        })

      assert {:error, :not_found} = result
    end

    test "returns error when querying with wrong tenant_id" do
      tenant1 = insert(:tenant)
      tenant2 = insert(:tenant)
      campaign = insert(:campaign, tenant: tenant1)
      challenge = insert(:challenge)
      cc = insert(:campaign_challenge, campaign: campaign, challenge: challenge)

      result =
        CampaignManagement.update_campaign_challenge(tenant2.id, campaign.id, cc.id, %{
          reward_points: 200
        })

      assert {:error, :not_found} = result
    end

    test "returns error when update data is invalid" do
      tenant = insert(:tenant)
      campaign = insert(:campaign, tenant: tenant)
      challenge = insert(:challenge)
      cc = insert(:campaign_challenge, campaign: campaign, challenge: challenge)

      result =
        CampaignManagement.update_campaign_challenge(tenant.id, campaign.id, cc.id, %{
          display_name: "ab"
        })

      assert {:error, changeset} = result
      assert %{display_name: ["should be at least 3 character(s)"]} = errors_on(changeset)
    end

    test "can update multiple fields at once" do
      tenant = insert(:tenant)
      campaign = insert(:campaign, tenant: tenant)
      challenge = insert(:challenge)
      cc = insert(:campaign_challenge, campaign: campaign, challenge: challenge)

      {:ok, updated} =
        CampaignManagement.update_campaign_challenge(tenant.id, campaign.id, cc.id, %{
          display_name: "Updated Name",
          reward_points: 300,
          evaluation_frequency: "weekly"
        })

      assert updated.display_name == "Updated Name"
      assert updated.reward_points == 300
      assert updated.evaluation_frequency == "weekly"
    end
  end

  describe "delete_campaign_challenge/3" do
    test "successfully deletes campaign challenge" do
      tenant = insert(:tenant)
      campaign = insert(:campaign, tenant: tenant)
      challenge = insert(:challenge)
      cc = insert(:campaign_challenge, campaign: campaign, challenge: challenge)

      {:ok, deleted} = CampaignManagement.delete_campaign_challenge(tenant.id, campaign.id, cc.id)

      assert deleted.id == cc.id
      assert CampaignManagement.get_campaign_challenge(tenant.id, campaign.id, cc.id) == nil
    end

    test "returns error when campaign challenge does not exist" do
      tenant = insert(:tenant)
      campaign = insert(:campaign, tenant: tenant)
      non_existent_id = Ecto.UUID.generate()

      result =
        CampaignManagement.delete_campaign_challenge(tenant.id, campaign.id, non_existent_id)

      assert {:error, :not_found} = result
    end

    test "returns error when querying with wrong tenant_id" do
      tenant1 = insert(:tenant)
      tenant2 = insert(:tenant)
      campaign = insert(:campaign, tenant: tenant1)
      challenge = insert(:challenge)
      cc = insert(:campaign_challenge, campaign: campaign, challenge: challenge)

      result = CampaignManagement.delete_campaign_challenge(tenant2.id, campaign.id, cc.id)

      assert {:error, :not_found} = result
    end

    test "campaign challenge does not appear in list after deletion" do
      tenant = insert(:tenant)
      campaign = insert(:campaign, tenant: tenant)
      challenge1 = insert(:challenge)
      challenge2 = insert(:challenge)
      cc1 = insert(:campaign_challenge, campaign: campaign, challenge: challenge1)
      cc2 = insert(:campaign_challenge, campaign: campaign, challenge: challenge2)

      {:ok, _} = CampaignManagement.delete_campaign_challenge(tenant.id, campaign.id, cc1.id)

      result = CampaignManagement.list_campaign_challenges(tenant.id, campaign.id)

      assert length(result.data) == 1
      assert hd(result.data).id == cc2.id
    end
  end

  describe "campaign deletion cascades to campaign_challenges" do
    test "deleting a campaign automatically deletes all associated campaign_challenges" do
      tenant = insert(:tenant)
      campaign = insert(:campaign, tenant: tenant)
      challenge1 = insert(:challenge)
      challenge2 = insert(:challenge)

      cc1 = insert(:campaign_challenge, campaign: campaign, challenge: challenge1)
      cc2 = insert(:campaign_challenge, campaign: campaign, challenge: challenge2)

      # Verify campaign challenges exist
      assert CampaignManagement.get_campaign_challenge(tenant.id, campaign.id, cc1.id) != nil
      assert CampaignManagement.get_campaign_challenge(tenant.id, campaign.id, cc2.id) != nil

      # Delete the campaign
      Repo.delete(campaign)

      # Verify campaign challenges are automatically deleted
      assert CampaignManagement.get_campaign_challenge(tenant.id, campaign.id, cc1.id) == nil
      assert CampaignManagement.get_campaign_challenge(tenant.id, campaign.id, cc2.id) == nil

      # Verify challenges still exist (only associations were deleted)
      assert Challenges.get_challenge(challenge1.id) != nil
      assert Challenges.get_challenge(challenge2.id) != nil
    end
  end

  describe "Unit tests for properties converted from property tests" do
    test "challenge created has UUID format" do
      {:ok, challenge} = Challenges.create_challenge(%{name: "Test Challenge"})

      assert is_binary(challenge.id)
      assert String.length(challenge.id) == 36
      assert challenge.id =~ ~r/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/
    end

    test "challenge can be created with optional fields" do
      {:ok, challenge} =
        Challenges.create_challenge(%{
          name: "Full Challenge",
          description: "Test description",
          metadata: %{"type" => "evaluation", "version" => 1}
        })

      assert challenge.description == "Test description"
      assert challenge.metadata == %{"type" => "evaluation", "version" => 1}
    end

    test "challenges are ordered by inserted_at descending" do
      insert_list(5, :challenge)

      result = Challenges.list_challenges()
      challenges = result.data

      assert length(challenges) == 5

      # Verify descending order
      timestamps = Enum.map(challenges, & &1.inserted_at)
      assert timestamps == Enum.sort(timestamps, {:desc, DateTime})
    end

    test "challenge includes all required fields" do
      {:ok, challenge} = Challenges.create_challenge(%{name: "Test Challenge"})

      assert Map.has_key?(challenge, :id)
      assert Map.has_key?(challenge, :name)
      assert Map.has_key?(challenge, :description)
      assert Map.has_key?(challenge, :metadata)
      assert Map.has_key?(challenge, :inserted_at)
      assert Map.has_key?(challenge, :updated_at)
    end

    test "challenge timestamps are stored in UTC" do
      {:ok, challenge} = Challenges.create_challenge(%{name: "Test Challenge"})

      assert challenge.inserted_at.time_zone == "Etc/UTC"
      assert challenge.updated_at.time_zone == "Etc/UTC"
    end
  end
end
