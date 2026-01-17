defmodule CampaignsApiWeb.CampaignCriterionControllerTest do
  use CampaignsApiWeb.ConnCase

  @tenant "tenant-abc123"

  describe "index" do
    setup [:create_campaign, :create_criterion]

    test "lists all campaign criteria for a campaign", %{
      conn: conn,
      campaign: campaign,
      criterion: criterion
    } do
      # Associate criterion with campaign
      {:ok, _} =
        CampaignsApi.Criteria.associate_criterion_to_campaign_by_tenant(
          %{
            "campaign_id" => campaign.id,
            "criterion_id" => criterion.id,
            "reward_points_amount" => 100,
            "periodicity" => "daily",
            "status" => "active"
          },
          @tenant
        )

      conn = conn |> put_auth_header() |> get(~p"/api/campaigns/#{campaign.id}/criteria")

      assert %{"data" => [criterion_data]} = json_response(conn, 200)
      assert criterion_data["criterion_id"] == criterion.id
      assert criterion_data["reward_points_amount"] == 100
    end

    test "returns empty list when no criteria associated", %{conn: conn, campaign: campaign} do
      conn = conn |> put_auth_header() |> get(~p"/api/campaigns/#{campaign.id}/criteria")
      assert json_response(conn, 200)["data"] == []
    end

    test "returns 401 when authorization header is missing", %{conn: conn, campaign: campaign} do
      conn = get(conn, ~p"/api/campaigns/#{campaign.id}/criteria")
      assert json_response(conn, 401)
    end
  end

  describe "create campaign criterion" do
    setup [:create_campaign, :create_criterion]

    test "associates a criterion with a campaign when data is valid", %{
      conn: conn,
      campaign: campaign,
      criterion: criterion
    } do
      attrs = %{
        criterion_id: criterion.id,
        reward_points_amount: 150,
        periodicity: "weekly",
        status: "active"
      }

      conn =
        conn
        |> put_auth_header()
        |> post(~p"/api/campaigns/#{campaign.id}/criteria", campaign_criterion: attrs)

      assert %{"id" => id} = json_response(conn, 201)["data"]
      assert json_response(conn, 201)["data"]["reward_points_amount"] == 150
      assert json_response(conn, 201)["data"]["periodicity"] == "weekly"

      conn = build_conn() |> put_auth_header() |> get(~p"/api/campaigns/#{campaign.id}/criteria")

      assert %{"data" => [criterion_data]} = json_response(conn, 200)
      assert criterion_data["id"] == id
    end

    test "renders errors when data is invalid", %{conn: conn, campaign: campaign} do
      attrs = %{reward_points_amount: nil}

      conn =
        conn
        |> put_auth_header()
        |> post(~p"/api/campaigns/#{campaign.id}/criteria", campaign_criterion: attrs)

      assert json_response(conn, 422)["errors"] != %{}
    end

    test "returns 401 when authorization header is missing", %{
      conn: conn,
      campaign: campaign,
      criterion: criterion
    } do
      attrs = %{criterion_id: criterion.id, reward_points_amount: 100}

      conn = post(conn, ~p"/api/campaigns/#{campaign.id}/criteria", campaign_criterion: attrs)
      assert json_response(conn, 401)
    end
  end

  describe "update campaign criterion" do
    setup [:create_campaign_with_criterion]

    test "updates the campaign criterion when data is valid", %{
      conn: conn,
      campaign: campaign,
      campaign_criterion: campaign_criterion
    } do
      update_attrs = %{reward_points_amount: 200, periodicity: "monthly"}

      conn =
        conn
        |> put_auth_header()
        |> put(
          ~p"/api/campaigns/#{campaign.id}/criteria/#{campaign_criterion.criterion_id}",
          campaign_criterion: update_attrs
        )

      assert %{"id" => _id} = json_response(conn, 200)["data"]
      assert json_response(conn, 200)["data"]["reward_points_amount"] == 200
      assert json_response(conn, 200)["data"]["periodicity"] == "monthly"
    end

    test "renders errors when data is invalid", %{
      conn: conn,
      campaign: campaign,
      campaign_criterion: campaign_criterion
    } do
      invalid_attrs = %{reward_points_amount: -10}

      conn =
        conn
        |> put_auth_header()
        |> put(
          ~p"/api/campaigns/#{campaign.id}/criteria/#{campaign_criterion.criterion_id}",
          campaign_criterion: invalid_attrs
        )

      assert json_response(conn, 422)["errors"] != %{}
    end

    test "returns 401 when authorization header is missing", %{
      conn: conn,
      campaign: campaign,
      campaign_criterion: campaign_criterion
    } do
      update_attrs = %{reward_points_amount: 200}

      conn =
        put(
          conn,
          ~p"/api/campaigns/#{campaign.id}/criteria/#{campaign_criterion.criterion_id}",
          campaign_criterion: update_attrs
        )

      assert json_response(conn, 401)
    end
  end

  describe "delete campaign criterion" do
    setup [:create_campaign_with_criterion]

    test "removes the criterion association from campaign", %{
      conn: conn,
      campaign: campaign,
      campaign_criterion: campaign_criterion
    } do
      conn =
        conn
        |> put_auth_header()
        |> delete(~p"/api/campaigns/#{campaign.id}/criteria/#{campaign_criterion.criterion_id}")

      assert response(conn, 204)

      conn =
        build_conn()
        |> put_auth_header()
        |> get(~p"/api/campaigns/#{campaign.id}/criteria")

      assert json_response(conn, 200)["data"] == []
    end

    test "returns 401 when authorization header is missing", %{
      conn: conn,
      campaign: campaign,
      campaign_criterion: campaign_criterion
    } do
      conn =
        delete(conn, ~p"/api/campaigns/#{campaign.id}/criteria/#{campaign_criterion.criterion_id}")

      assert json_response(conn, 401)
    end
  end

  defp create_campaign(_) do
    campaign = insert(:campaign, tenant: @tenant)
    %{campaign: campaign}
  end

  defp create_criterion(_) do
    criterion = insert(:criterion, tenant: @tenant)
    %{criterion: criterion}
  end

  defp create_campaign_with_criterion(_) do
    campaign = insert(:campaign, tenant: @tenant)
    criterion = insert(:criterion, tenant: @tenant)

    {:ok, campaign_criterion} =
      CampaignsApi.Criteria.associate_criterion_to_campaign_by_tenant(
        %{
          "campaign_id" => campaign.id,
          "criterion_id" => criterion.id,
          "reward_points_amount" => 100,
          "periodicity" => "daily",
          "status" => "active"
        },
        @tenant
      )

    %{campaign: campaign, criterion: criterion, campaign_criterion: campaign_criterion}
  end
end
