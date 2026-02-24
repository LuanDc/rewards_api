defmodule CampaignsApiWeb.Plugs.RequireAuthTest do
  use CampaignsApiWeb.ConnCase, async: true
  use ExUnitProperties

  alias CampaignsApiWeb.Plugs.RequireAuth

  describe "RequireAuth plug" do
    test "extracts tenant_id from valid JWT with tenant_id claim", %{conn: conn} do
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

  describe "property-based tests" do
    @tag :property
    property "extracts tenant_id from any valid JWT containing tenant_id claim" do
      check all(
              tenant_id <- tenant_id_generator(),
              additional_claims <- optional_claims_generator(),
              max_runs: 30
            ) do
        claims = Map.put(additional_claims, "tenant_id", tenant_id)
        token = create_jwt_token(claims)

        conn =
          build_conn()
          |> put_req_header("authorization", "Bearer #{token}")
          |> RequireAuth.call(%{})

        assert conn.assigns.tenant_id == tenant_id
        refute conn.halted
      end
    end
  end

  defp tenant_id_generator do
    one_of([
      string(:alphanumeric, min_length: 1, max_length: 50),
      map(
        {string(:alphanumeric, length: 8), string(:alphanumeric, length: 4),
         string(:alphanumeric, length: 4), string(:alphanumeric, length: 4),
         string(:alphanumeric, length: 12)},
        fn {a, b, c, d, e} -> "#{a}-#{b}-#{c}-#{d}-#{e}" end
      ),
      map(
        list_of(string(:alphanumeric, min_length: 1, max_length: 10),
          min_length: 1,
          max_length: 5
        ),
        fn parts -> Enum.join(parts, "-") end
      ),
      map(positive_integer(), &to_string/1)
    ])
  end

  defp optional_claims_generator do
    map(
      {optional_string_claim("name"), optional_string_claim("email"),
       optional_string_claim("sub"), optional_integer_claim("exp"),
       optional_integer_claim("iat")},
      fn {name, email, sub, exp, iat} ->
        [name, email, sub, exp, iat]
        |> Enum.reject(&is_nil/1)
        |> Map.new()
      end
    )
  end

  defp optional_string_claim(key) do
    one_of([
      constant(nil),
      map(string(:alphanumeric, min_length: 1, max_length: 30), fn value ->
        {key, value}
      end)
    ])
  end

  defp optional_integer_claim(key) do
    one_of([
      constant(nil),
      map(positive_integer(), fn value ->
        {key, value}
      end)
    ])
  end

  defp create_jwt_token(claims) do
    header = %{"alg" => "HS256", "typ" => "JWT"}

    encoded_header = header |> Jason.encode!() |> Base.url_encode64(padding: false)
    encoded_payload = claims |> Jason.encode!() |> Base.url_encode64(padding: false)

    signature = "dummy_signature"

    "#{encoded_header}.#{encoded_payload}.#{signature}"
  end
end
