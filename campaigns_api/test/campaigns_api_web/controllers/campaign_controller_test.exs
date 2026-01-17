defmodule CampaignsApiWeb.CampaignControllerTest do
  use CampaignsApiWeb.ConnCase

  alias CampaignsApi.Campaigns.Campaign

  @tenant "tenant-abc123"

  @create_attrs %{
    name: "Summer Campaign 2026",
    status: :not_started
  }

  @update_attrs %{
    name: "Updated Campaign Name",
    status: :active
  }

  @invalid_attrs %{name: nil}

  describe "index" do
    test "lists all campaigns for tenant", %{conn: conn} do
      conn = conn |> put_auth_header() |> get(~p"/api/campaigns")
      assert json_response(conn, 200)["data"] == []
    end

    test "returns 401 when authorization header is missing", %{conn: conn} do
      conn = get(conn, ~p"/api/campaigns")
      assert json_response(conn, 401)
    end
  end

  describe "create campaign" do
    test "renders campaign when data is valid", %{conn: conn} do
      conn = conn |> put_auth_header() |> post(~p"/api/campaigns", campaign: @create_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = build_conn() |> put_auth_header() |> get(~p"/api/campaigns/#{id}")

      assert %{
               "id" => ^id,
               "name" => "Summer Campaign 2026",
               "tenant" => @tenant,
               "status" => "not_started",
               "started_at" => nil,
               "finished_at" => nil
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = conn |> put_auth_header() |> post(~p"/api/campaigns", campaign: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end

    test "renders errors when name is too long", %{conn: conn} do
      long_name = String.duplicate("a", 256)
      attrs = %{@create_attrs | name: long_name}
      conn = conn |> put_auth_header() |> post(~p"/api/campaigns", campaign: attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end

    test "returns 401 when authorization header is missing", %{conn: conn} do
      conn = post(conn, ~p"/api/campaigns", campaign: @create_attrs)
      assert json_response(conn, 401)
    end
  end

  describe "update campaign" do
    setup [:create_campaign]

    test "renders campaign when data is valid", %{
      conn: conn,
      campaign: %Campaign{id: id}
    } do
      conn =
        conn |> put_auth_header() |> put(~p"/api/campaigns/#{id}", campaign: @update_attrs)

      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = build_conn() |> put_auth_header() |> get(~p"/api/campaigns/#{id}")

      assert %{
               "id" => ^id,
               "name" => "Updated Campaign Name",
               "status" => "active"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn, campaign: campaign} do
      conn =
        conn |> put_auth_header() |> put(~p"/api/campaigns/#{campaign}", campaign: @invalid_attrs)

      assert json_response(conn, 422)["errors"] != %{}
    end

    test "returns 404 when campaign does not exist for tenant", %{conn: conn} do
      non_existent_id = Uniq.UUID.uuid7()

      conn =
        conn
        |> put_auth_header()
        |> put(~p"/api/campaigns/#{non_existent_id}", campaign: @update_attrs)

      assert json_response(conn, 404)["errors"] != %{}
    end

    test "returns 401 when authorization header is missing", %{
      conn: conn,
      campaign: %Campaign{id: id}
    } do
      conn = conn |> put(~p"/api/campaigns/#{id}", campaign: @update_attrs)

      assert json_response(conn, 401)["errors"] != %{}
    end
  end

  describe "delete campaign" do
    setup [:create_campaign]

    test "deletes chosen campaign", %{conn: conn, campaign: %Campaign{id: id}} do
      conn = conn |> put_auth_header() |> delete(~p"/api/campaigns/#{id}")
      assert response(conn, 204)

      conn = build_conn() |> put_auth_header() |> get(~p"/api/campaigns/#{id}")

      assert json_response(conn, 404)["errors"] != %{}
    end

    test "returns 404 when campaign does not exist for tenant", %{conn: conn} do
      non_existent_id = Uniq.UUID.uuid7()
      conn = conn |> put_auth_header() |> delete(~p"/api/campaigns/#{non_existent_id}")

      assert json_response(conn, 404)["errors"] != %{}
    end

    test "returns 401 when authorization header is missing", %{
      conn: conn,
      campaign: %Campaign{id: id}
    } do
      conn = delete(conn, ~p"/api/campaigns/#{id}")

      assert json_response(conn, 401)["errors"] != %{}
    end
  end

  describe "start campaign" do
    setup [:create_campaign]

    test "starts a campaign and sets status to active", %{conn: conn, campaign: campaign} do
      conn = conn |> put_auth_header() |> post(~p"/api/campaigns/#{campaign.id}/start")

      assert %{"id" => id, "status" => "active", "started_at" => started_at} =
               json_response(conn, 200)["data"]

      assert id == campaign.id
      assert started_at != nil
    end

    test "returns 404 when campaign does not exist for tenant", %{conn: conn} do
      non_existent_id = Uniq.UUID.uuid7()
      conn = conn |> put_auth_header() |> post(~p"/api/campaigns/#{non_existent_id}/start")

      assert json_response(conn, 404)["errors"] != %{}
    end
  end

  describe "finish campaign" do
    setup [:create_campaign]

    test "finishes a campaign and sets status to completed", %{
      conn: conn,
      campaign: campaign
    } do
      conn = conn |> put_auth_header() |> post(~p"/api/campaigns/#{campaign.id}/finish")

      assert %{"id" => id, "status" => "completed", "finished_at" => finished_at} =
               json_response(conn, 200)["data"]

      assert id == campaign.id
      assert finished_at != nil
    end

    test "returns 404 when campaign does not exist for tenant", %{conn: conn} do
      non_existent_id = Uniq.UUID.uuid7()
      conn = conn |> put_auth_header() |> post(~p"/api/campaigns/#{non_existent_id}/finish")

      assert json_response(conn, 404)["errors"] != %{}
    end
  end

  defp create_campaign(_) do
    campaign = insert(:campaign, tenant: @tenant)
    %{campaign: campaign}
  end
end
