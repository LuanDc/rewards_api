defmodule CampaignsApi.CampaignManagement.Campaigns do
  @moduledoc false

  import Ecto.Query

  alias CampaignsApi.CampaignManagement.Campaign
  alias CampaignsApi.Outbox
  alias CampaignsApi.Pagination
  alias CampaignsApi.Repo
  alias Ecto.Multi

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
    attrs_with_product = Map.put(attrs, :product_id, product_id)

    Multi.new()
    |> Multi.insert(:campaign, Campaign.changeset(%Campaign{}, attrs_with_product))
    |> Outbox.enqueue_multi(:campaign_created,
      aggregate_type: "campaign",
      event_type: "campaign.created",
      aggregate_id: fn %{campaign: campaign} -> campaign.id end,
      payload: fn %{campaign: campaign} -> campaign_payload(campaign) end
    )
    |> Repo.transaction()
    |> case do
      {:ok, %{campaign: campaign}} -> {:ok, campaign}
      {:error, :campaign, changeset, _changes} -> {:error, changeset}
      {:error, _step, reason, _changes} -> {:error, reason}
    end
  end

  @spec update_campaign(product_id(), campaign_id(), attrs()) ::
          {:ok, Campaign.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def update_campaign(product_id, campaign_id, attrs) do
    case get_campaign(product_id, campaign_id) do
      nil ->
        {:error, :not_found}

      campaign ->
        Multi.new()
        |> Multi.update(:campaign, Campaign.changeset(campaign, attrs))
        |> Outbox.enqueue_multi(:campaign_updated,
          aggregate_type: "campaign",
          event_type: "campaign.updated",
          aggregate_id: fn %{campaign: updated_campaign} -> updated_campaign.id end,
          payload: fn %{campaign: updated_campaign} -> campaign_payload(updated_campaign) end
        )
        |> Repo.transaction()
        |> case do
          {:ok, %{campaign: updated_campaign}} -> {:ok, updated_campaign}
          {:error, :campaign, changeset, _changes} -> {:error, changeset}
          {:error, _step, reason, _changes} -> {:error, reason}
        end
    end
  end

  @spec delete_campaign(product_id(), campaign_id()) :: {:ok, Campaign.t()} | {:error, :not_found}
  def delete_campaign(product_id, campaign_id) do
    case get_campaign(product_id, campaign_id) do
      nil ->
        {:error, :not_found}

      campaign ->
        Multi.new()
        |> Multi.delete(:campaign, campaign)
        |> Outbox.enqueue_multi(:campaign_deleted,
          aggregate_type: "campaign",
          event_type: "campaign.deleted",
          aggregate_id: fn %{campaign: deleted_campaign} -> deleted_campaign.id end,
          payload: fn %{campaign: deleted_campaign} -> campaign_payload(deleted_campaign) end
        )
        |> Repo.transaction()
        |> case do
          {:ok, %{campaign: deleted_campaign}} -> {:ok, deleted_campaign}
          {:error, :campaign, reason, _changes} -> {:error, reason}
          {:error, _step, reason, _changes} -> {:error, reason}
        end
    end
  end

  defp campaign_payload(campaign) do
    %{
      id: campaign.id,
      product_id: campaign.product_id,
      name: campaign.name,
      description: campaign.description,
      start_time: campaign.start_time,
      end_time: campaign.end_time,
      status: campaign.status,
      inserted_at: campaign.inserted_at,
      updated_at: campaign.updated_at
    }
  end
end
