defmodule CampaignsApi.CampaignManagementCampaignChallengePropertyTest do
  @moduledoc """
  Property-based tests for CampaignChallenge operations in CampaignManagement context.

  Tests Properties 3, 7, and 8 from the design document.
  """

  use CampaignsApi.DataCase
  use ExUnitProperties

  alias CampaignsApi.CampaignManagement

  import CampaignsApi.Generators

  @iterations 100

  describe "Property 3: Campaign Challenge Unique Association" do
    @tag :property
    property "attempting to create duplicate campaign-challenge associations fails with unique constraint error" do
      check all(
              display_name1 <- string(:alphanumeric, min_length: 3, max_length: 50),
              display_name2 <- string(:alphanumeric, min_length: 3, max_length: 50),
              frequency1 <- evaluation_frequency_generator(),
              frequency2 <- evaluation_frequency_generator(),
              points1 <- reward_points_generator(),
              points2 <- reward_points_generator(),
              max_runs: @iterations
            ) do
        # Setup: Create tenant, campaign, and challenge
        tenant = insert(:tenant)
        campaign = insert(:campaign, tenant: tenant)
        challenge = insert(:challenge)

        # First association should succeed
        attrs1 = %{
          challenge_id: challenge.id,
          display_name: display_name1,
          evaluation_frequency: frequency1,
          reward_points: points1
        }

        {:ok, _cc1} =
          CampaignManagement.create_campaign_challenge(tenant.id, campaign.id, attrs1)

        # Second association with same campaign_id and challenge_id should fail
        attrs2 = %{
          challenge_id: challenge.id,
          display_name: display_name2,
          evaluation_frequency: frequency2,
          reward_points: points2
        }

        result = CampaignManagement.create_campaign_challenge(tenant.id, campaign.id, attrs2)

        # Assert: Should fail with unique constraint error
        assert {:error, changeset} = result
        assert %{campaign_id: ["has already been taken"]} = errors_on(changeset)
      end
    end
  end

  describe "Property 7: Campaign Challenge Cascade Deletion" do
    @tag :property
    property "deleting a campaign automatically deletes all associated campaign_challenges" do
      check all(
              num_challenges <- integer(1..5),
              display_names <-
                list_of(string(:alphanumeric, min_length: 3, max_length: 50),
                  length: num_challenges
                ),
              frequencies <- list_of(evaluation_frequency_generator(), length: num_challenges),
              points <- list_of(reward_points_generator(), length: num_challenges),
              max_runs: @iterations
            ) do
        # Setup: Create tenant and campaign
        tenant = insert(:tenant)
        campaign = insert(:campaign, tenant: tenant)

        # Create multiple campaign challenges
        campaign_challenge_ids =
          Enum.zip([display_names, frequencies, points])
          |> Enum.map(fn {display_name, frequency, reward_points} ->
            challenge = insert(:challenge)

            attrs = %{
              challenge_id: challenge.id,
              display_name: display_name,
              evaluation_frequency: frequency,
              reward_points: reward_points
            }

            {:ok, cc} =
              CampaignManagement.create_campaign_challenge(tenant.id, campaign.id, attrs)

            cc.id
          end)

        # Verify all campaign challenges exist before deletion
        Enum.each(campaign_challenge_ids, fn cc_id ->
          assert CampaignManagement.get_campaign_challenge(tenant.id, campaign.id, cc_id) != nil
        end)

        # Delete the campaign
        {:ok, _deleted_campaign} = CampaignManagement.delete_campaign(tenant.id, campaign.id)

        # Assert: All campaign challenges should be automatically deleted
        Enum.each(campaign_challenge_ids, fn cc_id ->
          assert CampaignManagement.get_campaign_challenge(tenant.id, campaign.id, cc_id) == nil
        end)
      end
    end
  end

  describe "Property 8: Campaign Ownership Validation" do
    @tag :property
    property "attempting to associate a challenge with a different tenant's campaign fails" do
      check all(
              display_name <- string(:alphanumeric, min_length: 3, max_length: 50),
              frequency <- evaluation_frequency_generator(),
              points <- reward_points_generator(),
              max_runs: @iterations
            ) do
        # Setup: Create two tenants and a campaign for tenant1
        tenant1 = insert(:tenant)
        tenant2 = insert(:tenant)
        campaign = insert(:campaign, tenant: tenant1)
        challenge = insert(:challenge)

        attrs = %{
          challenge_id: challenge.id,
          display_name: display_name,
          evaluation_frequency: frequency,
          reward_points: points
        }

        # Attempt to create campaign challenge using tenant2's ID with tenant1's campaign
        result = CampaignManagement.create_campaign_challenge(tenant2.id, campaign.id, attrs)

        # Assert: Should fail with campaign_not_found error
        assert {:error, :campaign_not_found} = result

        # Verify that tenant1 can still create the association
        {:ok, cc} = CampaignManagement.create_campaign_challenge(tenant1.id, campaign.id, attrs)
        assert cc.campaign_id == campaign.id
      end
    end

    @tag :property
    property "attempting to get a campaign challenge from a different tenant returns nil" do
      check all(
              display_name <- string(:alphanumeric, min_length: 3, max_length: 50),
              frequency <- evaluation_frequency_generator(),
              points <- reward_points_generator(),
              max_runs: @iterations
            ) do
        # Setup: Create two tenants and a campaign for tenant1
        tenant1 = insert(:tenant)
        tenant2 = insert(:tenant)
        campaign = insert(:campaign, tenant: tenant1)
        challenge = insert(:challenge)

        attrs = %{
          challenge_id: challenge.id,
          display_name: display_name,
          evaluation_frequency: frequency,
          reward_points: points
        }

        # Create campaign challenge for tenant1
        {:ok, cc} = CampaignManagement.create_campaign_challenge(tenant1.id, campaign.id, attrs)

        # Attempt to get campaign challenge using tenant2's ID
        result = CampaignManagement.get_campaign_challenge(tenant2.id, campaign.id, cc.id)

        # Assert: Should return nil (not found)
        assert result == nil

        # Verify that tenant1 can still get the campaign challenge
        result1 = CampaignManagement.get_campaign_challenge(tenant1.id, campaign.id, cc.id)
        assert result1 != nil
        assert result1.id == cc.id
      end
    end

    @tag :property
    property "attempting to update a campaign challenge from a different tenant fails" do
      check all(
              display_name <- string(:alphanumeric, min_length: 3, max_length: 50),
              new_display_name <- string(:alphanumeric, min_length: 3, max_length: 50),
              frequency <- evaluation_frequency_generator(),
              points <- reward_points_generator(),
              new_points <- reward_points_generator(),
              max_runs: @iterations
            ) do
        # Setup: Create two tenants and a campaign for tenant1
        tenant1 = insert(:tenant)
        tenant2 = insert(:tenant)
        campaign = insert(:campaign, tenant: tenant1)
        challenge = insert(:challenge)

        attrs = %{
          challenge_id: challenge.id,
          display_name: display_name,
          evaluation_frequency: frequency,
          reward_points: points
        }

        # Create campaign challenge for tenant1
        {:ok, cc} = CampaignManagement.create_campaign_challenge(tenant1.id, campaign.id, attrs)

        update_attrs = %{
          display_name: new_display_name,
          reward_points: new_points
        }

        # Attempt to update campaign challenge using tenant2's ID
        result =
          CampaignManagement.update_campaign_challenge(tenant2.id, campaign.id, cc.id, update_attrs)

        # Assert: Should fail with not_found error
        assert {:error, :not_found} = result

        # Verify that the campaign challenge was not modified
        unchanged = CampaignManagement.get_campaign_challenge(tenant1.id, campaign.id, cc.id)
        assert unchanged.display_name == display_name
        assert unchanged.reward_points == points
      end
    end

    @tag :property
    property "attempting to delete a campaign challenge from a different tenant fails" do
      check all(
              display_name <- string(:alphanumeric, min_length: 3, max_length: 50),
              frequency <- evaluation_frequency_generator(),
              points <- reward_points_generator(),
              max_runs: @iterations
            ) do
        # Setup: Create two tenants and a campaign for tenant1
        tenant1 = insert(:tenant)
        tenant2 = insert(:tenant)
        campaign = insert(:campaign, tenant: tenant1)
        challenge = insert(:challenge)

        attrs = %{
          challenge_id: challenge.id,
          display_name: display_name,
          evaluation_frequency: frequency,
          reward_points: points
        }

        # Create campaign challenge for tenant1
        {:ok, cc} = CampaignManagement.create_campaign_challenge(tenant1.id, campaign.id, attrs)

        # Attempt to delete campaign challenge using tenant2's ID
        result = CampaignManagement.delete_campaign_challenge(tenant2.id, campaign.id, cc.id)

        # Assert: Should fail with not_found error
        assert {:error, :not_found} = result

        # Verify that the campaign challenge still exists
        still_exists = CampaignManagement.get_campaign_challenge(tenant1.id, campaign.id, cc.id)
        assert still_exists != nil
        assert still_exists.id == cc.id
      end
    end
  end
end
