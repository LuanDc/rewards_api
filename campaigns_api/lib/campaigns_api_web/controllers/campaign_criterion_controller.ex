defmodule CampaignsApiWeb.CampaignCriterionController do
  @moduledoc """
  Controller for managing campaign criteria associations.
  """

  use CampaignsApiWeb, :controller

  alias CampaignsApi.Campaigns.CampaignCriterion
  alias CampaignsApi.Criteria

  action_fallback(CampaignsApiWeb.FallbackController)

  @doc """
  Lists all criteria associated with a specific campaign for the authenticated tenant.
  """
  def index(conn, %{"campaign_id" => campaign_id}) do
    tenant = conn.assigns.tenant

    campaign_criteria = Criteria.list_campaign_criteria_by_tenant(campaign_id, tenant)
    render(conn, :index, campaign_criteria: campaign_criteria)
  end

  @doc """
  Associates a criterion with a campaign.

  Expects params:
  - criterion_id (required): The ID of the criterion to associate
  - reward_points_amount (required): The amount of points for this criterion
  - periodicity (optional): How often the criterion can be completed (e.g., "daily", "weekly", "once")
  - status (optional): Status of the association (default: "active")
  """
  def create(conn, %{"campaign_id" => campaign_id, "campaign_criterion" => params}) do
    tenant = conn.assigns.tenant
    params_with_campaign = Map.put(params, "campaign_id", campaign_id)

    with {:ok, %CampaignCriterion{} = campaign_criterion} <-
           Criteria.associate_criterion_to_campaign_by_tenant(params_with_campaign, tenant) do
      conn
      |> put_status(:created)
      |> render(:create, campaign_criterion: campaign_criterion)
    end
  end

  @doc """
  Updates a campaign criterion association.
  """
  def update(conn, %{
        "campaign_id" => campaign_id,
        "id" => criterion_id,
        "campaign_criterion" => params
      }) do
    tenant = conn.assigns.tenant

    with {:ok, %CampaignCriterion{} = campaign_criterion} <-
           Criteria.update_campaign_criterion_by_tenant(campaign_id, criterion_id, params, tenant) do
      render(conn, :show, campaign_criterion: campaign_criterion)
    end
  end

  @doc """
  Removes a criterion association from a campaign.
  """
  def delete(conn, %{"campaign_id" => campaign_id, "id" => criterion_id}) do
    tenant = conn.assigns.tenant

    with {:ok, %CampaignCriterion{}} <-
           Criteria.remove_campaign_criterion_by_tenant(campaign_id, criterion_id, tenant) do
      send_resp(conn, :no_content, "")
    end
  end
end
