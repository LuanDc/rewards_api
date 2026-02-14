defmodule CampaignsApiWeb.CampaignControllerPropertyTest do
  use CampaignsApiWeb.ConnCase, async: true
  use ExUnitProperties

  alias CampaignsApi.CampaignManagement

  setup %{conn: conn} do
    tenant = insert(:tenant)
    token = create_jwt_token(%{"tenant_id" => tenant.id})
    conn = put_req_header(conn, "authorization", "Bearer #{token}")

    {:ok, conn: conn, tenant: tenant}
  end

  defp create_jwt_token(claims) do
    header = %{"alg" => "HS256", "typ" => "JWT"}

    encoded_header = header |> Jason.encode!() |> Base.url_encode64(padding: false)
    encoded_payload = claims |> Jason.encode!() |> Base.url_encode64(padding: false)

    signature = "dummy_signature"

    "#{encoded_header}.#{encoded_payload}.#{signature}"
  end

  property "successful campaign deletion returns HTTP 204 No Content", %{conn: conn, tenant: tenant} do
    check all name <- string(:alphanumeric, min_length: 3, max_length: 50) do
      {:ok, campaign} = CampaignManagement.create_campaign(tenant.id, %{name: name})
      conn = delete(conn, ~p"/api/campaigns/#{campaign.id}")
      assert response(conn, 204) == ""
      assert CampaignManagement.get_campaign(tenant.id, campaign.id) == nil
    end
  end

  test "creating campaign with non-existent tenant_id fails with constraint error" do
    fake_tenant_id = "non-existent-tenant-#{System.unique_integer([:positive])}"
    result = CampaignManagement.create_campaign(fake_tenant_id, %{name: "Test Campaign"})
    assert {:error, changeset} = result
    assert changeset.errors[:tenant_id] != nil
  end

  property "validation errors return structured JSON with 422 status", %{conn: conn} do
    check all name <- string(:alphanumeric, min_length: 0, max_length: 2) do
      conn = post(conn, ~p"/api/campaigns", %{"name" => name})
      assert %{"errors" => errors} = json_response(conn, 422)
      assert is_map(errors)
      assert Map.has_key?(errors, "name")
    end
  end

  property "date validation errors return structured JSON with 422 status", %{conn: conn} do
    check all start_offset <- integer(1..100),
              end_offset <- integer(-100..-1) do
      now = DateTime.utc_now()
      start_time = DateTime.add(now, start_offset, :second) |> DateTime.to_iso8601()
      end_time = DateTime.add(now, end_offset, :second) |> DateTime.to_iso8601()

      conn =
        post(conn, ~p"/api/campaigns", %{
          "name" => "Invalid Campaign",
          "start_time" => start_time,
          "end_time" => end_time
        })

      assert %{"errors" => errors} = json_response(conn, 422)
      assert is_map(errors)
      assert Map.has_key?(errors, "start_time")
    end
  end

  property "404 errors return structured JSON", %{conn: conn} do
    check all _iteration <- integer(1..10) do
      fake_id = Ecto.UUID.generate()
      conn = get(conn, ~p"/api/campaigns/#{fake_id}")
      assert %{"error" => error_message} = json_response(conn, 404)
      assert is_binary(error_message)
      assert error_message == "Campaign not found"
    end
  end
end
