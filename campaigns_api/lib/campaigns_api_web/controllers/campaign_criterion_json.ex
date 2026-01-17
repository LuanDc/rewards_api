defmodule CampaignsApiWeb.CampaignCriterionJSON do
  @moduledoc """
  JSON rendering for campaign criteria.
  """

  alias CampaignsApi.Campaigns.CampaignCriterion

  @doc """
  Renders a list of campaign criteria.
  """
  def index(%{campaign_criteria: campaign_criteria}) do
    %{data: for(campaign_criterion <- campaign_criteria, do: data(campaign_criterion))}
  end

  @doc """
  Renders a single campaign criterion.
  """
  def show(%{campaign_criterion: campaign_criterion}) do
    %{data: data(campaign_criterion)}
  end

  @doc """
  Renders a single campaign criterion for creation.
  """
  def create(%{campaign_criterion: campaign_criterion}) do
    %{data: data(campaign_criterion)}
  end

  defp data(%CampaignCriterion{} = campaign_criterion) do
    %{
      id: campaign_criterion.id,
      campaign_id: campaign_criterion.campaign_id,
      criterion_id: campaign_criterion.criterion_id,
      reward_points_amount: campaign_criterion.reward_points_amount,
      periodicity: campaign_criterion.periodicity,
      status: campaign_criterion.status,
      criterion: criterion_data(campaign_criterion.criterion),
      inserted_at: campaign_criterion.inserted_at,
      updated_at: campaign_criterion.updated_at
    }
  end

  defp criterion_data(nil), do: nil

  defp criterion_data(criterion) do
    %{
      id: criterion.id,
      name: criterion.name,
      description: criterion.description,
      status: criterion.status
    }
  end
end
