defmodule CampaignsApi.CampaignManagement.CampaignChallenges do
  @moduledoc false

  import Ecto.Query

  alias CampaignsApi.CampaignManagement.Campaign
  alias CampaignsApi.CampaignManagement.CampaignChallenge
  alias CampaignsApi.Pagination
  alias CampaignsApi.Repo

  @type product_id :: String.t()
  @type campaign_id :: Ecto.UUID.t()
  @type attrs :: map()

  @spec list_campaign_challenges(product_id(), campaign_id(), Pagination.pagination_opts()) ::
          Pagination.pagination_result(CampaignChallenge.t())
  def list_campaign_challenges(product_id, campaign_id, opts \\ []) do
    query =
      from(cc in CampaignChallenge,
        join: c in assoc(cc, :campaign),
        where: c.product_id == ^product_id and cc.campaign_id == ^campaign_id,
        preload: [:challenge]
      )

    Pagination.paginate(Repo, query, opts)
  end

  @spec get_campaign_challenge(product_id(), campaign_id(), Ecto.UUID.t()) ::
          CampaignChallenge.t() | nil
  def get_campaign_challenge(product_id, campaign_id, campaign_challenge_id) do
    from(cc in CampaignChallenge,
      join: c in assoc(cc, :campaign),
      where:
        c.product_id == ^product_id and
          cc.campaign_id == ^campaign_id and
          cc.id == ^campaign_challenge_id,
      preload: [:challenge]
    )
    |> Repo.one()
  end

  @spec create_campaign_challenge(product_id(), campaign_id(), attrs()) ::
          {:ok, CampaignChallenge.t()} | {:error, :campaign_not_found | Ecto.Changeset.t()}
  def create_campaign_challenge(product_id, campaign_id, attrs) do
    with {:ok, _campaign} <- validate_campaign_ownership(product_id, campaign_id) do
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

  @spec update_campaign_challenge(product_id(), campaign_id(), Ecto.UUID.t(), attrs()) ::
          {:ok, CampaignChallenge.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def update_campaign_challenge(product_id, campaign_id, campaign_challenge_id, attrs) do
    case get_campaign_challenge(product_id, campaign_id, campaign_challenge_id) do
      nil ->
        {:error, :not_found}

      campaign_challenge ->
        campaign_challenge
        |> CampaignChallenge.changeset(attrs)
        |> Repo.update()
    end
  end

  @spec delete_campaign_challenge(product_id(), campaign_id(), Ecto.UUID.t()) ::
          {:ok, CampaignChallenge.t()} | {:error, :not_found}
  def delete_campaign_challenge(product_id, campaign_id, campaign_challenge_id) do
    case get_campaign_challenge(product_id, campaign_id, campaign_challenge_id) do
      nil ->
        {:error, :not_found}

      campaign_challenge ->
        Repo.delete(campaign_challenge)
    end
  end

  defp validate_campaign_ownership(product_id, campaign_id) do
    case Repo.get_by(Campaign, id: campaign_id, product_id: product_id) do
      nil -> {:error, :campaign_not_found}
      campaign -> {:ok, campaign}
    end
  end
end
