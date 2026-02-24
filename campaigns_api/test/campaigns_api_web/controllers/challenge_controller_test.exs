defmodule CampaignsApiWeb.ChallengeControllerTest do
  use CampaignsApiWeb.ConnCase, async: true

  setup %{conn: conn} do
    tenant = insert(:tenant)
    token = jwt_token(tenant.id)
    conn = put_req_header(conn, "authorization", "Bearer #{token}")

    {:ok, conn: conn, tenant: tenant}
  end

  describe "GET /api/challenges (index)" do
    test "returns empty list when no challenges exist", %{conn: conn} do
      conn = get(conn, ~p"/api/challenges")

      assert %{"data" => [], "has_more" => false, "next_cursor" => nil} = json_response(conn, 200)
    end

    test "returns all challenges with complete data", %{conn: conn} do
      insert(:challenge)
      insert(:challenge)

      conn = get(conn, ~p"/api/challenges")

      assert %{"data" => challenges, "has_more" => false} = json_response(conn, 200)
      assert length(challenges) == 2

      # Verify all required fields are present
      for challenge_data <- challenges do
        assert Map.has_key?(challenge_data, "id")
        assert Map.has_key?(challenge_data, "name")
        assert Map.has_key?(challenge_data, "description")
        assert Map.has_key?(challenge_data, "metadata")
        assert Map.has_key?(challenge_data, "inserted_at")
        assert Map.has_key?(challenge_data, "updated_at")
      end
    end

    test "returns challenges ordered by inserted_at descending", %{conn: conn} do
      # Insert challenges - they will be ordered by inserted_at desc (newest first)
      insert_list(3, :challenge)

      conn = get(conn, ~p"/api/challenges")

      assert %{"data" => challenges} = json_response(conn, 200)
      assert length(challenges) == 3

      # Verify descending order by checking timestamps
      timestamps =
        Enum.map(challenges, fn c ->
          {:ok, dt, _} = DateTime.from_iso8601(c["inserted_at"])
          dt
        end)

      # Each timestamp should be >= the next one (descending order)
      assert timestamps == Enum.sort(timestamps, {:desc, DateTime})
    end

    test "supports pagination with limit parameter", %{conn: conn} do
      insert_list(3, :challenge)

      conn = get(conn, ~p"/api/challenges?limit=2")

      assert %{"data" => challenges, "has_more" => true, "next_cursor" => cursor} =
               json_response(conn, 200)

      assert length(challenges) == 2
      assert cursor != nil
    end

    test "supports pagination with cursor parameter", %{conn: conn} do
      # Insert challenges
      insert_list(5, :challenge)

      # Get first page with limit
      conn1 = get(conn, ~p"/api/challenges?limit=2")
      response1 = json_response(conn1, 200)

      assert %{"data" => page1, "next_cursor" => cursor, "has_more" => has_more1} = response1
      assert length(page1) == 2

      # If there are more results, cursor should be present
      if has_more1 do
        assert cursor != nil

        # Get second page using cursor
        conn2 = get(conn, ~p"/api/challenges?cursor=#{cursor}")
        response2 = json_response(conn2, 200)

        assert %{"data" => page2} = response2

        # Verify no overlap between pages
        page1_ids = Enum.map(page1, & &1["id"])
        page2_ids = Enum.map(page2, & &1["id"])
        assert MapSet.disjoint?(MapSet.new(page1_ids), MapSet.new(page2_ids))
      end
    end

    test "handles missing limit parameter gracefully", %{conn: conn} do
      insert_list(2, :challenge)

      conn = get(conn, ~p"/api/challenges")

      assert %{"data" => challenges} = json_response(conn, 200)
      assert length(challenges) == 2
    end

    test "handles empty limit parameter gracefully", %{conn: conn} do
      insert_list(2, :challenge)

      conn = get(conn, ~p"/api/challenges?limit=")

      assert %{"data" => challenges} = json_response(conn, 200)
      assert length(challenges) == 2
    end

    test "handles invalid limit parameter gracefully", %{conn: conn} do
      insert_list(2, :challenge)

      conn = get(conn, ~p"/api/challenges?limit=invalid")

      assert %{"data" => challenges} = json_response(conn, 200)
      assert length(challenges) == 2
    end

    test "handles missing cursor parameter gracefully", %{conn: conn} do
      insert_list(2, :challenge)

      conn = get(conn, ~p"/api/challenges")

      assert %{"data" => challenges} = json_response(conn, 200)
      assert length(challenges) == 2
    end

    test "handles empty cursor parameter gracefully", %{conn: conn} do
      insert_list(2, :challenge)

      conn = get(conn, ~p"/api/challenges?cursor=")

      assert %{"data" => challenges} = json_response(conn, 200)
      assert length(challenges) == 2
    end

    test "handles invalid cursor parameter gracefully", %{conn: conn} do
      insert_list(2, :challenge)

      conn = get(conn, ~p"/api/challenges?cursor=invalid")

      assert %{"data" => challenges} = json_response(conn, 200)
      assert length(challenges) == 2
    end

    test "all tenants see the same challenges (global availability)", %{conn: conn} do
      # Create challenges
      insert(:challenge)
      insert(:challenge)

      # First tenant request
      conn1 = get(conn, ~p"/api/challenges")
      response1 = json_response(conn1, 200)

      # Second tenant request
      tenant2 = insert(:tenant)
      token2 = jwt_token(tenant2.id)

      conn2 =
        build_conn()
        |> put_req_header("authorization", "Bearer #{token2}")
        |> get(~p"/api/challenges")

      response2 = json_response(conn2, 200)

      # Both tenants should see the same challenges
      ids1 = Enum.map(response1["data"], & &1["id"]) |> Enum.sort()
      ids2 = Enum.map(response2["data"], & &1["id"]) |> Enum.sort()

      assert ids1 == ids2
      assert length(ids1) == 2
    end

    test "returns proper JSON structure", %{conn: conn} do
      insert(:challenge)

      conn = get(conn, ~p"/api/challenges")

      response = json_response(conn, 200)

      assert Map.has_key?(response, "data")
      assert Map.has_key?(response, "has_more")
      assert Map.has_key?(response, "next_cursor")
      assert is_list(response["data"])
      assert is_boolean(response["has_more"])
    end
  end

  describe "GET /api/challenges/:id (show)" do
    test "returns challenge when it exists", %{conn: conn} do
      challenge = insert(:challenge)

      conn = get(conn, ~p"/api/challenges/#{challenge.id}")

      assert %{
               "id" => id,
               "name" => name,
               "description" => description,
               "metadata" => metadata,
               "inserted_at" => _inserted_at,
               "updated_at" => _updated_at
             } = json_response(conn, 200)

      assert id == challenge.id
      assert name == challenge.name
      assert description == challenge.description
      assert metadata == challenge.metadata
    end

    test "returns 404 when challenge does not exist", %{conn: conn} do
      fake_id = Ecto.UUID.generate()
      conn = get(conn, ~p"/api/challenges/#{fake_id}")

      assert %{"error" => "Challenge not found"} = json_response(conn, 404)
    end

    test "all tenants can access the same challenge (global availability)", %{conn: conn} do
      challenge = insert(:challenge)

      # First tenant request
      conn1 = get(conn, ~p"/api/challenges/#{challenge.id}")
      response1 = json_response(conn1, 200)

      # Second tenant request
      tenant2 = insert(:tenant)
      token2 = jwt_token(tenant2.id)

      conn2 =
        build_conn()
        |> put_req_header("authorization", "Bearer #{token2}")
        |> get(~p"/api/challenges/#{challenge.id}")

      response2 = json_response(conn2, 200)

      # Both tenants should see the same challenge
      assert response1["id"] == response2["id"]
      assert response1["name"] == response2["name"]
    end

    test "returns complete challenge data structure", %{conn: conn} do
      challenge = insert(:challenge)

      conn = get(conn, ~p"/api/challenges/#{challenge.id}")

      response = json_response(conn, 200)

      # Verify all required fields are present
      assert Map.has_key?(response, "id")
      assert Map.has_key?(response, "name")
      assert Map.has_key?(response, "description")
      assert Map.has_key?(response, "metadata")
      assert Map.has_key?(response, "inserted_at")
      assert Map.has_key?(response, "updated_at")
    end
  end

  describe "POST /api/challenges (create - not exposed)" do
    test "returns 404 or 405 for POST endpoint", %{conn: conn} do
      params = %{
        "name" => "Test Challenge",
        "description" => "Should not be created"
      }

      conn = post(conn, ~p"/api/challenges", params)

      assert conn.status in [404, 405]
    end
  end

  describe "PUT /api/challenges/:id (update - not exposed)" do
    test "returns 404 or 405 for PUT endpoint", %{conn: conn} do
      challenge = insert(:challenge)

      params = %{
        "name" => "Updated Name"
      }

      conn = put(conn, ~p"/api/challenges/#{challenge.id}", params)

      assert conn.status in [404, 405]
    end
  end

  describe "PATCH /api/challenges/:id (update - not exposed)" do
    test "returns 404 or 405 for PATCH endpoint", %{conn: conn} do
      challenge = insert(:challenge)

      params = %{
        "name" => "Updated Name"
      }

      conn = patch(conn, ~p"/api/challenges/#{challenge.id}", params)

      assert conn.status in [404, 405]
    end
  end

  describe "DELETE /api/challenges/:id (delete - not exposed)" do
    test "returns 404 or 405 for DELETE endpoint", %{conn: conn} do
      challenge = insert(:challenge)

      conn = delete(conn, ~p"/api/challenges/#{challenge.id}")

      assert conn.status in [404, 405]
    end
  end

  describe "Error response format" do
    test "404 errors return structured JSON", %{conn: conn} do
      fake_id = Ecto.UUID.generate()
      conn = get(conn, ~p"/api/challenges/#{fake_id}")

      response = json_response(conn, 404)

      assert Map.has_key?(response, "error")
      assert is_binary(response["error"])
    end

    test "401 errors return structured JSON when not authenticated" do
      conn = build_conn() |> get(~p"/api/challenges")

      assert conn.status in [401, 403]
      response = json_response(conn, conn.status)

      assert Map.has_key?(response, "error")
      assert is_binary(response["error"])
    end

    test "403 errors return structured JSON for suspended tenants" do
      suspended_tenant = insert(:suspended_tenant)
      token = jwt_token(suspended_tenant.id)

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/challenges")

      assert conn.status == 403
      response = json_response(conn, 403)

      assert Map.has_key?(response, "error")
      assert is_binary(response["error"])
    end

    test "error responses contain only error field" do
      fake_id = Ecto.UUID.generate()
      tenant = insert(:tenant)
      token = jwt_token(tenant.id)

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/challenges/#{fake_id}")

      response = json_response(conn, 404)

      assert Map.keys(response) == ["error"]
    end
  end
end
