defmodule CampaignsApi.CampaignManagement do
  @moduledoc """
  The CampaignManagement context manages campaign operations with tenant isolation.

  All operations require tenant_id parameter to ensure data isolation between tenants.
  """

  import Ecto.Query
  alias CampaignsApi.CampaignManagement.Campaign
  alias CampaignsApi.Pagination
  alias CampaignsApi.Repo

  @type tenant_id :: String.t()
  @type campaign_id :: Ecto.UUID.t()
  @type attrs :: map()
  @type pagination_opts :: keyword()
  @type pagination_result :: %{
          data: [Campaign.t()],
          next_cursor: DateTime.t() | nil,
          has_more: boolean()
        }

  @doc """
  Lists campaigns for a specific tenant with cursor-based pagination.
  """
  @spec list_campaigns(tenant_id(), pagination_opts()) :: pagination_result()
  def list_campaigns(tenant_id, opts \\ []) do
    query =
      from c in Campaign,
        where: c.tenant_id == ^tenant_id

    Pagination.paginate(Repo, query, opts)
  end

  @doc """
  Gets a single campaign by ID for a specific tenant.
  """
  @spec get_campaign(tenant_id(), campaign_id()) :: Campaign.t() | nil
  def get_campaign(tenant_id, campaign_id) do
    Repo.get_by(Campaign, id: campaign_id, tenant_id: tenant_id)
  end

  @doc """
  Creates a new campaign for a specific tenant.
  """
  @spec create_campaign(tenant_id(), attrs()) :: {:ok, Campaign.t()} | {:error, Ecto.Changeset.t()}
  def create_campaign(tenant_id, attrs) do
    %Campaign{}
    |> Campaign.changeset(Map.put(attrs, :tenant_id, tenant_id))
    |> Repo.insert()
  end

  @doc """
  Updates an existing campaign for a specific tenant.
  """
  @spec update_campaign(tenant_id(), campaign_id(), attrs()) ::
          {:ok, Campaign.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def update_campaign(tenant_id, campaign_id, attrs) do
    case get_campaign(tenant_id, campaign_id) do
      nil ->
        {:error, :not_found}

      campaign ->
        campaign
        |> Campaign.changeset(attrs)
        |> Repo.update()
    end
  end

  @doc """
  Deletes a campaign for a specific tenant (hard delete).
  """
  @spec delete_campaign(tenant_id(), campaign_id()) :: {:ok, Campaign.t()} | {:error, :not_found}
  def delete_campaign(tenant_id, campaign_id) do
    case get_campaign(tenant_id, campaign_id) do
      nil ->
        {:error, :not_found}

      campaign ->
        Repo.delete(campaign)
    end
  end
end
