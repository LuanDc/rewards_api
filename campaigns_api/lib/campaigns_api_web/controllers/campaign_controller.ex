defmodule CampaignsApiWeb.CampaignController do
  @moduledoc """
  Controller for managing campaigns.
  """

  use CampaignsApiWeb, :controller

  alias CampaignsApi.Campaigns
  alias CampaignsApi.Campaigns.Campaign

  action_fallback(CampaignsApiWeb.FallbackController)

  @doc """
  Lists all campaigns for the authenticated tenant.
  """
  def index(conn, _params) do
    tenant = conn.assigns.tenant
    campaigns = Campaigns.list_campaigns_by_tenant(tenant)
    render(conn, :index, campaigns: campaigns)
  end

  @doc """
  Creates a new campaign.

  Expects params:
  - name (required): Campaign name
  - started_at (optional): Start date/time
  - finished_at (optional): End date/time
  - status (optional): Campaign status

  The tenant is automatically extracted from the Authorization header.
  """
  def create(conn, %{"campaign" => campaign_params}) do
    tenant = conn.assigns.tenant
    params_with_tenant = Map.put(campaign_params, "tenant", tenant)

    with {:ok, %Campaign{} = campaign} <- Campaigns.create_campaign(params_with_tenant) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/campaigns/#{campaign}")
      |> render(:create, campaign: campaign)
    end
  end

  @doc """
  Shows a single campaign for the authenticated tenant.
  """
  def show(conn, %{"id" => id}) do
    tenant = conn.assigns.tenant

    case Campaigns.get_campaign_by_tenant(id, tenant) do
      nil ->
        conn
        |> put_status(:not_found)
        |> put_view(json: CampaignsApiWeb.ErrorJSON)
        |> render(:"404")

      campaign ->
        render(conn, :show, campaign: campaign)
    end
  end

  @doc """
  Updates a campaign for the authenticated tenant.
  """
  def update(conn, %{"id" => id, "campaign" => campaign_params}) do
    tenant = conn.assigns.tenant

    case Campaigns.get_campaign_by_tenant(id, tenant) do
      nil ->
        conn
        |> put_status(:not_found)
        |> put_view(json: CampaignsApiWeb.ErrorJSON)
        |> render(:"404")

      campaign ->
        with {:ok, %Campaign{} = campaign} <- Campaigns.update_campaign(campaign, campaign_params) do
          render(conn, :show, campaign: campaign)
        end
    end
  end

  @doc """
  Deletes a campaign for the authenticated tenant.
  """
  def delete(conn, %{"id" => id}) do
    tenant = conn.assigns.tenant

    case Campaigns.get_campaign_by_tenant(id, tenant) do
      nil ->
        conn
        |> put_status(:not_found)
        |> put_view(json: CampaignsApiWeb.ErrorJSON)
        |> render(:"404")

      campaign ->
        with {:ok, %Campaign{}} <- Campaigns.delete_campaign(campaign) do
          send_resp(conn, :no_content, "")
        end
    end
  end

  @doc """
  Starts a campaign for the authenticated tenant.
  """
  def start(conn, %{"campaign_id" => id}) do
    tenant = conn.assigns.tenant

    case Campaigns.get_campaign_by_tenant(id, tenant) do
      nil ->
        conn
        |> put_status(:not_found)
        |> put_view(json: CampaignsApiWeb.ErrorJSON)
        |> render(:"404")

      campaign ->
        with {:ok, %Campaign{} = campaign} <- Campaigns.start_campaign(campaign) do
          render(conn, :show, campaign: campaign)
        end
    end
  end

  @doc """
  Finishes a campaign for the authenticated tenant.
  """
  def finish(conn, %{"campaign_id" => id}) do
    tenant = conn.assigns.tenant

    case Campaigns.get_campaign_by_tenant(id, tenant) do
      nil ->
        conn
        |> put_status(:not_found)
        |> put_view(json: CampaignsApiWeb.ErrorJSON)
        |> render(:"404")

      campaign ->
        with {:ok, %Campaign{} = campaign} <- Campaigns.finish_campaign(campaign) do
          render(conn, :show, campaign: campaign)
        end
    end
  end
end
