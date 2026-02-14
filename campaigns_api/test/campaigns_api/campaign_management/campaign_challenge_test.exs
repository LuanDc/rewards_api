defmodule CampaignsApi.CampaignManagement.CampaignChallengeTest do
  use CampaignsApi.DataCase

  import CampaignsApi.Factory

  alias CampaignsApi.CampaignManagement.CampaignChallenge

  describe "changeset/2" do
    test "creates valid campaign challenge with all fields" do
      campaign = insert(:campaign)
      challenge = insert(:challenge)

      attrs = %{
        campaign_id: campaign.id,
        challenge_id: challenge.id,
        display_name: "Buy+ Challenge",
        display_description: "Earn points for purchases",
        evaluation_frequency: "daily",
        reward_points: 100,
        configuration: %{"threshold" => 10, "multiplier" => 2}
      }

      changeset = CampaignChallenge.changeset(%CampaignChallenge{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :display_name) == "Buy+ Challenge"
      assert get_change(changeset, :display_description) == "Earn points for purchases"
      assert get_change(changeset, :evaluation_frequency) == "daily"
      assert get_change(changeset, :reward_points) == 100
      assert get_change(changeset, :configuration) == %{"threshold" => 10, "multiplier" => 2}
    end

    test "rejects campaign challenge with display_name less than 3 characters" do
      campaign = insert(:campaign)
      challenge = insert(:challenge)

      attrs = %{
        campaign_id: campaign.id,
        challenge_id: challenge.id,
        display_name: "ab",
        evaluation_frequency: "daily",
        reward_points: 100
      }

      changeset = CampaignChallenge.changeset(%CampaignChallenge{}, attrs)

      refute changeset.valid?
      assert %{display_name: ["should be at least 3 character(s)"]} = errors_on(changeset)
    end

    test "accepts campaign challenge with display_name exactly 3 characters" do
      campaign = insert(:campaign)
      challenge = insert(:challenge)

      attrs = %{
        campaign_id: campaign.id,
        challenge_id: challenge.id,
        display_name: "abc",
        evaluation_frequency: "daily",
        reward_points: 100
      }

      changeset = CampaignChallenge.changeset(%CampaignChallenge{}, attrs)

      assert changeset.valid?
    end

    test "accepts campaign challenge with display_name more than 3 characters" do
      campaign = insert(:campaign)
      challenge = insert(:challenge)

      attrs = %{
        campaign_id: campaign.id,
        challenge_id: challenge.id,
        display_name: "Valid Challenge Name",
        evaluation_frequency: "daily",
        reward_points: 100
      }

      changeset = CampaignChallenge.changeset(%CampaignChallenge{}, attrs)

      assert changeset.valid?
    end
  end

  describe "evaluation_frequency validation with predefined keywords" do
    test "accepts 'daily' keyword" do
      campaign = insert(:campaign)
      challenge = insert(:challenge)

      attrs = %{
        campaign_id: campaign.id,
        challenge_id: challenge.id,
        display_name: "Daily Challenge",
        evaluation_frequency: "daily",
        reward_points: 100
      }

      changeset = CampaignChallenge.changeset(%CampaignChallenge{}, attrs)

      assert changeset.valid?
    end

    test "accepts 'weekly' keyword" do
      campaign = insert(:campaign)
      challenge = insert(:challenge)

      attrs = %{
        campaign_id: campaign.id,
        challenge_id: challenge.id,
        display_name: "Weekly Challenge",
        evaluation_frequency: "weekly",
        reward_points: 100
      }

      changeset = CampaignChallenge.changeset(%CampaignChallenge{}, attrs)

      assert changeset.valid?
    end

    test "accepts 'monthly' keyword" do
      campaign = insert(:campaign)
      challenge = insert(:challenge)

      attrs = %{
        campaign_id: campaign.id,
        challenge_id: challenge.id,
        display_name: "Monthly Challenge",
        evaluation_frequency: "monthly",
        reward_points: 100
      }

      changeset = CampaignChallenge.changeset(%CampaignChallenge{}, attrs)

      assert changeset.valid?
    end

    test "accepts 'on_event' keyword" do
      campaign = insert(:campaign)
      challenge = insert(:challenge)

      attrs = %{
        campaign_id: campaign.id,
        challenge_id: challenge.id,
        display_name: "Event Challenge",
        evaluation_frequency: "on_event",
        reward_points: 100
      }

      changeset = CampaignChallenge.changeset(%CampaignChallenge{}, attrs)

      assert changeset.valid?
    end
  end

  describe "evaluation_frequency validation with cron expressions" do
    test "accepts valid cron expression with 5 parts" do
      campaign = insert(:campaign)
      challenge = insert(:challenge)

      attrs = %{
        campaign_id: campaign.id,
        challenge_id: challenge.id,
        display_name: "Cron Challenge",
        evaluation_frequency: "0 0 * * *",
        reward_points: 100
      }

      changeset = CampaignChallenge.changeset(%CampaignChallenge{}, attrs)

      assert changeset.valid?
    end

    test "accepts another valid cron expression" do
      campaign = insert(:campaign)
      challenge = insert(:challenge)

      attrs = %{
        campaign_id: campaign.id,
        challenge_id: challenge.id,
        display_name: "Cron Challenge",
        evaluation_frequency: "*/15 * * * *",
        reward_points: 100
      }

      changeset = CampaignChallenge.changeset(%CampaignChallenge{}, attrs)

      assert changeset.valid?
    end

    test "accepts cron expression with ranges" do
      campaign = insert(:campaign)
      challenge = insert(:challenge)

      attrs = %{
        campaign_id: campaign.id,
        challenge_id: challenge.id,
        display_name: "Cron Challenge",
        evaluation_frequency: "0 9-17 * * 1-5",
        reward_points: 100
      }

      changeset = CampaignChallenge.changeset(%CampaignChallenge{}, attrs)

      assert changeset.valid?
    end
  end

  describe "evaluation_frequency validation with invalid formats" do
    test "rejects cron expression with less than 5 parts" do
      campaign = insert(:campaign)
      challenge = insert(:challenge)

      attrs = %{
        campaign_id: campaign.id,
        challenge_id: challenge.id,
        display_name: "Invalid Cron",
        evaluation_frequency: "0 0 * *",
        reward_points: 100
      }

      changeset = CampaignChallenge.changeset(%CampaignChallenge{}, attrs)

      refute changeset.valid?

      assert %{evaluation_frequency: [error_msg]} = errors_on(changeset)
      assert error_msg =~ "must be a valid cron expression"
    end

    test "rejects cron expression with more than 5 parts" do
      campaign = insert(:campaign)
      challenge = insert(:challenge)

      attrs = %{
        campaign_id: campaign.id,
        challenge_id: challenge.id,
        display_name: "Invalid Cron",
        evaluation_frequency: "0 0 * * * *",
        reward_points: 100
      }

      changeset = CampaignChallenge.changeset(%CampaignChallenge{}, attrs)

      refute changeset.valid?

      assert %{evaluation_frequency: [error_msg]} = errors_on(changeset)
      assert error_msg =~ "must be a valid cron expression"
    end

    test "rejects invalid keyword" do
      campaign = insert(:campaign)
      challenge = insert(:challenge)

      attrs = %{
        campaign_id: campaign.id,
        challenge_id: challenge.id,
        display_name: "Invalid Keyword",
        evaluation_frequency: "hourly",
        reward_points: 100
      }

      changeset = CampaignChallenge.changeset(%CampaignChallenge{}, attrs)

      refute changeset.valid?

      assert %{evaluation_frequency: [error_msg]} = errors_on(changeset)
      assert error_msg =~ "must be a valid cron expression or one of: daily, weekly, monthly, on_event"
    end

    test "rejects empty string" do
      campaign = insert(:campaign)
      challenge = insert(:challenge)

      attrs = %{
        campaign_id: campaign.id,
        challenge_id: challenge.id,
        display_name: "Empty Frequency",
        evaluation_frequency: "",
        reward_points: 100
      }

      changeset = CampaignChallenge.changeset(%CampaignChallenge{}, attrs)

      refute changeset.valid?

      assert %{evaluation_frequency: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "reward_points validation" do
    test "accepts positive reward points" do
      campaign = insert(:campaign)
      challenge = insert(:challenge)

      attrs = %{
        campaign_id: campaign.id,
        challenge_id: challenge.id,
        display_name: "Positive Points",
        evaluation_frequency: "daily",
        reward_points: 100
      }

      changeset = CampaignChallenge.changeset(%CampaignChallenge{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :reward_points) == 100
    end

    test "accepts negative reward points" do
      campaign = insert(:campaign)
      challenge = insert(:challenge)

      attrs = %{
        campaign_id: campaign.id,
        challenge_id: challenge.id,
        display_name: "Negative Points",
        evaluation_frequency: "daily",
        reward_points: -50
      }

      changeset = CampaignChallenge.changeset(%CampaignChallenge{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :reward_points) == -50
    end

    test "accepts zero reward points" do
      campaign = insert(:campaign)
      challenge = insert(:challenge)

      attrs = %{
        campaign_id: campaign.id,
        challenge_id: challenge.id,
        display_name: "Zero Points",
        evaluation_frequency: "daily",
        reward_points: 0
      }

      changeset = CampaignChallenge.changeset(%CampaignChallenge{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :reward_points) == 0
    end

    test "accepts large positive reward points" do
      campaign = insert(:campaign)
      challenge = insert(:challenge)

      attrs = %{
        campaign_id: campaign.id,
        challenge_id: challenge.id,
        display_name: "Large Points",
        evaluation_frequency: "daily",
        reward_points: 999_999
      }

      changeset = CampaignChallenge.changeset(%CampaignChallenge{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :reward_points) == 999_999
    end

    test "accepts large negative reward points" do
      campaign = insert(:campaign)
      challenge = insert(:challenge)

      attrs = %{
        campaign_id: campaign.id,
        challenge_id: challenge.id,
        display_name: "Large Penalty",
        evaluation_frequency: "daily",
        reward_points: -999_999
      }

      changeset = CampaignChallenge.changeset(%CampaignChallenge{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :reward_points) == -999_999
    end
  end

  describe "configuration JSONB field" do
    test "accepts valid JSON configuration" do
      campaign = insert(:campaign)
      challenge = insert(:challenge)

      attrs = %{
        campaign_id: campaign.id,
        challenge_id: challenge.id,
        display_name: "Configured Challenge",
        evaluation_frequency: "daily",
        reward_points: 100,
        configuration: %{"threshold" => 10, "enabled" => true}
      }

      changeset = CampaignChallenge.changeset(%CampaignChallenge{}, attrs)

      assert changeset.valid?
      config = get_change(changeset, :configuration)
      assert config["threshold"] == 10
      assert config["enabled"] == true
    end

    test "accepts nil configuration" do
      campaign = insert(:campaign)
      challenge = insert(:challenge)

      attrs = %{
        campaign_id: campaign.id,
        challenge_id: challenge.id,
        display_name: "No Config",
        evaluation_frequency: "daily",
        reward_points: 100,
        configuration: nil
      }

      changeset = CampaignChallenge.changeset(%CampaignChallenge{}, attrs)

      assert changeset.valid?
    end

    test "accepts empty map configuration" do
      campaign = insert(:campaign)
      challenge = insert(:challenge)

      attrs = %{
        campaign_id: campaign.id,
        challenge_id: challenge.id,
        display_name: "Empty Config",
        evaluation_frequency: "daily",
        reward_points: 100,
        configuration: %{}
      }

      changeset = CampaignChallenge.changeset(%CampaignChallenge{}, attrs)

      assert changeset.valid?
    end

    test "accepts nested JSON configuration" do
      campaign = insert(:campaign)
      challenge = insert(:challenge)

      attrs = %{
        campaign_id: campaign.id,
        challenge_id: challenge.id,
        display_name: "Nested Config",
        evaluation_frequency: "daily",
        reward_points: 100,
        configuration: %{
          "rules" => %{
            "min_amount" => 100,
            "max_amount" => 1000
          },
          "tags" => ["premium", "active"]
        }
      }

      changeset = CampaignChallenge.changeset(%CampaignChallenge{}, attrs)

      assert changeset.valid?
      config = get_change(changeset, :configuration)
      assert config["rules"]["min_amount"] == 100
      assert config["tags"] == ["premium", "active"]
    end

    test "accepts various JSON data types in configuration" do
      campaign = insert(:campaign)
      challenge = insert(:challenge)

      attrs = %{
        campaign_id: campaign.id,
        challenge_id: challenge.id,
        display_name: "Mixed Types",
        evaluation_frequency: "daily",
        reward_points: 100,
        configuration: %{
          "string" => "value",
          "integer" => 42,
          "float" => 3.14,
          "boolean" => true,
          "null" => nil,
          "array" => [1, 2, 3],
          "object" => %{"nested" => "data"}
        }
      }

      changeset = CampaignChallenge.changeset(%CampaignChallenge{}, attrs)

      assert changeset.valid?
      config = get_change(changeset, :configuration)
      assert config["string"] == "value"
      assert config["integer"] == 42
      assert config["float"] == 3.14
      assert config["boolean"] == true
      assert config["null"] == nil
      assert config["array"] == [1, 2, 3]
      assert config["object"]["nested"] == "data"
    end
  end

  describe "unique constraint on (campaign_id, challenge_id)" do
    test "prevents duplicate campaign-challenge associations" do
      campaign = insert(:campaign)
      challenge = insert(:challenge)

      attrs = %{
        campaign_id: campaign.id,
        challenge_id: challenge.id,
        display_name: "First Association",
        evaluation_frequency: "daily",
        reward_points: 100
      }

      # Insert first association
      {:ok, _first} =
        %CampaignChallenge{}
        |> CampaignChallenge.changeset(attrs)
        |> Repo.insert()

      # Try to insert duplicate
      result =
        %CampaignChallenge{}
        |> CampaignChallenge.changeset(attrs)
        |> Repo.insert()

      assert {:error, changeset} = result
      assert %{campaign_id: ["has already been taken"]} = errors_on(changeset)
    end

    test "allows same challenge with different campaigns" do
      campaign1 = insert(:campaign)
      campaign2 = insert(:campaign)
      challenge = insert(:challenge)

      attrs1 = %{
        campaign_id: campaign1.id,
        challenge_id: challenge.id,
        display_name: "Campaign 1 Association",
        evaluation_frequency: "daily",
        reward_points: 100
      }

      attrs2 = %{
        campaign_id: campaign2.id,
        challenge_id: challenge.id,
        display_name: "Campaign 2 Association",
        evaluation_frequency: "weekly",
        reward_points: 200
      }

      {:ok, _first} =
        %CampaignChallenge{}
        |> CampaignChallenge.changeset(attrs1)
        |> Repo.insert()

      {:ok, _second} =
        %CampaignChallenge{}
        |> CampaignChallenge.changeset(attrs2)
        |> Repo.insert()

      # Both should succeed
      assert true
    end

    test "allows same campaign with different challenges" do
      campaign = insert(:campaign)
      challenge1 = insert(:challenge)
      challenge2 = insert(:challenge)

      attrs1 = %{
        campaign_id: campaign.id,
        challenge_id: challenge1.id,
        display_name: "Challenge 1 Association",
        evaluation_frequency: "daily",
        reward_points: 100
      }

      attrs2 = %{
        campaign_id: campaign.id,
        challenge_id: challenge2.id,
        display_name: "Challenge 2 Association",
        evaluation_frequency: "weekly",
        reward_points: 200
      }

      {:ok, _first} =
        %CampaignChallenge{}
        |> CampaignChallenge.changeset(attrs1)
        |> Repo.insert()

      {:ok, _second} =
        %CampaignChallenge{}
        |> CampaignChallenge.changeset(attrs2)
        |> Repo.insert()

      # Both should succeed
      assert true
    end
  end
end
