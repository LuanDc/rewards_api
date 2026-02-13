defmodule CampaignsApiWeb.Plugs.RequireAuthTest do
  use CampaignsApiWeb.ConnCase, async: true

  alias CampaignsApiWeb.Plugs.RequireAuth

  describe "RequireAuth plug" do
    test "extracts tenant_id from valid JWT with tenant_id claim", %{conn: conn} do
      # Create a valid JWT token with tenant_id claim
      claims = %{"tenant_id" => "test-tenant-123", "name" => "Test Tenant"}
      token = create_jwt_token(claims)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> RequireAuth.call(%{})

      assert conn.assigns.tenant_id == "test-tenant-123"
      refute conn.halted
    end

    test "returns 401 when Authorization header is missing", %{conn: conn} do
      conn = RequireAuth.call(conn, %{})

      assert conn.status == 401
      assert conn.halted
      assert json_response(conn, 401) == %{"error" => "Unauthorized"}
    end

    test "returns 401 when JWT does not contain tenant_id claim", %{conn: conn} do
      # Create a JWT token without tenant_id claim
      claims = %{"user_id" => "user-123", "name" => "Test User"}
      token = create_jwt_token(claims)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> RequireAuth.call(%{})

      assert conn.status == 401
      assert conn.halted
      assert json_response(conn, 401) == %{"error" => "Unauthorized"}
    end

    test "returns 401 when JWT format is invalid", %{conn: conn} do
      # Use a malformed JWT token (not valid base64 encoded JSON)
      invalid_token = "eyJhbGciOiJIUzI1NiJ9.invalid_payload.signature"

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{invalid_token}")
        |> RequireAuth.call(%{})

      assert conn.status == 401
      assert conn.halted
      assert json_response(conn, 401) == %{"error" => "Unauthorized"}
    end

    test "returns 401 when Authorization header format is incorrect", %{conn: conn} do
      claims = %{"tenant_id" => "test-tenant-123"}
      token = create_jwt_token(claims)

      # Missing "Bearer " prefix
      conn =
        conn
        |> put_req_header("authorization", token)
        |> RequireAuth.call(%{})

      assert conn.status == 401
      assert conn.halted
      assert json_response(conn, 401) == %{"error" => "Unauthorized"}
    end

    test "returns 401 when token is empty string", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer ")
        |> RequireAuth.call(%{})

      assert conn.status == 401
      assert conn.halted
      assert json_response(conn, 401) == %{"error" => "Unauthorized"}
    end
  end

  # Helper function to create a JWT token for testing
  # This creates a properly formatted JWT without signature verification
  defp create_jwt_token(claims) do
    # Create a simple JWT structure: header.payload.signature
    # Since we're using Joken.peek_claims which doesn't verify, we just need valid structure
    header = %{"alg" => "HS256", "typ" => "JWT"}

    encoded_header = header |> Jason.encode!() |> Base.url_encode64(padding: false)
    encoded_payload = claims |> Jason.encode!() |> Base.url_encode64(padding: false)

    # Add a dummy signature (not verified in our mock implementation)
    signature = "dummy_signature"

    "#{encoded_header}.#{encoded_payload}.#{signature}"
  end
end
