defmodule CampaignsApiWeb.CampaignChallengeControllerTest do
  use CampaignsApiWeb.ConnCase, async: true
  use ExUnitProperties

  alias CampaignsApi.CampaignManagement

  setup %{conn: conn} do
    product = insert(:product)
    token = jwt_token(product.id)
    conn = put_req_header(conn, "authorization", "Bearer #{token}")

    campaign = insert(:campaign, product: product)
    challenge = insert(:challenge)

    {:ok, conn: conn, product: product, campaign: campaign, challenge: challenge}
  end

  describe "POST /api/campaigns/:campaign_id/challenges (create)" do
    test "creates campaign challenge with valid data", %{
      conn: conn,
      campaign: campaign,
      challenge: challenge
    } do
      params = %{
        "challenge_id" => challenge.id,
        "display_name" => "Buy+ Challenge",
        "display_description" => "Earn points for purchases",
        "evaluation_frequency" => "daily",
        "reward_points" => 100,
        "configuration" => %{"threshold" => 10}
      }

      conn = post(conn, ~p"/api/campaigns/#{campaign.id}/challenges", params)

      assert %{
               "id" => _id,
               "campaign_id" => campaign_id,
               "challenge_id" => challenge_id,
               "display_name" => "Buy+ Challenge",
               "display_description" => "Earn points for purchases",
               "evaluation_frequency" => "daily",
               "reward_points" => 100,
               "configuration" => %{"threshold" => 10}
             } = json_response(conn, 201)

      assert campaign_id == campaign.id
      assert challenge_id == challenge.id
    end

    test "creates campaign challenge with cron expression", %{
      conn: conn,
      campaign: campaign,
      challenge: challenge
    } do
      params = %{
        "challenge_id" => challenge.id,
        "display_name" => "Midnight Check",
        "evaluation_frequency" => "0 0 * * *",
        "reward_points" => 50
      }

      conn = post(conn, ~p"/api/campaigns/#{campaign.id}/challenges", params)

      assert %{"evaluation_frequency" => "0 0 * * *"} = json_response(conn, 201)
    end

    test "creates campaign challenge with negative reward points", %{
      conn: conn,
      campaign: campaign,
      challenge: challenge
    } do
      params = %{
        "challenge_id" => challenge.id,
        "display_name" => "Penalty Challenge",
        "evaluation_frequency" => "weekly",
        "reward_points" => -50
      }

      conn = post(conn, ~p"/api/campaigns/#{campaign.id}/challenges", params)

      assert %{"reward_points" => -50} = json_response(conn, 201)
    end

    test "returns 422 with validation errors for invalid data", %{
      conn: conn,
      campaign: campaign,
      challenge: challenge
    } do
      # Display name too short
      conn =
        post(conn, ~p"/api/campaigns/#{campaign.id}/challenges", %{
          "challenge_id" => challenge.id,
          "display_name" => "ab",
          "evaluation_frequency" => "daily",
          "reward_points" => 100
        })

      assert %{"errors" => errors} = json_response(conn, 422)
      assert Map.has_key?(errors, "display_name")
    end

    test "returns 422 with invalid evaluation frequency", %{
      conn: conn,
      campaign: campaign,
      challenge: challenge
    } do
      conn =
        post(conn, ~p"/api/campaigns/#{campaign.id}/challenges", %{
          "challenge_id" => challenge.id,
          "display_name" => "Test Challenge",
          "evaluation_frequency" => "invalid_frequency",
          "reward_points" => 100
        })

      assert %{"errors" => errors} = json_response(conn, 422)
      assert Map.has_key?(errors, "evaluation_frequency")
    end

    test "returns 422 when creating duplicate association", %{
      conn: conn,
      campaign: campaign,
      challenge: challenge
    } do
      params = %{
        "challenge_id" => challenge.id,
        "display_name" => "First Association",
        "evaluation_frequency" => "daily",
        "reward_points" => 100
      }

      # Create first association
      post(conn, ~p"/api/campaigns/#{campaign.id}/challenges", params)

      # Try to create duplicate
      conn = post(conn, ~p"/api/campaigns/#{campaign.id}/challenges", params)

      assert %{"errors" => _errors} = json_response(conn, 422)
    end

    test "returns 404 when campaign does not exist", %{conn: conn, challenge: challenge} do
      fake_id = Ecto.UUID.generate()

      conn =
        post(conn, ~p"/api/campaigns/#{fake_id}/challenges", %{
          "challenge_id" => challenge.id,
          "display_name" => "Test",
          "evaluation_frequency" => "daily",
          "reward_points" => 100
        })

      assert %{"error" => "Campaign not found"} = json_response(conn, 404)
    end

    test "returns 404 when campaign belongs to different product", %{
      conn: conn,
      challenge: challenge
    } do
      other_product = insert(:product)
      other_campaign = insert(:campaign, product: other_product)

      conn =
        post(conn, ~p"/api/campaigns/#{other_campaign.id}/challenges", %{
          "challenge_id" => challenge.id,
          "display_name" => "Test",
          "evaluation_frequency" => "daily",
          "reward_points" => 100
        })

      assert %{"error" => "Campaign not found"} = json_response(conn, 404)
    end

    test "allows any product to use any challenge", %{conn: conn, campaign: campaign} do
      # Create a challenge (challenges are global)
      global_challenge = insert(:challenge, name: "Global Challenge")

      params = %{
        "challenge_id" => global_challenge.id,
        "display_name" => "Using Global Challenge",
        "evaluation_frequency" => "daily",
        "reward_points" => 100
      }

      conn = post(conn, ~p"/api/campaigns/#{campaign.id}/challenges", params)

      assert %{"challenge_id" => challenge_id} = json_response(conn, 201)
      assert challenge_id == global_challenge.id
    end
  end

  describe "GET /api/campaigns/:campaign_id/challenges (index)" do
    test "returns empty list when no campaign challenges exist", %{conn: conn, campaign: campaign} do
      conn = get(conn, ~p"/api/campaigns/#{campaign.id}/challenges")

      assert %{"data" => [], "has_more" => false, "next_cursor" => nil} = json_response(conn, 200)
    end

    test "returns campaign challenges for the campaign", %{
      conn: conn,
      campaign: campaign
    } do
      challenge1 = insert(:challenge)
      challenge2 = insert(:challenge)

      insert(:campaign_challenge, campaign: campaign, challenge: challenge1)
      insert(:campaign_challenge, campaign: campaign, challenge: challenge2)

      conn = get(conn, ~p"/api/campaigns/#{campaign.id}/challenges")

      assert %{"data" => challenges, "has_more" => false} = json_response(conn, 200)
      assert length(challenges) == 2
    end

    test "supports pagination with limit parameter", %{
      conn: conn,
      campaign: campaign
    } do
      Enum.each(1..3, fn _ ->
        challenge = insert(:challenge)
        insert(:campaign_challenge, campaign: campaign, challenge: challenge)
      end)

      conn = get(conn, ~p"/api/campaigns/#{campaign.id}/challenges?limit=2")

      assert %{"data" => challenges, "has_more" => true, "next_cursor" => cursor} =
               json_response(conn, 200)

      assert length(challenges) == 2
      assert cursor != nil
    end

    test "does not return campaign challenges from other campaigns", %{
      conn: conn,
      product: product,
      campaign: campaign
    } do
      my_challenge = insert(:challenge)
      my_cc = insert(:campaign_challenge, campaign: campaign, challenge: my_challenge)

      other_campaign = insert(:campaign, product: product)
      other_challenge = insert(:challenge)
      insert(:campaign_challenge, campaign: other_campaign, challenge: other_challenge)

      conn = get(conn, ~p"/api/campaigns/#{campaign.id}/challenges")

      assert %{"data" => challenges} = json_response(conn, 200)
      assert length(challenges) == 1
      assert hd(challenges)["display_name"] == my_cc.display_name
    end

    test "returns 404 when campaign belongs to different product", %{conn: conn} do
      other_product = insert(:product)
      other_campaign = insert(:campaign, product: other_product)

      conn = get(conn, ~p"/api/campaigns/#{other_campaign.id}/challenges")

      # The list will be empty because product isolation prevents access
      assert %{"data" => []} = json_response(conn, 200)
    end

    test "handles missing limit parameter gracefully", %{conn: conn, campaign: campaign} do
      challenge1 = insert(:challenge)
      challenge2 = insert(:challenge)
      insert(:campaign_challenge, campaign: campaign, challenge: challenge1)
      insert(:campaign_challenge, campaign: campaign, challenge: challenge2)

      conn = get(conn, ~p"/api/campaigns/#{campaign.id}/challenges")

      assert %{"data" => challenges} = json_response(conn, 200)
      assert length(challenges) == 2
    end

    test "handles empty limit parameter gracefully", %{conn: conn, campaign: campaign} do
      challenge1 = insert(:challenge)
      challenge2 = insert(:challenge)
      insert(:campaign_challenge, campaign: campaign, challenge: challenge1)
      insert(:campaign_challenge, campaign: campaign, challenge: challenge2)

      conn = get(conn, ~p"/api/campaigns/#{campaign.id}/challenges?limit=")

      assert %{"data" => challenges} = json_response(conn, 200)
      assert length(challenges) == 2
    end

    test "handles invalid limit parameter gracefully", %{conn: conn, campaign: campaign} do
      challenge1 = insert(:challenge)
      challenge2 = insert(:challenge)
      insert(:campaign_challenge, campaign: campaign, challenge: challenge1)
      insert(:campaign_challenge, campaign: campaign, challenge: challenge2)

      conn = get(conn, ~p"/api/campaigns/#{campaign.id}/challenges?limit=invalid")

      assert %{"data" => challenges} = json_response(conn, 200)
      assert length(challenges) == 2
    end

    test "handles missing cursor parameter gracefully", %{conn: conn, campaign: campaign} do
      challenge1 = insert(:challenge)
      challenge2 = insert(:challenge)
      insert(:campaign_challenge, campaign: campaign, challenge: challenge1)
      insert(:campaign_challenge, campaign: campaign, challenge: challenge2)

      conn = get(conn, ~p"/api/campaigns/#{campaign.id}/challenges")

      assert %{"data" => challenges} = json_response(conn, 200)
      assert length(challenges) == 2
    end

    test "handles empty cursor parameter gracefully", %{conn: conn, campaign: campaign} do
      challenge1 = insert(:challenge)
      challenge2 = insert(:challenge)
      insert(:campaign_challenge, campaign: campaign, challenge: challenge1)
      insert(:campaign_challenge, campaign: campaign, challenge: challenge2)

      conn = get(conn, ~p"/api/campaigns/#{campaign.id}/challenges?cursor=")

      assert %{"data" => challenges} = json_response(conn, 200)
      assert length(challenges) == 2
    end

    test "handles invalid cursor parameter gracefully", %{conn: conn, campaign: campaign} do
      challenge1 = insert(:challenge)
      challenge2 = insert(:challenge)
      insert(:campaign_challenge, campaign: campaign, challenge: challenge1)
      insert(:campaign_challenge, campaign: campaign, challenge: challenge2)

      conn = get(conn, ~p"/api/campaigns/#{campaign.id}/challenges?cursor=invalid")

      assert %{"data" => challenges} = json_response(conn, 200)
      assert length(challenges) == 2
    end
  end

  describe "GET /api/campaigns/:campaign_id/challenges/:id (show)" do
    test "returns campaign challenge when it exists", %{
      conn: conn,
      campaign: campaign,
      challenge: challenge
    } do
      cc = insert(:campaign_challenge, campaign: campaign, challenge: challenge)

      conn = get(conn, ~p"/api/campaigns/#{campaign.id}/challenges/#{cc.id}")

      assert %{
               "id" => id,
               "campaign_id" => campaign_id,
               "challenge_id" => challenge_id,
               "display_name" => display_name
             } = json_response(conn, 200)

      assert id == cc.id
      assert campaign_id == campaign.id
      assert challenge_id == challenge.id
      assert display_name == cc.display_name
    end

    test "returns 404 when campaign challenge does not exist", %{conn: conn, campaign: campaign} do
      fake_id = Ecto.UUID.generate()
      conn = get(conn, ~p"/api/campaigns/#{campaign.id}/challenges/#{fake_id}")

      assert %{"error" => "Campaign challenge not found"} = json_response(conn, 404)
    end

    test "returns 404 when campaign belongs to different product", %{
      conn: conn,
      challenge: challenge
    } do
      other_product = insert(:product)
      other_campaign = insert(:campaign, product: other_product)
      other_cc = insert(:campaign_challenge, campaign: other_campaign, challenge: challenge)

      conn = get(conn, ~p"/api/campaigns/#{other_campaign.id}/challenges/#{other_cc.id}")

      assert %{"error" => "Campaign challenge not found"} = json_response(conn, 404)
    end
  end

  describe "PUT /api/campaigns/:campaign_id/challenges/:id (update)" do
    test "updates campaign challenge with valid data", %{
      conn: conn,
      campaign: campaign,
      challenge: challenge
    } do
      cc = insert(:campaign_challenge, campaign: campaign, challenge: challenge)

      update_params = %{
        "display_name" => "Updated Challenge Name",
        "display_description" => "New description",
        "evaluation_frequency" => "weekly",
        "reward_points" => 200
      }

      conn = put(conn, ~p"/api/campaigns/#{campaign.id}/challenges/#{cc.id}", update_params)

      assert %{
               "id" => id,
               "display_name" => "Updated Challenge Name",
               "display_description" => "New description",
               "evaluation_frequency" => "weekly",
               "reward_points" => 200
             } = json_response(conn, 200)

      assert id == cc.id
    end

    test "returns 422 with validation errors for invalid data", %{
      conn: conn,
      campaign: campaign,
      challenge: challenge
    } do
      cc = insert(:campaign_challenge, campaign: campaign, challenge: challenge)

      conn =
        put(conn, ~p"/api/campaigns/#{campaign.id}/challenges/#{cc.id}", %{
          "display_name" => "ab"
        })

      assert %{"errors" => errors} = json_response(conn, 422)
      assert Map.has_key?(errors, "display_name")
    end

    test "returns 404 when campaign challenge does not exist", %{conn: conn, campaign: campaign} do
      fake_id = Ecto.UUID.generate()

      conn =
        put(conn, ~p"/api/campaigns/#{campaign.id}/challenges/#{fake_id}", %{
          "display_name" => "Updated"
        })

      assert %{"error" => "Campaign challenge not found"} = json_response(conn, 404)
    end

    test "returns 404 when campaign belongs to different product", %{
      conn: conn,
      challenge: challenge
    } do
      other_product = insert(:product)
      other_campaign = insert(:campaign, product: other_product)
      other_cc = insert(:campaign_challenge, campaign: other_campaign, challenge: challenge)

      conn =
        put(conn, ~p"/api/campaigns/#{other_campaign.id}/challenges/#{other_cc.id}", %{
          "display_name" => "Hacked"
        })

      assert %{"error" => "Campaign challenge not found"} = json_response(conn, 404)
    end
  end

  describe "DELETE /api/campaigns/:campaign_id/challenges/:id (delete)" do
    test "deletes campaign challenge successfully", %{
      conn: conn,
      product: product,
      campaign: campaign,
      challenge: challenge
    } do
      cc = insert(:campaign_challenge, campaign: campaign, challenge: challenge)

      conn = delete(conn, ~p"/api/campaigns/#{campaign.id}/challenges/#{cc.id}")

      assert response(conn, 204) == ""
      assert CampaignManagement.get_campaign_challenge(product.id, campaign.id, cc.id) == nil
    end

    test "returns 404 when campaign challenge does not exist", %{conn: conn, campaign: campaign} do
      fake_id = Ecto.UUID.generate()
      conn = delete(conn, ~p"/api/campaigns/#{campaign.id}/challenges/#{fake_id}")

      assert %{"error" => "Campaign challenge not found"} = json_response(conn, 404)
    end

    test "returns 404 when campaign belongs to different product", %{
      conn: conn,
      challenge: challenge
    } do
      other_product = insert(:product)
      other_campaign = insert(:campaign, product: other_product)
      other_cc = insert(:campaign_challenge, campaign: other_campaign, challenge: challenge)

      conn = delete(conn, ~p"/api/campaigns/#{other_campaign.id}/challenges/#{other_cc.id}")

      assert %{"error" => "Campaign challenge not found"} = json_response(conn, 404)
    end
  end

  describe "property-based tests" do
    @tag :property
    property "campaign challenge responses include all required fields" do
      check all(
              display_name <- string(:alphanumeric, min_length: 3, max_length: 50),
              reward_points <- integer(-1000..1000),
              frequency <- member_of(["daily", "weekly", "monthly", "on_event"])
            ) do
        product = insert(:product)
        token = jwt_token(product.id)
        conn = build_conn() |> put_req_header("authorization", "Bearer #{token}")
        campaign = insert(:campaign, product: product)

        # Create a new challenge for each iteration to avoid unique constraint violations
        challenge = insert(:challenge)

        params = %{
          "challenge_id" => challenge.id,
          "display_name" => display_name,
          "evaluation_frequency" => frequency,
          "reward_points" => reward_points
        }

        conn = post(conn, ~p"/api/campaigns/#{campaign.id}/challenges", params)
        response = json_response(conn, 201)

        # Verify all required fields are present
        assert Map.has_key?(response, "id")
        assert Map.has_key?(response, "campaign_id")
        assert Map.has_key?(response, "challenge_id")
        assert Map.has_key?(response, "display_name")
        assert Map.has_key?(response, "display_description")
        assert Map.has_key?(response, "evaluation_frequency")
        assert Map.has_key?(response, "reward_points")
        assert Map.has_key?(response, "configuration")
        assert Map.has_key?(response, "inserted_at")
        assert Map.has_key?(response, "updated_at")

        # Verify field values match input
        assert response["campaign_id"] == campaign.id
        assert response["challenge_id"] == challenge.id
        assert response["display_name"] == display_name
        assert response["evaluation_frequency"] == frequency
        assert response["reward_points"] == reward_points
      end
    end

    @tag :property
    property "successful campaign challenge deletion returns HTTP 204 No Content" do
      check all(display_name <- string(:alphanumeric, min_length: 3, max_length: 50)) do
        product = insert(:product)
        token = jwt_token(product.id)
        conn = build_conn() |> put_req_header("authorization", "Bearer #{token}")
        campaign = insert(:campaign, product: product)
        challenge = insert(:challenge)

        cc =
          insert(:campaign_challenge,
            campaign: campaign,
            challenge: challenge,
            display_name: display_name
          )

        conn = delete(conn, ~p"/api/campaigns/#{campaign.id}/challenges/#{cc.id}")
        assert response(conn, 204) == ""
        assert CampaignManagement.get_campaign_challenge(product.id, campaign.id, cc.id) == nil
      end
    end

    @tag :property
    property "validation errors return structured JSON with 422 status" do
      check all(display_name <- string(:alphanumeric, min_length: 0, max_length: 2)) do
        product = insert(:product)
        token = jwt_token(product.id)
        conn = build_conn() |> put_req_header("authorization", "Bearer #{token}")
        campaign = insert(:campaign, product: product)
        challenge = insert(:challenge)

        conn =
          post(conn, ~p"/api/campaigns/#{campaign.id}/challenges", %{
            "challenge_id" => challenge.id,
            "display_name" => display_name,
            "evaluation_frequency" => "daily",
            "reward_points" => 100
          })

        assert %{"errors" => errors} = json_response(conn, 422)
        assert is_map(errors)
        assert Map.has_key?(errors, "display_name")
      end
    end

    @tag :property
    property "invalid evaluation frequency returns structured JSON with 422 status" do
      check all(
              invalid_frequency <- string(:alphanumeric, min_length: 1, max_length: 20),
              invalid_frequency not in ["daily", "weekly", "monthly", "on_event"]
            ) do
        product = insert(:product)
        token = jwt_token(product.id)
        conn = build_conn() |> put_req_header("authorization", "Bearer #{token}")
        campaign = insert(:campaign, product: product)
        challenge = insert(:challenge)

        # Skip valid cron expressions (5 parts separated by spaces)
        parts = String.split(invalid_frequency, " ")

        if length(parts) != 5 do
          conn =
            post(conn, ~p"/api/campaigns/#{campaign.id}/challenges", %{
              "challenge_id" => challenge.id,
              "display_name" => "Test Challenge",
              "evaluation_frequency" => invalid_frequency,
              "reward_points" => 100
            })

          assert %{"errors" => errors} = json_response(conn, 422)
          assert is_map(errors)
          assert Map.has_key?(errors, "evaluation_frequency")
        end
      end
    end

    @tag :property
    property "404 errors return structured JSON" do
      check all(_iteration <- integer(1..10)) do
        product = insert(:product)
        token = jwt_token(product.id)
        conn = build_conn() |> put_req_header("authorization", "Bearer #{token}")
        campaign = insert(:campaign, product: product)

        fake_id = Ecto.UUID.generate()
        conn = get(conn, ~p"/api/campaigns/#{campaign.id}/challenges/#{fake_id}")
        assert %{"error" => error_message} = json_response(conn, 404)
        assert is_binary(error_message)
        assert error_message == "Campaign challenge not found"
      end
    end

    @tag :property
    property "reward points can be positive, negative, or zero" do
      check all(reward_points <- integer(-10_000..10_000)) do
        product = insert(:product)
        token = jwt_token(product.id)
        conn = build_conn() |> put_req_header("authorization", "Bearer #{token}")
        campaign = insert(:campaign, product: product)

        # Create a new challenge for each iteration to avoid unique constraint violations
        challenge = insert(:challenge)

        params = %{
          "challenge_id" => challenge.id,
          "display_name" => "Points Test",
          "evaluation_frequency" => "daily",
          "reward_points" => reward_points
        }

        conn = post(conn, ~p"/api/campaigns/#{campaign.id}/challenges", params)
        response = json_response(conn, 201)

        assert response["reward_points"] == reward_points
      end
    end

    @tag :property
    property "cron expressions with 5 parts are accepted" do
      check all(
              part1 <- string(:alphanumeric, min_length: 1, max_length: 2),
              part2 <- string(:alphanumeric, min_length: 1, max_length: 2),
              part3 <- string(:alphanumeric, min_length: 1, max_length: 2),
              part4 <- string(:alphanumeric, min_length: 1, max_length: 2),
              part5 <- string(:alphanumeric, min_length: 1, max_length: 2)
            ) do
        product = insert(:product)
        token = jwt_token(product.id)
        conn = build_conn() |> put_req_header("authorization", "Bearer #{token}")
        campaign = insert(:campaign, product: product)

        # Create a new challenge for each iteration to avoid unique constraint violations
        challenge = insert(:challenge)
        cron_expression = "#{part1} #{part2} #{part3} #{part4} #{part5}"

        params = %{
          "challenge_id" => challenge.id,
          "display_name" => "Cron Test",
          "evaluation_frequency" => cron_expression,
          "reward_points" => 100
        }

        conn = post(conn, ~p"/api/campaigns/#{campaign.id}/challenges", params)
        response = json_response(conn, 201)

        assert response["evaluation_frequency"] == cron_expression
      end
    end
  end
end
