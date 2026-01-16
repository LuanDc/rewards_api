defmodule CampaignsApiWeb.CampaignController do
  @moduledoc """
  Controller for managing campaigns.
  """

  use CampaignsApiWeb, :controller

  alias CampaignsApi.Campaigns
  alias CampaignsApi.Campaigns.Campaign

  action_fallback CampaignsApiWeb.FallbackController

  @doc """
  Lists all campaigns.
  """
  def index(conn, _params) do
    campaigns = Campaigns.list_campaigns()
    render(conn, :index, campaigns: campaigns)
  end

  @doc """
  Creates a new campaign.

  Expects params:
  - name (required): Campaign name
  - tenant (required): Tenant identifier string
  - started_at (optional): Start date/time
  - finished_at (optional): End date/time
  - status (optional): Campaign status
  """
  def create(conn, %{"campaign" => campaign_params}) do
    with {:ok, %Campaign{} = campaign} <- Campaigns.create_campaign(campaign_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/campaigns/#{campaign}")
      |> render(:create, campaign: campaign)
    end
  end

  @doc """
  Shows a single campaign.
  """
  def show(conn, %{"id" => id}) do
    campaign = Campaigns.get_campaign!(id)
    render(conn, :show, campaign: campaign)
  end

  @doc """
  Updates a campaign.
  """
  def update(conn, %{"id" => id, "campaign" => campaign_params}) do
    campaign = Campaigns.get_campaign!(id)

    with {:ok, %Campaign{} = campaign} <- Campaigns.update_campaign(campaign, campaign_params) do
      render(conn, :show, campaign: campaign)
    end
  end

  @doc """
  Deletes a campaign.
  """
  def delete(conn, %{"id" => id}) do
    campaign = Campaigns.get_campaign!(id)

    with {:ok, %Campaign{}} <- Campaigns.delete_campaign(campaign) do
      send_resp(conn, :no_content, "")
    end
  end

  @doc """
  Starts a campaign.
  """
  def start(conn, %{"campaign_id" => id}) do
    campaign = Campaigns.get_campaign!(id)

    with {:ok, %Campaign{} = campaign} <- Campaigns.start_campaign(campaign) do
      render(conn, :show, campaign: campaign)
    end
  end

  @doc """
  Finishes a campaign.
  """
  def finish(conn, %{"campaign_id" => id}) do
    campaign = Campaigns.get_campaign!(id)

    with {:ok, %Campaign{} = campaign} <- Campaigns.finish_campaign(campaign) do
      render(conn, :show, campaign: campaign)
    end
  end
end
