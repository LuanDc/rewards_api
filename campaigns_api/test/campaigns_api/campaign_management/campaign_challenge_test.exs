defmodule CampaignsApi.CampaignManagement.CampaignChallengeTest do
  use CampaignsApi.DataCase
  use ExUnitProperties

  import CampaignsApi.Factory
  import CampaignsApi.Generators

  alias CampaignsApi.CampaignManagement
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

  describe "Properties: Campaign Challenge Business Invariants" do
    @tag :property
    property "unique association - duplicate campaign-challenge associations fail" do
      check all(
              display_name1 <- string(:alphanumeric, min_length: 3, max_length: 50),
              display_name2 <- string(:alphanumeric, min_length: 3, max_length: 50),
              frequency1 <- evaluation_frequency_generator(),
              frequency2 <- evaluation_frequency_generator(),
              points1 <- reward_points_generator(),
              points2 <- reward_points_generator(),
              max_runs: 50
            ) do
        tenant = insert(:tenant)
        campaign = insert(:campaign, tenant: tenant)
        challenge = insert(:challenge)

        attrs1 = %{
          challenge_id: challenge.id,
          display_name: display_name1,
          evaluation_frequency: frequency1,
          reward_points: points1
        }

        {:ok, _cc1} =
          CampaignManagement.create_campaign_challenge(tenant.id, campaign.id, attrs1)

        attrs2 = %{
          challenge_id: challenge.id,
          display_name: display_name2,
          evaluation_frequency: frequency2,
          reward_points: points2
        }

        result = CampaignManagement.create_campaign_challenge(tenant.id, campaign.id, attrs2)

        assert {:error, changeset} = result
        assert %{campaign_id: ["has already been taken"]} = errors_on(changeset)
      end
    end

    @tag :property
    property "cascade deletion - deleting campaign deletes all campaign_challenges" do
      check all(
              num_challenges <- integer(1..5),
              max_runs: 50
            ) do
        tenant = insert(:tenant)
        campaign = insert(:campaign, tenant: tenant)

        campaign_challenge_ids =
          Enum.map(1..num_challenges, fn _ ->
            challenge = insert(:challenge)

            attrs = %{
              challenge_id: challenge.id,
              display_name: "Challenge #{System.unique_integer([:positive])}",
              evaluation_frequency: "daily",
              reward_points: 100
            }

            {:ok, cc} =
              CampaignManagement.create_campaign_challenge(tenant.id, campaign.id, attrs)

            cc.id
          end)

        Enum.each(campaign_challenge_ids, fn cc_id ->
          assert CampaignManagement.get_campaign_challenge(tenant.id, campaign.id, cc_id) != nil
        end)

        {:ok, _deleted_campaign} = CampaignManagement.delete_campaign(tenant.id, campaign.id)

        Enum.each(campaign_challenge_ids, fn cc_id ->
          assert CampaignManagement.get_campaign_challenge(tenant.id, campaign.id, cc_id) == nil
        end)
      end
    end

    @tag :property
    property "tenant validation - cross-tenant access always fails" do
      check all(
              display_name <- string(:alphanumeric, min_length: 3, max_length: 50),
              frequency <- evaluation_frequency_generator(),
              points <- reward_points_generator(),
              max_runs: 50
            ) do
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

        # Tenant2 cannot create association with tenant1's campaign
        result = CampaignManagement.create_campaign_challenge(tenant2.id, campaign.id, attrs)
        assert {:error, :campaign_not_found} = result

        # Tenant1 can create the association
        {:ok, cc} = CampaignManagement.create_campaign_challenge(tenant1.id, campaign.id, attrs)

        # Tenant2 cannot get tenant1's campaign challenge
        assert CampaignManagement.get_campaign_challenge(tenant2.id, campaign.id, cc.id) == nil

        # Tenant2 cannot update tenant1's campaign challenge
        update_attrs = %{reward_points: points + 100}

        assert {:error, :not_found} =
                 CampaignManagement.update_campaign_challenge(
                   tenant2.id,
                   campaign.id,
                   cc.id,
                   update_attrs
                 )

        # Tenant2 cannot delete tenant1's campaign challenge
        assert {:error, :not_found} =
                 CampaignManagement.delete_campaign_challenge(tenant2.id, campaign.id, cc.id)

        # Verify tenant1 can still access
        assert CampaignManagement.get_campaign_challenge(tenant1.id, campaign.id, cc.id) != nil
      end
    end
  end
end
