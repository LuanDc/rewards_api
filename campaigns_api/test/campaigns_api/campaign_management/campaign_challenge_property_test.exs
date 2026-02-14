defmodule CampaignsApi.CampaignManagement.CampaignChallengePropertyTest do
  use CampaignsApi.DataCase
  use ExUnitProperties

  import CampaignsApi.Factory
  import CampaignsApi.Generators

  alias CampaignsApi.CampaignManagement.CampaignChallenge

  describe "Property 4: Evaluation Frequency Validation" do
    # **Validates: Requirements 5.1, 5.2, 5.3**
    @tag :property
    property "evaluation_frequency must be valid cron expression or predefined keyword" do
      check all(
              frequency <- evaluation_frequency_generator(),
              max_runs: 100
            ) do
        campaign = insert(:campaign)
        challenge = insert(:challenge)

        attrs = %{
          campaign_id: campaign.id,
          challenge_id: challenge.id,
          display_name: "Test Challenge",
          evaluation_frequency: frequency,
          reward_points: 100
        }

        changeset = CampaignChallenge.changeset(%CampaignChallenge{}, attrs)

        # All generated frequencies should be valid
        assert changeset.valid?,
               "Expected frequency '#{frequency}' to be valid"
      end
    end

    @tag :property
    property "invalid evaluation_frequency formats are rejected" do
      check all(
              frequency <- invalid_evaluation_frequency_generator(),
              max_runs: 100
            ) do
        campaign = insert(:campaign)
        challenge = insert(:challenge)

        attrs = %{
          campaign_id: campaign.id,
          challenge_id: challenge.id,
          display_name: "Test Challenge",
          evaluation_frequency: frequency,
          reward_points: 100
        }

        changeset = CampaignChallenge.changeset(%CampaignChallenge{}, attrs)

        # All invalid frequencies should be rejected
        refute changeset.valid?,
               "Expected frequency '#{frequency}' to be invalid"

        assert %{evaluation_frequency: errors} = errors_on(changeset)
        assert errors != []
      end
    end
  end

  describe "Property 5: Reward Points Flexibility" do
    # **Validates: Requirements 6.1, 6.2**
    @tag :property
    property "reward_points accepts any integer value (positive, negative, or zero)" do
      check all(
              points <- reward_points_generator(),
              max_runs: 100
            ) do
        campaign = insert(:campaign)
        challenge = insert(:challenge)

        attrs = %{
          campaign_id: campaign.id,
          challenge_id: challenge.id,
          display_name: "Test Challenge",
          evaluation_frequency: "daily",
          reward_points: points
        }

        changeset = CampaignChallenge.changeset(%CampaignChallenge{}, attrs)

        # All integer values should be valid
        assert changeset.valid?,
               "Expected reward_points #{points} to be valid"

        assert get_change(changeset, :reward_points) == points
      end
    end
  end

  describe "Property 9: Metadata and Configuration Flexibility" do
    # **Validates: Requirements 9.1, 9.2, 9.3**
    @tag :property
    property "configuration accepts any valid JSON structure" do
      check all(
              config <- json_configuration_generator(),
              max_runs: 100
            ) do
        campaign = insert(:campaign)
        challenge = insert(:challenge)

        attrs = %{
          campaign_id: campaign.id,
          challenge_id: challenge.id,
          display_name: "Test Challenge",
          evaluation_frequency: "daily",
          reward_points: 100,
          configuration: config
        }

        changeset = CampaignChallenge.changeset(%CampaignChallenge{}, attrs)

        # All valid JSON structures should be accepted
        assert changeset.valid?,
               "Expected configuration #{inspect(config)} to be valid"

        # Verify the configuration is stored correctly
        stored_config = get_change(changeset, :configuration)
        assert stored_config == config
      end
    end
  end
end
