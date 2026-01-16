defmodule CampaignsApiWeb.CampaignControllerTest do
  use CampaignsApiWeb.ConnCase

  alias CampaignsApi.Campaigns.Campaign

  @create_attrs %{
    name: "Summer Campaign 2026",
    tenant: "tenant-abc123",
    status: :not_started
  }

  @update_attrs %{
    name: "Updated Campaign Name",
    status: :active
  }

  @invalid_attrs %{name: nil, tenant: nil}

  describe "index" do
    test "lists all campaigns", %{conn: conn} do
      conn = get(conn, ~p"/api/campaigns")
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create campaign" do
    test "renders campaign when data is valid", %{conn: conn} do
      conn = post(conn, ~p"/api/campaigns", campaign: @create_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, ~p"/api/campaigns/#{id}")

      assert %{
               "id" => ^id,
               "name" => "Summer Campaign 2026",
               "tenant" => "tenant-abc123",
               "status" => "not_started",
               "started_at" => nil,
               "finished_at" => nil
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/api/campaigns", campaign: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end

    test "renders errors when name is too long", %{conn: conn} do
      long_name = String.duplicate("a", 256)
      attrs = %{@create_attrs | name: long_name}
      conn = post(conn, ~p"/api/campaigns", campaign: attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end

    test "renders errors when tenant is too long", %{conn: conn} do
      long_tenant = String.duplicate("a", 101)
      attrs = %{@create_attrs | tenant: long_tenant}
      conn = post(conn, ~p"/api/campaigns", campaign: attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update campaign" do
    setup [:create_campaign]

    test "renders campaign when data is valid", %{
      conn: conn,
      campaign: %Campaign{id: id} = campaign
    } do
      conn = put(conn, ~p"/api/campaigns/#{campaign}", campaign: @update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get(conn, ~p"/api/campaigns/#{id}")

      assert %{
               "id" => ^id,
               "name" => "Updated Campaign Name",
               "status" => "active"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn, campaign: campaign} do
      conn = put(conn, ~p"/api/campaigns/#{campaign}", campaign: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete campaign" do
    setup [:create_campaign]

    test "deletes chosen campaign", %{conn: conn, campaign: campaign} do
      conn = delete(conn, ~p"/api/campaigns/#{campaign}")
      assert response(conn, 204)

      assert_error_sent(404, fn ->
        get(conn, ~p"/api/campaigns/#{campaign}")
      end)
    end
  end

  describe "start campaign" do
    setup [:create_campaign]

    test "starts a campaign and sets status to active", %{conn: conn, campaign: campaign} do
      conn = post(conn, ~p"/api/campaigns/#{campaign.id}/start")

      assert %{"id" => id, "status" => "active", "started_at" => started_at} =
               json_response(conn, 200)["data"]

      assert id == campaign.id
      assert started_at != nil
    end
  end

  describe "finish campaign" do
    setup [:create_campaign]

    test "finishes a campaign and sets status to completed", %{conn: conn, campaign: campaign} do
      conn = post(conn, ~p"/api/campaigns/#{campaign.id}/finish")

      assert %{"id" => id, "status" => "completed", "finished_at" => finished_at} =
               json_response(conn, 200)["data"]

      assert id == campaign.id
      assert finished_at != nil
    end
  end

  defp create_campaign(_) do
    campaign = insert(:campaign)
    %{campaign: campaign}
  end
end
