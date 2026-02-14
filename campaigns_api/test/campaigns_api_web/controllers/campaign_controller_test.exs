defmodule CampaignsApiWeb.CampaignControllerTest do
  use CampaignsApiWeb.ConnCase, async: true

  alias CampaignsApi.CampaignManagement

  setup %{conn: conn} do
    tenant = insert(:tenant)
    token = jwt_token(tenant.id)
    conn = put_req_header(conn, "authorization", "Bearer #{token}")

    {:ok, conn: conn, tenant: tenant}
  end

  describe "POST /api/campaigns (create)" do
    test "creates campaign with valid data", %{conn: conn, tenant: tenant} do
      params = %{
        "name" => "Summer Sale Campaign",
        "description" => "A great summer promotion",
        "status" => "active"
      }

      conn = post(conn, ~p"/api/campaigns", params)

      assert %{
               "id" => _id,
               "tenant_id" => tenant_id,
               "name" => "Summer Sale Campaign",
               "description" => "A great summer promotion",
               "status" => "active",
               "start_time" => nil,
               "end_time" => nil
             } = json_response(conn, 201)

      assert tenant_id == tenant.id
    end

    test "creates campaign with all date combinations", %{conn: conn} do
      # No dates
      conn1 = post(conn, ~p"/api/campaigns", %{"name" => "Campaign 1"})
      assert json_response(conn1, 201)["start_time"] == nil
      assert json_response(conn1, 201)["end_time"] == nil

      # Start time only
      start_time = DateTime.utc_now() |> DateTime.to_iso8601()
      conn2 = post(conn, ~p"/api/campaigns", %{"name" => "Campaign 2", "start_time" => start_time})
      assert json_response(conn2, 201)["start_time"] != nil
      assert json_response(conn2, 201)["end_time"] == nil

      # End time only
      end_time = DateTime.utc_now() |> DateTime.add(86_400, :second) |> DateTime.to_iso8601()
      conn3 = post(conn, ~p"/api/campaigns", %{"name" => "Campaign 3", "end_time" => end_time})
      assert json_response(conn3, 201)["start_time"] == nil
      assert json_response(conn3, 201)["end_time"] != nil

      # Both dates
      conn4 =
        post(conn, ~p"/api/campaigns", %{
          "name" => "Campaign 4",
          "start_time" => start_time,
          "end_time" => end_time
        })

      assert json_response(conn4, 201)["start_time"] != nil
      assert json_response(conn4, 201)["end_time"] != nil
    end

    test "returns 422 with validation errors for invalid data", %{conn: conn} do
      # Name too short
      conn = post(conn, ~p"/api/campaigns", %{"name" => "ab"})

      assert %{"errors" => errors} = json_response(conn, 422)
      assert Map.has_key?(errors, "name")
    end

    test "returns 422 when start_time is after end_time", %{conn: conn} do
      start_time = DateTime.utc_now() |> DateTime.add(86_400, :second) |> DateTime.to_iso8601()
      end_time = DateTime.utc_now() |> DateTime.to_iso8601()

      conn =
        post(conn, ~p"/api/campaigns", %{
          "name" => "Invalid Campaign",
          "start_time" => start_time,
          "end_time" => end_time
        })

      assert %{"errors" => errors} = json_response(conn, 422)
      assert Map.has_key?(errors, "start_time")
    end
  end

  describe "GET /api/campaigns (index)" do
    test "returns empty list when no campaigns exist", %{conn: conn} do
      conn = get(conn, ~p"/api/campaigns")

      assert %{"data" => [], "has_more" => false, "next_cursor" => nil} = json_response(conn, 200)
    end

    test "returns campaigns for the tenant", %{conn: conn, tenant: tenant} do
      insert_list(2, :campaign, tenant: tenant)

      conn = get(conn, ~p"/api/campaigns")

      assert %{"data" => campaigns, "has_more" => false} = json_response(conn, 200)
      assert length(campaigns) == 2
    end

    test "supports pagination with limit parameter", %{conn: conn, tenant: tenant} do
      insert_list(3, :campaign, tenant: tenant)

      conn = get(conn, ~p"/api/campaigns?limit=2")

      assert %{"data" => campaigns, "has_more" => true, "next_cursor" => cursor} =
               json_response(conn, 200)

      assert length(campaigns) == 2
      assert cursor != nil
    end

    test "supports pagination with cursor parameter", %{conn: conn, tenant: tenant} do
      insert_list(3, :campaign, tenant: tenant)

      conn1 = get(conn, ~p"/api/campaigns?limit=2")
      response1 = json_response(conn1, 200)

      assert %{"data" => page1, "next_cursor" => cursor, "has_more" => true} = response1
      assert length(page1) == 2
      assert cursor != nil

      conn2 = get(conn, ~p"/api/campaigns?cursor=#{cursor}")
      response2 = json_response(conn2, 200)

      assert %{"data" => _page2} = response2
    end

    test "does not return campaigns from other tenants", %{conn: conn, tenant: tenant} do
      my_campaign = insert(:campaign, tenant: tenant)
      other_tenant = insert(:tenant)
      insert(:campaign, tenant: other_tenant)

      conn = get(conn, ~p"/api/campaigns")

      assert %{"data" => campaigns} = json_response(conn, 200)
      assert length(campaigns) == 1
      assert hd(campaigns)["name"] == my_campaign.name
    end

    test "handles missing limit parameter gracefully", %{conn: conn, tenant: tenant} do
      insert_list(2, :campaign, tenant: tenant)

      conn = get(conn, ~p"/api/campaigns")

      assert %{"data" => campaigns} = json_response(conn, 200)
      assert length(campaigns) == 2
    end

    test "handles empty limit parameter gracefully", %{conn: conn, tenant: tenant} do
      insert_list(2, :campaign, tenant: tenant)

      conn = get(conn, ~p"/api/campaigns?limit=")

      assert %{"data" => campaigns} = json_response(conn, 200)
      assert length(campaigns) == 2
    end

    test "handles invalid limit parameter gracefully", %{conn: conn, tenant: tenant} do
      insert_list(2, :campaign, tenant: tenant)

      conn = get(conn, ~p"/api/campaigns?limit=invalid")

      assert %{"data" => campaigns} = json_response(conn, 200)
      assert length(campaigns) == 2
    end

    test "handles missing cursor parameter gracefully", %{conn: conn, tenant: tenant} do
      insert_list(2, :campaign, tenant: tenant)

      conn = get(conn, ~p"/api/campaigns")

      assert %{"data" => campaigns} = json_response(conn, 200)
      assert length(campaigns) == 2
    end

    test "handles empty cursor parameter gracefully", %{conn: conn, tenant: tenant} do
      insert_list(2, :campaign, tenant: tenant)

      conn = get(conn, ~p"/api/campaigns?cursor=")

      assert %{"data" => campaigns} = json_response(conn, 200)
      assert length(campaigns) == 2
    end

    test "handles invalid cursor parameter gracefully", %{conn: conn, tenant: tenant} do
      insert_list(2, :campaign, tenant: tenant)

      conn = get(conn, ~p"/api/campaigns?cursor=invalid")

      assert %{"data" => campaigns} = json_response(conn, 200)
      assert length(campaigns) == 2
    end
  end

  describe "GET /api/campaigns/:id (show)" do
    test "returns campaign when it exists and belongs to tenant", %{conn: conn, tenant: tenant} do
      campaign = insert(:campaign, tenant: tenant)

      conn = get(conn, ~p"/api/campaigns/#{campaign.id}")

      assert %{
               "id" => id,
               "name" => name,
               "tenant_id" => tenant_id
             } = json_response(conn, 200)

      assert id == campaign.id
      assert name == campaign.name
      assert tenant_id == tenant.id
    end

    test "returns 404 when campaign does not exist", %{conn: conn} do
      fake_id = Ecto.UUID.generate()
      conn = get(conn, ~p"/api/campaigns/#{fake_id}")

      assert %{"error" => "Campaign not found"} = json_response(conn, 404)
    end

    test "returns 404 when campaign belongs to different tenant", %{conn: conn} do
      other_tenant = insert(:tenant)
      other_campaign = insert(:campaign, tenant: other_tenant)

      conn = get(conn, ~p"/api/campaigns/#{other_campaign.id}")

      assert %{"error" => "Campaign not found"} = json_response(conn, 404)
    end
  end

  describe "PUT /api/campaigns/:id (update)" do
    test "updates campaign with valid data", %{conn: conn, tenant: tenant} do
      campaign = insert(:campaign, tenant: tenant)

      update_params = %{
        "name" => "Updated Name",
        "description" => "New description",
        "status" => "paused"
      }

      conn = put(conn, ~p"/api/campaigns/#{campaign.id}", update_params)

      assert %{
               "id" => id,
               "name" => "Updated Name",
               "description" => "New description",
               "status" => "paused"
             } = json_response(conn, 200)

      assert id == campaign.id
    end

    test "returns 422 with validation errors for invalid data", %{conn: conn, tenant: tenant} do
      campaign = insert(:campaign, tenant: tenant)

      conn = put(conn, ~p"/api/campaigns/#{campaign.id}", %{name: "ab"})

      assert %{"errors" => errors} = json_response(conn, 422)
      assert Map.has_key?(errors, "name")
    end

    test "returns 404 when campaign does not exist", %{conn: conn} do
      fake_id = Ecto.UUID.generate()
      conn = put(conn, ~p"/api/campaigns/#{fake_id}", %{name: "Updated"})

      assert %{"error" => "Campaign not found"} = json_response(conn, 404)
    end

    test "returns 404 when campaign belongs to different tenant", %{conn: conn} do
      other_tenant = insert(:tenant)
      other_campaign = insert(:campaign, tenant: other_tenant)

      conn = put(conn, ~p"/api/campaigns/#{other_campaign.id}", %{name: "Hacked"})

      assert %{"error" => "Campaign not found"} = json_response(conn, 404)
    end
  end

  describe "DELETE /api/campaigns/:id (delete)" do
    test "deletes campaign successfully", %{conn: conn, tenant: tenant} do
      campaign = insert(:campaign, tenant: tenant)

      conn = delete(conn, ~p"/api/campaigns/#{campaign.id}")

      assert response(conn, 204) == ""
      assert CampaignManagement.get_campaign(tenant.id, campaign.id) == nil
    end

    test "returns 404 when campaign does not exist", %{conn: conn} do
      fake_id = Ecto.UUID.generate()
      conn = delete(conn, ~p"/api/campaigns/#{fake_id}")

      assert %{"error" => "Campaign not found"} = json_response(conn, 404)
    end

    test "returns 404 when campaign belongs to different tenant", %{conn: conn} do
      other_tenant = insert(:tenant)
      other_campaign = insert(:campaign, tenant: other_tenant)

      conn = delete(conn, ~p"/api/campaigns/#{other_campaign.id}")

      assert %{"error" => "Campaign not found"} = json_response(conn, 404)
    end
  end
end
