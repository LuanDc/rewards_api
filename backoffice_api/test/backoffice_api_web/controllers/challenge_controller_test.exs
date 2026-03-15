defmodule BackofficeApiWeb.ChallengeControllerTest do
  use BackofficeApiWeb.ConnCase, async: true

  alias BackofficeApi.ChallengeManagement

  describe "create challenge" do
    test "creates challenge and returns 201", %{conn: conn} do
      params = %{
        "name" => "DeviceMatcher",
        "description" => "Evaluates known-device signal",
        "metadata" => %{"source" => "device_graph"}
      }

      conn = post(conn, ~p"/api/challenges", params)

      assert %{
               "id" => id,
               "external_id" => external_id,
               "name" => "DeviceMatcher",
               "description" => "Evaluates known-device signal",
               "metadata" => %{"source" => "device_graph"}
             } = json_response(conn, 201)

      assert is_binary(id)
      assert is_binary(external_id)
    end

    test "returns 422 for invalid payload", %{conn: conn} do
      conn = post(conn, ~p"/api/challenges", %{"name" => "ab"})

      assert %{"errors" => %{"name" => [_ | _]}} = json_response(conn, 422)
    end
  end

  describe "challenge CRUD" do
    test "index, show, update and delete", %{conn: conn} do
      assert {:ok, challenge} =
               ChallengeManagement.create_challenge(%{
                 "name" => "RiskScore",
                 "description" => "Initial",
                 "metadata" => %{"rule" => "r1"}
               })

      index_conn = get(conn, ~p"/api/challenges")
      assert %{"data" => [first | _]} = json_response(index_conn, 200)
      assert first["id"] == challenge.id

      show_conn = get(conn, ~p"/api/challenges/#{challenge.id}")
      assert %{"id" => id, "name" => "RiskScore"} = json_response(show_conn, 200)
      assert id == challenge.id

      update_conn =
        put(conn, ~p"/api/challenges/#{challenge.id}", %{
          "name" => "RiskScoreUpdated",
          "metadata" => %{"rule" => "r2"}
        })

      assert %{"name" => "RiskScoreUpdated", "metadata" => %{"rule" => "r2"}} =
               json_response(update_conn, 200)

      delete_conn = delete(conn, ~p"/api/challenges/#{challenge.id}")
      assert response(delete_conn, 204)

      get_missing_conn = get(conn, ~p"/api/challenges/#{challenge.id}")
      assert %{"error" => "Challenge not found"} = json_response(get_missing_conn, 404)
    end
  end
end
