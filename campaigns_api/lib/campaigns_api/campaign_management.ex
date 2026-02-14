defmodule CampaignsApi.CampaignManagement do
  @moduledoc """
  The CampaignManagement context manages campaign operations with tenant isolation.

  All operations require tenant_id parameter to ensure data isolation between tenants.
  """

  import Ecto.Query
  alias CampaignsApi.CampaignManagement.Campaign
  alias CampaignsApi.CampaignManagement.CampaignChallenge
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

  # Campaign Challenge Operations

  @doc """
  Lists campaign challenges for a specific campaign with tenant isolation.
  """
  @spec list_campaign_challenges(tenant_id(), campaign_id(), pagination_opts()) ::
          pagination_result()
  def list_campaign_challenges(tenant_id, campaign_id, opts \\ []) do
    query =
      from cc in CampaignChallenge,
        join: c in assoc(cc, :campaign),
        where: c.tenant_id == ^tenant_id and cc.campaign_id == ^campaign_id,
        preload: [:challenge]

    Pagination.paginate(Repo, query, opts)
  end

  @doc """
  Gets a single campaign challenge by ID with tenant isolation.
  """
  @spec get_campaign_challenge(tenant_id(), campaign_id(), Ecto.UUID.t()) ::
          CampaignChallenge.t() | nil
  def get_campaign_challenge(tenant_id, campaign_id, campaign_challenge_id) do
    from(cc in CampaignChallenge,
      join: c in assoc(cc, :campaign),
      where:
        c.tenant_id == ^tenant_id and
          cc.campaign_id == ^campaign_id and
          cc.id == ^campaign_challenge_id,
      preload: [:challenge]
    )
    |> Repo.one()
  end

  @doc """
  Creates a new campaign challenge association.
  """
  @spec create_campaign_challenge(tenant_id(), campaign_id(), attrs()) ::
          {:ok, CampaignChallenge.t()} | {:error, :campaign_not_found | Ecto.Changeset.t()}
  def create_campaign_challenge(tenant_id, campaign_id, attrs) do
    with {:ok, _campaign} <- validate_campaign_ownership(tenant_id, campaign_id) do
      # Convert string keys to atoms and add campaign_id
      attrs =
        attrs
        |> Enum.map(fn {k, v} -> {to_string(k), v} end)
        |> Map.new()
        |> Map.put("campaign_id", campaign_id)

      %CampaignChallenge{}
      |> CampaignChallenge.changeset(attrs)
      |> Repo.insert()
    end
  end

  @doc """
  Updates an existing campaign challenge.
  """
  @spec update_campaign_challenge(tenant_id(), campaign_id(), Ecto.UUID.t(), attrs()) ::
          {:ok, CampaignChallenge.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def update_campaign_challenge(tenant_id, campaign_id, campaign_challenge_id, attrs) do
    case get_campaign_challenge(tenant_id, campaign_id, campaign_challenge_id) do
      nil ->
        {:error, :not_found}

      campaign_challenge ->
        campaign_challenge
        |> CampaignChallenge.changeset(attrs)
        |> Repo.update()
    end
  end

  @doc """
  Deletes a campaign challenge association.
  """
  @spec delete_campaign_challenge(tenant_id(), campaign_id(), Ecto.UUID.t()) ::
          {:ok, CampaignChallenge.t()} | {:error, :not_found}
  def delete_campaign_challenge(tenant_id, campaign_id, campaign_challenge_id) do
    case get_campaign_challenge(tenant_id, campaign_id, campaign_challenge_id) do
      nil ->
        {:error, :not_found}

      campaign_challenge ->
        Repo.delete(campaign_challenge)
    end
  end

  # Private Helpers

  @doc false
  @spec validate_campaign_ownership(tenant_id(), campaign_id()) ::
          {:ok, Campaign.t()} | {:error, :campaign_not_found}
  defp validate_campaign_ownership(tenant_id, campaign_id) do
    case Repo.get_by(Campaign, id: campaign_id, tenant_id: tenant_id) do
      nil -> {:error, :campaign_not_found}
      campaign -> {:ok, campaign}
    end
  end
end
