defmodule CampaignsApi.CampaignManagement.Participants do
  @moduledoc false

  import Ecto.Query

  alias CampaignsApi.CampaignManagement.Campaign
  alias CampaignsApi.CampaignManagement.CampaignChallenge
  alias CampaignsApi.CampaignManagement.CampaignParticipant
  alias CampaignsApi.CampaignManagement.Participant
  alias CampaignsApi.CampaignManagement.ParticipantChallenge
  alias CampaignsApi.Challenges.Challenge, as: ChallengeSchema
  alias CampaignsApi.Pagination
  alias CampaignsApi.Repo

  @type product_id :: String.t()
  @type campaign_id :: Ecto.UUID.t()
  @type participant_id :: Ecto.UUID.t()
  @type challenge_id :: Ecto.UUID.t()
  @type attrs :: map()

  @spec create_participant(product_id(), attrs()) ::
          {:ok, Participant.t()} | {:error, Ecto.Changeset.t()}
  def create_participant(product_id, attrs) do
    %Participant{}
    |> Participant.changeset(Map.put(attrs, :product_id, product_id))
    |> Repo.insert()
  end

  @spec list_participants(product_id(), keyword()) ::
          Pagination.pagination_result(Participant.t())
  def list_participants(product_id, opts \\ []) do
    query =
      from(p in Participant,
        where: p.product_id == ^product_id
      )

    query =
      case Keyword.get(opts, :nickname) do
        nil -> query
        nickname -> from(p in query, where: ilike(p.nickname, ^"%#{nickname}%"))
      end

    Pagination.paginate(Repo, query, Keyword.drop(opts, [:nickname]))
  end

  @spec get_participant(product_id(), participant_id()) :: Participant.t() | nil
  def get_participant(product_id, participant_id) do
    Participant
    |> where([p], p.id == ^participant_id and p.product_id == ^product_id)
    |> Repo.one()
  end

  @spec update_participant(product_id(), participant_id(), attrs()) ::
          {:ok, Participant.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def update_participant(product_id, participant_id, attrs) do
    case get_participant(product_id, participant_id) do
      nil ->
        {:error, :not_found}

      participant ->
        participant
        |> Participant.changeset(attrs)
        |> Repo.update()
    end
  end

  @spec delete_participant(product_id(), participant_id()) ::
          {:ok, Participant.t()} | {:error, :not_found}
  def delete_participant(product_id, participant_id) do
    case get_participant(product_id, participant_id) do
      nil ->
        {:error, :not_found}

      participant ->
        Repo.delete(participant)
    end
  end

  @spec associate_participant_with_campaign(product_id(), participant_id(), campaign_id()) ::
          {:ok, CampaignParticipant.t()} | {:error, :product_mismatch | Ecto.Changeset.t()}
  def associate_participant_with_campaign(product_id, participant_id, campaign_id) do
    participant = get_participant(product_id, participant_id)

    campaign =
      Campaign
      |> where([c], c.id == ^campaign_id and c.product_id == ^product_id)
      |> Repo.one()

    case {participant, campaign} do
      {nil, _} ->
        {:error, :product_mismatch}

      {_, nil} ->
        {:error, :product_mismatch}

      {_participant, _campaign} ->
        %CampaignParticipant{}
        |> CampaignParticipant.changeset(%{
          participant_id: participant_id,
          campaign_id: campaign_id
        })
        |> Repo.insert()
    end
  end

  @spec disassociate_participant_from_campaign(product_id(), participant_id(), campaign_id()) ::
          {:ok, CampaignParticipant.t()} | {:error, :not_found}
  def disassociate_participant_from_campaign(product_id, participant_id, campaign_id) do
    campaign_participant = find_campaign_participant(product_id, participant_id, campaign_id)

    case campaign_participant do
      nil -> {:error, :not_found}
      cp -> delete_campaign_participant_with_challenges(cp, participant_id, campaign_id)
    end
  end

  @spec list_campaigns_for_participant(
          product_id(),
          participant_id(),
          Pagination.pagination_opts()
        ) ::
          Pagination.pagination_result(Campaign.t())
  def list_campaigns_for_participant(product_id, participant_id, opts \\ []) do
    query =
      from(c in Campaign,
        join: cp in CampaignParticipant,
        on: cp.campaign_id == c.id,
        join: p in Participant,
        on: cp.participant_id == p.id,
        where:
          cp.participant_id == ^participant_id and
            p.product_id == ^product_id and
            c.product_id == ^product_id,
        order_by: [desc: cp.inserted_at],
        select: %{c | inserted_at: cp.inserted_at}
      )

    Pagination.paginate(Repo, query, opts)
  end

  @spec list_participants_for_campaign(product_id(), campaign_id(), Pagination.pagination_opts()) ::
          Pagination.pagination_result(Participant.t())
  def list_participants_for_campaign(product_id, campaign_id, opts \\ []) do
    query =
      from(p in Participant,
        join: cp in CampaignParticipant,
        on: cp.participant_id == p.id,
        join: c in Campaign,
        on: cp.campaign_id == c.id,
        where:
          cp.campaign_id == ^campaign_id and
            p.product_id == ^product_id and
            c.product_id == ^product_id,
        order_by: [desc: cp.inserted_at],
        select: %{p | inserted_at: cp.inserted_at}
      )

    Pagination.paginate(Repo, query, opts)
  end

  @spec associate_participant_with_challenge(product_id(), participant_id(), challenge_id()) ::
          {:ok, ParticipantChallenge.t()}
          | {:error, :product_mismatch | :participant_not_in_campaign | Ecto.Changeset.t()}
  def associate_participant_with_challenge(product_id, participant_id, challenge_id) do
    participant = get_participant(product_id, participant_id)

    challenge_with_campaign =
      from(cc in CampaignChallenge,
        join: c in Campaign,
        on: cc.campaign_id == c.id,
        where: cc.challenge_id == ^challenge_id and c.product_id == ^product_id,
        select: %{challenge_id: cc.challenge_id, campaign_id: cc.campaign_id}
      )
      |> Repo.one()

    campaign_participant =
      case challenge_with_campaign do
        nil ->
          nil

        %{campaign_id: campaign_id} ->
          CampaignParticipant
          |> where(
            [cp],
            cp.participant_id == ^participant_id and cp.campaign_id == ^campaign_id
          )
          |> Repo.one()
      end

    case {participant, challenge_with_campaign, campaign_participant} do
      {nil, _, _} ->
        {:error, :product_mismatch}

      {_, nil, _} ->
        {:error, :product_mismatch}

      {_, _, nil} ->
        {:error, :participant_not_in_campaign}

      {_participant, %{campaign_id: campaign_id}, _cp} ->
        %ParticipantChallenge{}
        |> ParticipantChallenge.changeset(%{
          participant_id: participant_id,
          challenge_id: challenge_id,
          campaign_id: campaign_id
        })
        |> Repo.insert()
    end
  end

  @spec disassociate_participant_from_challenge(product_id(), participant_id(), challenge_id()) ::
          {:ok, ParticipantChallenge.t()} | {:error, :not_found}
  def disassociate_participant_from_challenge(product_id, participant_id, challenge_id) do
    participant_challenge =
      ParticipantChallenge
      |> join(:inner, [pc], p in Participant, on: pc.participant_id == p.id)
      |> join(:inner, [pc], cc in CampaignChallenge, on: pc.challenge_id == cc.challenge_id)
      |> join(:inner, [pc, p, cc], c in Campaign, on: cc.campaign_id == c.id)
      |> where(
        [pc, p, cc, c],
        pc.participant_id == ^participant_id and
          pc.challenge_id == ^challenge_id and
          p.product_id == ^product_id and
          c.product_id == ^product_id
      )
      |> Repo.one()

    case participant_challenge do
      nil -> {:error, :not_found}
      pc -> Repo.delete(pc)
    end
  end

  @spec list_challenges_for_participant(
          product_id(),
          participant_id(),
          keyword()
        ) ::
          Pagination.pagination_result(ChallengeSchema.t())
  def list_challenges_for_participant(product_id, participant_id, opts \\ []) do
    query =
      from(ch in ChallengeSchema,
        join: pc in ParticipantChallenge,
        on: pc.challenge_id == ch.id,
        join: p in Participant,
        on: pc.participant_id == p.id,
        join: c in Campaign,
        on: pc.campaign_id == c.id,
        where:
          pc.participant_id == ^participant_id and
            p.product_id == ^product_id and
            c.product_id == ^product_id,
        order_by: [desc: pc.inserted_at],
        select: %{ch | inserted_at: pc.inserted_at}
      )

    query =
      case Keyword.get(opts, :campaign_id) do
        nil -> query
        campaign_id -> from([ch, pc, p, c] in query, where: pc.campaign_id == ^campaign_id)
      end

    Pagination.paginate(Repo, query, Keyword.drop(opts, [:campaign_id]))
  end

  @spec list_participants_for_challenge(
          product_id(),
          challenge_id(),
          Pagination.pagination_opts()
        ) ::
          Pagination.pagination_result(Participant.t())
  def list_participants_for_challenge(product_id, challenge_id, opts \\ []) do
    query =
      from(p in Participant,
        join: pc in ParticipantChallenge,
        on: pc.participant_id == p.id,
        join: c in Campaign,
        on: pc.campaign_id == c.id,
        where:
          pc.challenge_id == ^challenge_id and
            p.product_id == ^product_id and
            c.product_id == ^product_id,
        order_by: [desc: pc.inserted_at],
        select: %{p | inserted_at: pc.inserted_at}
      )

    Pagination.paginate(Repo, query, opts)
  end

  defp find_campaign_participant(product_id, participant_id, campaign_id) do
    CampaignParticipant
    |> join(:inner, [cp], p in Participant, on: cp.participant_id == p.id)
    |> join(:inner, [cp], c in Campaign, on: cp.campaign_id == c.id)
    |> where(
      [cp, p, c],
      cp.participant_id == ^participant_id and
        cp.campaign_id == ^campaign_id and
        p.product_id == ^product_id and
        c.product_id == ^product_id
    )
    |> Repo.one()
  end

  defp delete_campaign_participant_with_challenges(cp, participant_id, campaign_id) do
    Repo.transaction(fn ->
      delete_participant_challenges(participant_id, campaign_id)
      delete_campaign_participant_record(cp)
    end)
    |> handle_transaction_result()
  end

  defp delete_participant_challenges(participant_id, campaign_id) do
    from(pc in ParticipantChallenge,
      where: pc.participant_id == ^participant_id and pc.campaign_id == ^campaign_id
    )
    |> Repo.delete_all()
  end

  defp delete_campaign_participant_record(cp) do
    case Repo.delete(cp) do
      {:ok, deleted_cp} -> deleted_cp
      {:error, changeset} -> Repo.rollback(changeset)
    end
  end

  defp handle_transaction_result({:ok, deleted_cp}), do: {:ok, deleted_cp}
  defp handle_transaction_result({:error, reason}), do: {:error, reason}
end
