defmodule CampaignsApi.CampaignManagement.Campaigns do
  @moduledoc false

  import Ecto.Query

  alias CampaignsApi.CampaignManagement.Campaign
  alias CampaignsApi.Pagination
  alias CampaignsApi.Repo

  @type product_id :: String.t()
  @type campaign_id :: Ecto.UUID.t()
  @type attrs :: map()

  @spec list_campaigns(product_id(), Pagination.pagination_opts()) ::
          Pagination.pagination_result(Campaign.t())
  def list_campaigns(product_id, opts \\ []) do
    query =
      from(c in Campaign,
        where: c.product_id == ^product_id
      )

    Pagination.paginate(Repo, query, opts)
  end

  @spec get_campaign(product_id(), campaign_id()) :: Campaign.t() | nil
  def get_campaign(product_id, campaign_id) do
    Repo.get_by(Campaign, id: campaign_id, product_id: product_id)
  end

  @spec create_campaign(product_id(), attrs()) ::
          {:ok, Campaign.t()} | {:error, Ecto.Changeset.t()}
  def create_campaign(product_id, attrs) do
    %Campaign{}
    |> Campaign.changeset(Map.put(attrs, :product_id, product_id))
    |> Repo.insert()
  end

  @spec update_campaign(product_id(), campaign_id(), attrs()) ::
          {:ok, Campaign.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def update_campaign(product_id, campaign_id, attrs) do
    case get_campaign(product_id, campaign_id) do
      nil ->
        {:error, :not_found}

      campaign ->
        campaign
        |> Campaign.changeset(attrs)
        |> Repo.update()
    end
  end

  @spec delete_campaign(product_id(), campaign_id()) :: {:ok, Campaign.t()} | {:error, :not_found}
  def delete_campaign(product_id, campaign_id) do
    case get_campaign(product_id, campaign_id) do
      nil ->
        {:error, :not_found}

      campaign ->
        Repo.delete(campaign)
    end
  end
end
