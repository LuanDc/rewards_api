defmodule CampaignsApiWeb.CampaignControllerPropertyTest do
  use CampaignsApiWeb.ConnCase, async: true
  use ExUnitProperties

  alias CampaignsApi.CampaignManagement
  alias CampaignsApi.Tenants

  setup %{conn: conn} do
    # Create an active tenant for testing
    tenant_id = "test-tenant-#{System.unique_integer([:positive])}"
    {:ok, tenant} = Tenants.create_tenant(tenant_id)

    # Create a JWT token for authentication
    token = create_jwt_token(%{"tenant_id" => tenant_id})

    # Add authorization header to conn
    conn = put_req_header(conn, "authorization", "Bearer #{token}")

    {:ok, conn: conn, tenant: tenant}
  end

  # Helper function to create a JWT token for testing
  defp create_jwt_token(claims) do
    header = %{"alg" => "HS256", "typ" => "JWT"}

    encoded_header = header |> Jason.encode!() |> Base.url_encode64(padding: false)
    encoded_payload = claims |> Jason.encode!() |> Base.url_encode64(padding: false)

    signature = "dummy_signature"

    "#{encoded_header}.#{encoded_payload}.#{signature}"
  end

  # Property 23: Successful Deletion Response
  # **Validates: Requirements 7.4**
  property "successful campaign deletion returns HTTP 204 No Content", %{conn: conn, tenant: tenant} do
    check all name <- string(:alphanumeric, min_length: 3, max_length: 50) do
      # Create a campaign
      {:ok, campaign} = CampaignManagement.create_campaign(tenant.id, %{name: name})

      # Delete the campaign
      conn = delete(conn, ~p"/api/campaigns/#{campaign.id}")

      # Verify 204 response
      assert response(conn, 204) == ""

      # Verify campaign is actually deleted
      assert CampaignManagement.get_campaign(tenant.id, campaign.id) == nil
    end
  end

  # Property 24: Foreign Key Constraint Enforcement
  # **Validates: Requirements 8.3, 8.4**
  test "creating campaign with non-existent tenant_id fails with constraint error" do
    # This test verifies the database constraint, not the controller
    # The controller always uses the authenticated tenant_id
    fake_tenant_id = "non-existent-tenant-#{System.unique_integer([:positive])}"

    # Attempt to create campaign directly in the context (bypassing controller)
    result = CampaignManagement.create_campaign(fake_tenant_id, %{name: "Test Campaign"})

    # Should fail with foreign key constraint error
    assert {:error, changeset} = result
    assert changeset.errors[:tenant_id] != nil
  end

  # Property 25: Structured Error Responses
  # **Validates: Requirements 11.1, 11.6**
  property "validation errors return structured JSON with 422 status", %{conn: conn} do
    check all name <- string(:alphanumeric, min_length: 0, max_length: 2) do
      # Create campaign with invalid name (too short)
      conn = post(conn, ~p"/api/campaigns", %{"name" => name})

      # Verify 422 response with structured errors
      assert %{"errors" => errors} = json_response(conn, 422)
      assert is_map(errors)
      assert Map.has_key?(errors, "name")
    end
  end

  property "date validation errors return structured JSON with 422 status", %{conn: conn} do
    check all start_offset <- integer(1..100),
              end_offset <- integer(-100..-1) do
      # Create dates where start is after end
      now = DateTime.utc_now()
      start_time = DateTime.add(now, start_offset, :second) |> DateTime.to_iso8601()
      end_time = DateTime.add(now, end_offset, :second) |> DateTime.to_iso8601()

      conn =
        post(conn, ~p"/api/campaigns", %{
          "name" => "Invalid Campaign",
          "start_time" => start_time,
          "end_time" => end_time
        })

      # Verify 422 response with structured errors
      assert %{"errors" => errors} = json_response(conn, 422)
      assert is_map(errors)
      assert Map.has_key?(errors, "start_time")
    end
  end

  property "404 errors return structured JSON", %{conn: conn} do
    check all _iteration <- integer(1..10) do
      # Try to get a non-existent campaign
      fake_id = Ecto.UUID.generate()
      conn = get(conn, ~p"/api/campaigns/#{fake_id}")

      # Verify 404 response with structured error
      assert %{"error" => error_message} = json_response(conn, 404)
      assert is_binary(error_message)
      assert error_message == "Campaign not found"
    end
  end
end
