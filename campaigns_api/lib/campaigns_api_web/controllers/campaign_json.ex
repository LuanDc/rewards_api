defmodule CampaignsApiWeb.CampaignJSON do
  @moduledoc """
  JSON rendering for Campaigns.
  """

  alias CampaignsApi.Campaigns.Campaign

  @doc """
  Renders a list of campaigns.
  """
  def index(%{campaigns: campaigns}) do
    %{data: for(campaign <- campaigns, do: data(campaign))}
  end

  @doc """
  Renders a single campaign.
  """
  def show(%{campaign: campaign}) do
    %{data: data(campaign)}
  end

  @doc """
  Renders campaign created response.
  """
  def create(%{campaign: campaign}) do
    %{data: data(campaign)}
  end

  defp data(%Campaign{} = campaign) do
    %{
      id: campaign.id,
      name: campaign.name,
      tenant: campaign.tenant,
      started_at: campaign.started_at,
      finished_at: campaign.finished_at,
      status: campaign.status,
      inserted_at: campaign.inserted_at,
      updated_at: campaign.updated_at
    }
  end
end
