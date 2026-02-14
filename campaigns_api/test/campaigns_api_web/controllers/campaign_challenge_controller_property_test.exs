defmodule CampaignsApiWeb.CampaignChallengeControllerPropertyTest do
  use CampaignsApiWeb.ConnCase, async: true
  use ExUnitProperties

  alias CampaignsApi.CampaignManagement

  setup %{conn: conn} do
    tenant = insert(:tenant)
    token = jwt_token(tenant.id)
    conn = put_req_header(conn, "authorization", "Bearer #{token}")

    campaign = insert(:campaign, tenant: tenant)
    challenge = insert(:challenge)

    {:ok, conn: conn, tenant: tenant, campaign: campaign, challenge: challenge}
  end

  @doc """
  **Property 10: Campaign Challenge Response Schema**

  For any campaign challenge retrieved or created, the response should include
  all required fields with correct types.

  **Validates: Requirements 4.1, 4.2, 4.3, 4.4, 9.4**
  """
  property "campaign challenge responses include all required fields", %{
    conn: conn,
    campaign: campaign
  } do
    check all display_name <- string(:alphanumeric, min_length: 3, max_length: 50),
              reward_points <- integer(-1000..1000),
              frequency <- member_of(["daily", "weekly", "monthly", "on_event"]) do
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

  property "successful campaign challenge deletion returns HTTP 204 No Content", %{
    conn: conn,
    tenant: tenant,
    campaign: campaign,
    challenge: challenge
  } do
    check all display_name <- string(:alphanumeric, min_length: 3, max_length: 50) do
      cc = insert(:campaign_challenge, campaign: campaign, challenge: challenge, display_name: display_name)
      conn = delete(conn, ~p"/api/campaigns/#{campaign.id}/challenges/#{cc.id}")
      assert response(conn, 204) == ""
      assert CampaignManagement.get_campaign_challenge(tenant.id, campaign.id, cc.id) == nil
    end
  end

  property "validation errors return structured JSON with 422 status", %{
    conn: conn,
    campaign: campaign,
    challenge: challenge
  } do
    check all display_name <- string(:alphanumeric, min_length: 0, max_length: 2) do
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

  property "invalid evaluation frequency returns structured JSON with 422 status", %{
    conn: conn,
    campaign: campaign,
    challenge: challenge
  } do
    check all invalid_frequency <- string(:alphanumeric, min_length: 1, max_length: 20),
              invalid_frequency not in ["daily", "weekly", "monthly", "on_event"] do
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

  property "404 errors return structured JSON", %{conn: conn, campaign: campaign} do
    check all _iteration <- integer(1..10) do
      fake_id = Ecto.UUID.generate()
      conn = get(conn, ~p"/api/campaigns/#{campaign.id}/challenges/#{fake_id}")
      assert %{"error" => error_message} = json_response(conn, 404)
      assert is_binary(error_message)
      assert error_message == "Campaign challenge not found"
    end
  end

  property "reward points can be positive, negative, or zero", %{
    conn: conn,
    campaign: campaign
  } do
    check all reward_points <- integer(-10_000..10_000) do
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

  property "cron expressions with 5 parts are accepted", %{
    conn: conn,
    campaign: campaign
  } do
    check all part1 <- string(:alphanumeric, min_length: 1, max_length: 2),
              part2 <- string(:alphanumeric, min_length: 1, max_length: 2),
              part3 <- string(:alphanumeric, min_length: 1, max_length: 2),
              part4 <- string(:alphanumeric, min_length: 1, max_length: 2),
              part5 <- string(:alphanumeric, min_length: 1, max_length: 2) do
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
