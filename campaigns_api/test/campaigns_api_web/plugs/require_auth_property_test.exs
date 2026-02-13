defmodule CampaignsApiWeb.Plugs.RequireAuthPropertyTest do
  use CampaignsApiWeb.ConnCase, async: true
  use ExUnitProperties

  alias CampaignsApiWeb.Plugs.RequireAuth

  describe "RequireAuth plug property tests" do
    # Feature: campaign-management-api, Property 1: JWT Tenant ID Extraction
    # **Validates: Requirements 1.1**
    property "extracts tenant_id from any valid JWT containing tenant_id claim" do
      check all tenant_id <- tenant_id_generator(),
                additional_claims <- optional_claims_generator(),
                max_runs: 100 do
        # Create JWT with tenant_id and optional additional claims
        claims = Map.put(additional_claims, "tenant_id", tenant_id)
        token = create_jwt_token(claims)

        # Create a fresh connection and call the plug
        conn =
          build_conn()
          |> put_req_header("authorization", "Bearer #{token}")
          |> RequireAuth.call(%{})

        # Property: The plug should successfully extract the tenant_id
        assert conn.assigns.tenant_id == tenant_id
        refute conn.halted
      end
    end
  end

  # StreamData Generators

  defp tenant_id_generator do
    one_of([
      # Alphanumeric tenant IDs
      string(:alphanumeric, min_length: 1, max_length: 50),
      # UUID-style tenant IDs
      map(
        {string(:alphanumeric, length: 8), string(:alphanumeric, length: 4),
         string(:alphanumeric, length: 4), string(:alphanumeric, length: 4),
         string(:alphanumeric, length: 12)},
        fn {a, b, c, d, e} -> "#{a}-#{b}-#{c}-#{d}-#{e}" end
      ),
      # Tenant IDs with hyphens and underscores
      map(
        list_of(string(:alphanumeric, min_length: 1, max_length: 10), min_length: 1, max_length: 5),
        fn parts -> Enum.join(parts, "-") end
      ),
      # Simple numeric tenant IDs
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
