defmodule CampaignsApi.CampaignManagement.CampaignChallenges do
  @moduledoc false

  import Ecto.Query

  alias CampaignsApi.CampaignManagement.Campaign
  alias CampaignsApi.CampaignManagement.CampaignChallenge
  alias CampaignsApi.Outbox
  alias CampaignsApi.Pagination
  alias CampaignsApi.Repo
  alias Ecto.Multi

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
      |> then(fn changeset ->
        Multi.new()
        |> Multi.insert(:campaign_challenge, changeset)
        |> Outbox.enqueue_multi(:campaign_challenge_created,
          aggregate_type: "campaign_challenge",
          event_type: "campaign_challenge.created",
          aggregate_id: fn %{campaign_challenge: campaign_challenge} -> campaign_challenge.id end,
          payload: fn %{campaign_challenge: campaign_challenge} ->
            campaign_challenge_payload(campaign_challenge, product_id)
          end
        )
        |> Repo.transaction()
        |> case do
          {:ok, %{campaign_challenge: campaign_challenge}} -> {:ok, campaign_challenge}
          {:error, :campaign_challenge, changeset, _changes} -> {:error, changeset}
          {:error, _step, reason, _changes} -> {:error, reason}
        end
      end)
    end
  end

  @spec update_campaign_challenge(product_id(), campaign_id(), Ecto.UUID.t(), attrs()) ::
          {:ok, CampaignChallenge.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def update_campaign_challenge(product_id, campaign_id, campaign_challenge_id, attrs) do
    case get_campaign_challenge(product_id, campaign_id, campaign_challenge_id) do
      nil ->
        {:error, :not_found}

      campaign_challenge ->
        Multi.new()
        |> Multi.update(
          :campaign_challenge,
          CampaignChallenge.changeset(campaign_challenge, attrs)
        )
        |> Outbox.enqueue_multi(:campaign_challenge_updated,
          aggregate_type: "campaign_challenge",
          event_type: "campaign_challenge.updated",
          aggregate_id: fn %{campaign_challenge: updated_campaign_challenge} ->
            updated_campaign_challenge.id
          end,
          payload: fn %{campaign_challenge: updated_campaign_challenge} ->
            campaign_challenge_payload(updated_campaign_challenge, product_id)
          end
        )
        |> Repo.transaction()
        |> case do
          {:ok, %{campaign_challenge: updated_campaign_challenge}} ->
            {:ok, updated_campaign_challenge}

          {:error, :campaign_challenge, changeset, _changes} ->
            {:error, changeset}

          {:error, _step, reason, _changes} ->
            {:error, reason}
        end
    end
  end

  @spec delete_campaign_challenge(product_id(), campaign_id(), Ecto.UUID.t()) ::
          {:ok, CampaignChallenge.t()} | {:error, :not_found}
  def delete_campaign_challenge(product_id, campaign_id, campaign_challenge_id) do
    case get_campaign_challenge(product_id, campaign_id, campaign_challenge_id) do
      nil ->
        {:error, :not_found}

      campaign_challenge ->
        Multi.new()
        |> Multi.delete(:campaign_challenge, campaign_challenge)
        |> Outbox.enqueue_multi(:campaign_challenge_deleted,
          aggregate_type: "campaign_challenge",
          event_type: "campaign_challenge.deleted",
          aggregate_id: fn %{campaign_challenge: deleted_campaign_challenge} ->
            deleted_campaign_challenge.id
          end,
          payload: fn %{campaign_challenge: deleted_campaign_challenge} ->
            campaign_challenge_payload(deleted_campaign_challenge, product_id)
          end
        )
        |> Repo.transaction()
        |> case do
          {:ok, %{campaign_challenge: deleted_campaign_challenge}} ->
            {:ok, deleted_campaign_challenge}

          {:error, :campaign_challenge, reason, _changes} ->
            {:error, reason}

          {:error, _step, reason, _changes} ->
            {:error, reason}
        end
    end
  end

  defp validate_campaign_ownership(product_id, campaign_id) do
    case Repo.get_by(Campaign, id: campaign_id, product_id: product_id) do
      nil -> {:error, :campaign_not_found}
      campaign -> {:ok, campaign}
    end
  end

  defp campaign_challenge_payload(campaign_challenge, product_id) do
    %{
      id: campaign_challenge.id,
      product_id: product_id,
      campaign_id: campaign_challenge.campaign_id,
      challenge_id: campaign_challenge.challenge_id,
      display_name: campaign_challenge.display_name,
      display_description: campaign_challenge.display_description,
      evaluation_frequency: campaign_challenge.evaluation_frequency,
      reward_points: campaign_challenge.reward_points,
      configuration: campaign_challenge.configuration,
      inserted_at: campaign_challenge.inserted_at,
      updated_at: campaign_challenge.updated_at
    }
  end
end
