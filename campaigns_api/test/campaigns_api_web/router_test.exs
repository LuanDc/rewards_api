defmodule CampaignsApiWeb.RouterTest do
  use CampaignsApiWeb.ConnCase, async: true

  describe "router configuration" do
    test "campaigns routes are properly configured" do
      # Verify all expected routes exist
      assert %{route: "/api/campaigns"} =
               Phoenix.Router.route_info(CampaignsApiWeb.Router, "GET", "/api/campaigns", "")

      assert %{route: "/api/campaigns/:id"} =
               Phoenix.Router.route_info(CampaignsApiWeb.Router, "GET", "/api/campaigns/123", "")

      assert %{route: "/api/campaigns"} =
               Phoenix.Router.route_info(CampaignsApiWeb.Router, "POST", "/api/campaigns", "")

      assert %{route: "/api/campaigns/:id"} =
               Phoenix.Router.route_info(CampaignsApiWeb.Router, "PUT", "/api/campaigns/123", "")

      assert %{route: "/api/campaigns/:id"} =
               Phoenix.Router.route_info(
                 CampaignsApiWeb.Router,
                 "PATCH",
                 "/api/campaigns/123",
                 ""
               )

      assert %{route: "/api/campaigns/:id"} =
               Phoenix.Router.route_info(
                 CampaignsApiWeb.Router,
                 "DELETE",
                 "/api/campaigns/123",
                 ""
               )
    end

    test "campaign challenge routes are properly configured" do
      # Verify all expected nested routes exist
      assert %{route: "/api/campaigns/:campaign_id/challenges"} =
               Phoenix.Router.route_info(
                 CampaignsApiWeb.Router,
                 "GET",
                 "/api/campaigns/123/challenges",
                 ""
               )

      assert %{route: "/api/campaigns/:campaign_id/challenges/:id"} =
               Phoenix.Router.route_info(
                 CampaignsApiWeb.Router,
                 "GET",
                 "/api/campaigns/123/challenges/456",
                 ""
               )

      assert %{route: "/api/campaigns/:campaign_id/challenges"} =
               Phoenix.Router.route_info(
                 CampaignsApiWeb.Router,
                 "POST",
                 "/api/campaigns/123/challenges",
                 ""
               )

      assert %{route: "/api/campaigns/:campaign_id/challenges/:id"} =
               Phoenix.Router.route_info(
                 CampaignsApiWeb.Router,
                 "PUT",
                 "/api/campaigns/123/challenges/456",
                 ""
               )

      assert %{route: "/api/campaigns/:campaign_id/challenges/:id"} =
               Phoenix.Router.route_info(
                 CampaignsApiWeb.Router,
                 "PATCH",
                 "/api/campaigns/123/challenges/456",
                 ""
               )

      assert %{route: "/api/campaigns/:campaign_id/challenges/:id"} =
               Phoenix.Router.route_info(
                 CampaignsApiWeb.Router,
                 "DELETE",
                 "/api/campaigns/123/challenges/456",
                 ""
               )
    end

    test "campaigns routes use CampaignController" do
      route_info = Phoenix.Router.route_info(CampaignsApiWeb.Router, "GET", "/api/campaigns", "")
      assert route_info.plug == CampaignsApiWeb.CampaignController
    end

    test "campaign challenge routes use CampaignChallengeController" do
      route_info =
        Phoenix.Router.route_info(
          CampaignsApiWeb.Router,
          "GET",
          "/api/campaigns/123/challenges",
          ""
        )

      assert route_info.plug == CampaignsApiWeb.CampaignChallengeController
    end

    test "authenticated pipeline includes RequireAuth plug" do
      # Make a request without auth header to verify RequireAuth is applied
      conn =
        build_conn()
        |> put_req_header("accept", "application/json")
        |> get("/api/campaigns")

      assert conn.status == 401
      assert json_response(conn, 401) == %{"error" => "Unauthorized"}
    end

    test "campaign challenge routes require authentication" do
      # Make a request without auth header to verify RequireAuth is applied
      conn =
        build_conn()
        |> put_req_header("accept", "application/json")
        |> get("/api/campaigns/123/challenges")

      assert conn.status == 401
      assert json_response(conn, 401) == %{"error" => "Unauthorized"}
    end

    test "authenticated pipeline includes AssignTenant plug after RequireAuth" do
      # Create a valid JWT with tenant_id
      tenant_id = "test-tenant-#{System.unique_integer([:positive])}"
      claims = %{"tenant_id" => tenant_id}
      token = create_test_jwt(claims)

      # Make request with valid auth - should reach AssignTenant which creates tenant
      conn =
        build_conn()
        |> put_req_header("accept", "application/json")
        |> put_req_header("authorization", "Bearer #{token}")
        |> get("/api/campaigns")

      # Should succeed (200) with empty list, proving both plugs executed
      assert conn.status == 200

      assert json_response(conn, 200) == %{
               "data" => [],
               "has_more" => false,
               "next_cursor" => nil
             }
    end

    test "plugs are executed in correct order: RequireAuth then AssignTenant" do
      # Test that missing auth is caught by RequireAuth before AssignTenant
      conn =
        build_conn()
        |> put_req_header("accept", "application/json")
        |> get("/api/campaigns")

      # Should fail at RequireAuth with 401, not reach AssignTenant
      assert conn.status == 401
      assert json_response(conn, 401) == %{"error" => "Unauthorized"}
    end

    test "routes outside /api scope do not require authentication" do
      # Home page should be accessible without auth
      conn =
        build_conn()
        |> get("/")

      assert conn.status == 200
    end
  end

  # Helper to create test JWT tokens
  defp create_test_jwt(claims) do
    # Create a simple JWT structure without signature (mock implementation)
    header = %{"alg" => "none", "typ" => "JWT"}

    header_json = Jason.encode!(header)
    claims_json = Jason.encode!(claims)

    header_b64 = Base.url_encode64(header_json, padding: false)
    claims_b64 = Base.url_encode64(claims_json, padding: false)

    "#{header_b64}.#{claims_b64}."
  end
end
