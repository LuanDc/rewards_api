defmodule CampaignsApi.CampaignManagement do
  @moduledoc """
  The CampaignManagement context manages campaign and participant operations with tenant isolation.

  All operations require tenant_id parameter to ensure data isolation between tenants.
  Provides CRUD operations for campaigns, campaign challenges, participants, and their associations.
  """

  import Ecto.Query
  alias CampaignsApi.CampaignManagement.Campaign
  alias CampaignsApi.CampaignManagement.CampaignChallenge
  alias CampaignsApi.CampaignManagement.CampaignParticipant
  alias CampaignsApi.CampaignManagement.Participant
  alias CampaignsApi.CampaignManagement.ParticipantChallenge
  alias CampaignsApi.Challenges.Challenge, as: ChallengeSchema
  alias CampaignsApi.Pagination
  alias CampaignsApi.Repo

  @type tenant_id :: String.t()
  @type campaign_id :: Ecto.UUID.t()
  @type participant_id :: Ecto.UUID.t()
  @type challenge_id :: Ecto.UUID.t()
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

  # Participant Operations

  @doc """
  Creates a new participant for a specific tenant.
  """
  @spec create_participant(tenant_id(), attrs()) ::
          {:ok, Participant.t()} | {:error, Ecto.Changeset.t()}
  def create_participant(tenant_id, attrs) do
    %Participant{}
    |> Participant.changeset(Map.put(attrs, :tenant_id, tenant_id))
    |> Repo.insert()
  end

  @doc """
  Lists participants for a specific tenant with cursor-based pagination.

  Supports optional nickname filtering (case-insensitive substring match).
  """
  @spec list_participants(tenant_id(), pagination_opts()) :: pagination_result()
  def list_participants(tenant_id, opts \\ []) do
    query =
      from p in Participant,
        where: p.tenant_id == ^tenant_id

    # Apply optional nickname filter
    query =
      case Keyword.get(opts, :nickname) do
        nil -> query
        nickname -> from p in query, where: ilike(p.nickname, ^"%#{nickname}%")
      end

    Pagination.paginate(Repo, query, opts)
  end

  @doc """
  Retrieves a participant by ID within a specific tenant.

  Returns the participant if found and belongs to the tenant, otherwise returns nil.
  """
  @spec get_participant(tenant_id(), participant_id()) :: Participant.t() | nil
  def get_participant(tenant_id, participant_id) do
    Participant
    |> where([p], p.id == ^participant_id and p.tenant_id == ^tenant_id)
    |> Repo.one()
  end

  @doc """
  Updates a participant within a specific tenant.

  Returns {:ok, participant} if the participant exists and is updated successfully.
  Returns {:error, :not_found} if the participant doesn't exist or belongs to a different tenant.
  Returns {:error, changeset} if validation fails.
  """
  @spec update_participant(tenant_id(), participant_id(), attrs()) ::
          {:ok, Participant.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def update_participant(tenant_id, participant_id, attrs) do
    case get_participant(tenant_id, participant_id) do
      nil ->
        {:error, :not_found}

      participant ->
        participant
        |> Participant.changeset(attrs)
        |> Repo.update()
    end
  end

  @doc """
  Deletes a participant within a specific tenant.

  Returns {:ok, participant} if the participant exists and is deleted successfully.
  Returns {:error, :not_found} if the participant doesn't exist or belongs to a different tenant.

  Note: All campaign and challenge associations will be automatically removed via cascade delete.
  """
  @spec delete_participant(tenant_id(), participant_id()) ::
          {:ok, Participant.t()} | {:error, :not_found}
  def delete_participant(tenant_id, participant_id) do
    case get_participant(tenant_id, participant_id) do
      nil ->
        {:error, :not_found}

      participant ->
        Repo.delete(participant)
    end
  end

  @doc """
  Associates a participant with a campaign within the same tenant.

  Returns {:ok, campaign_participant} if the association is created successfully.
  Returns {:error, :tenant_mismatch} if the participant and campaign belong to different tenants.
  Returns {:error, changeset} if validation fails (e.g., duplicate association).
  """
  @spec associate_participant_with_campaign(tenant_id(), participant_id(), campaign_id()) ::
          {:ok, CampaignParticipant.t()} | {:error, :tenant_mismatch | Ecto.Changeset.t()}
  def associate_participant_with_campaign(tenant_id, participant_id, campaign_id) do
    # Validate participant belongs to tenant
    participant = get_participant(tenant_id, participant_id)

    # Validate campaign belongs to tenant
    campaign =
      Campaign
      |> where([c], c.id == ^campaign_id and c.tenant_id == ^tenant_id)
      |> Repo.one()

    case {participant, campaign} do
      {nil, _} ->
        {:error, :tenant_mismatch}

      {_, nil} ->
        {:error, :tenant_mismatch}

      {_participant, _campaign} ->
        %CampaignParticipant{}
        |> CampaignParticipant.changeset(%{
          participant_id: participant_id,
          campaign_id: campaign_id
        })
        |> Repo.insert()
    end
  end

  @doc """
  Disassociates a participant from a campaign within the same tenant.

  Returns {:ok, campaign_participant} if the association is deleted successfully.
  Returns {:error, :not_found} if the association doesn't exist or belongs to a different tenant.

  Note: All participant-challenge associations for this campaign will be automatically removed.
  """
  @spec disassociate_participant_from_campaign(tenant_id(), participant_id(), campaign_id()) ::
          {:ok, CampaignParticipant.t()} | {:error, :not_found}
  def disassociate_participant_from_campaign(tenant_id, participant_id, campaign_id) do
    campaign_participant = find_campaign_participant(tenant_id, participant_id, campaign_id)

    case campaign_participant do
      nil -> {:error, :not_found}
      cp -> delete_campaign_participant_with_challenges(cp, participant_id, campaign_id)
    end
  end

  @doc """
  Lists all campaigns a participant is enrolled in with cursor-based pagination.

  Returns a paginated list of campaigns ordered by association creation time (newest first).
  Only returns campaigns for participants belonging to the requesting tenant.
  """
  @spec list_campaigns_for_participant(tenant_id(), participant_id(), pagination_opts()) ::
          pagination_result()
  def list_campaigns_for_participant(tenant_id, participant_id, opts \\ []) do
    query =
      from c in Campaign,
        join: cp in CampaignParticipant,
        on: cp.campaign_id == c.id,
        join: p in Participant,
        on: cp.participant_id == p.id,
        where:
          cp.participant_id == ^participant_id and
            p.tenant_id == ^tenant_id and
            c.tenant_id == ^tenant_id,
        order_by: [desc: cp.inserted_at],
        select: %{c | inserted_at: cp.inserted_at}

    Pagination.paginate(Repo, query, opts)
  end

  @doc """
  Lists all participants enrolled in a campaign with cursor-based pagination.

  Returns a paginated list of participants ordered by association creation time (newest first).
  Only returns participants for campaigns belonging to the requesting tenant.
  """
  @spec list_participants_for_campaign(tenant_id(), campaign_id(), pagination_opts()) ::
          pagination_result()
  def list_participants_for_campaign(tenant_id, campaign_id, opts \\ []) do
    query =
      from p in Participant,
        join: cp in CampaignParticipant,
        on: cp.participant_id == p.id,
        join: c in Campaign,
        on: cp.campaign_id == c.id,
        where:
          cp.campaign_id == ^campaign_id and
            p.tenant_id == ^tenant_id and
            c.tenant_id == ^tenant_id,
        order_by: [desc: cp.inserted_at],
        select: %{p | inserted_at: cp.inserted_at}

    Pagination.paginate(Repo, query, opts)
  end

  @doc """
  Associates a participant with a challenge within the same tenant.

  Validates that:
  - Participant belongs to the tenant
  - Challenge belongs to the tenant (via its campaign)
  - Participant is already associated with the challenge's campaign

  Returns {:ok, participant_challenge} if the association is created successfully.
  Returns {:error, :tenant_mismatch} if resources belong to different tenants.
  Returns {:error, :participant_not_in_campaign} if participant is not in the challenge's campaign.
  Returns {:error, changeset} if validation fails (e.g., duplicate association).
  """
  @spec associate_participant_with_challenge(tenant_id(), participant_id(), challenge_id()) ::
          {:ok, ParticipantChallenge.t()}
          | {:error, :tenant_mismatch | :participant_not_in_campaign | Ecto.Changeset.t()}
  def associate_participant_with_challenge(tenant_id, participant_id, challenge_id) do
    # Validate participant belongs to tenant
    participant = get_participant(tenant_id, participant_id)

    # Query challenge with campaign via CampaignChallenge join
    challenge_with_campaign =
      from(cc in CampaignChallenge,
        join: c in Campaign,
        on: cc.campaign_id == c.id,
        where: cc.challenge_id == ^challenge_id and c.tenant_id == ^tenant_id,
        select: %{challenge_id: cc.challenge_id, campaign_id: cc.campaign_id}
      )
      |> Repo.one()

    # Check if participant is associated with the campaign
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
        {:error, :tenant_mismatch}

      {_, nil, _} ->
        {:error, :tenant_mismatch}

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

  @doc """
  Disassociates a participant from a challenge within the same tenant.

  Returns {:ok, participant_challenge} if the association is deleted successfully.
  Returns {:error, :not_found} if the association doesn't exist or belongs to a different tenant.
  """
  @spec disassociate_participant_from_challenge(tenant_id(), participant_id(), challenge_id()) ::
          {:ok, ParticipantChallenge.t()} | {:error, :not_found}
  def disassociate_participant_from_challenge(tenant_id, participant_id, challenge_id) do
    participant_challenge =
      ParticipantChallenge
      |> join(:inner, [pc], p in Participant, on: pc.participant_id == p.id)
      |> join(:inner, [pc], cc in CampaignChallenge,
        on: pc.challenge_id == cc.challenge_id
      )
      |> join(:inner, [pc, p, cc], c in Campaign, on: cc.campaign_id == c.id)
      |> where(
        [pc, p, cc, c],
        pc.participant_id == ^participant_id and
          pc.challenge_id == ^challenge_id and
          p.tenant_id == ^tenant_id and
          c.tenant_id == ^tenant_id
      )
      |> Repo.one()

    case participant_challenge do
      nil -> {:error, :not_found}
      pc -> Repo.delete(pc)
    end
  end

  @doc """
  Lists all challenges a participant is enrolled in with cursor-based pagination.

  Supports optional campaign_id filtering to show only challenges from a specific campaign.
  Returns a paginated list of challenges ordered by association creation time (newest first).
  Only returns challenges for participants belonging to the requesting tenant.
  """
  @spec list_challenges_for_participant(tenant_id(), participant_id(), pagination_opts()) ::
          pagination_result()
  def list_challenges_for_participant(tenant_id, participant_id, opts \\ []) do
    query =
      from ch in ChallengeSchema,
        join: pc in ParticipantChallenge,
        on: pc.challenge_id == ch.id,
        join: p in Participant,
        on: pc.participant_id == p.id,
        join: c in Campaign,
        on: pc.campaign_id == c.id,
        where:
          pc.participant_id == ^participant_id and
            p.tenant_id == ^tenant_id and
            c.tenant_id == ^tenant_id,
        order_by: [desc: pc.inserted_at],
        select: %{ch | inserted_at: pc.inserted_at}

    # Apply optional campaign_id filter
    query =
      case Keyword.get(opts, :campaign_id) do
        nil -> query
        campaign_id -> from [ch, pc, p, c] in query, where: pc.campaign_id == ^campaign_id
      end

    Pagination.paginate(Repo, query, opts)
  end

  @doc """
  Lists all participants enrolled in a specific challenge with cursor-based pagination.

  Returns a paginated list of participants ordered by association creation time (newest first).
  Only returns participants for challenges belonging to the requesting tenant.
  """
  @spec list_participants_for_challenge(tenant_id(), challenge_id(), pagination_opts()) ::
          pagination_result()
  def list_participants_for_challenge(tenant_id, challenge_id, opts \\ []) do
    query =
      from p in Participant,
        join: pc in ParticipantChallenge,
        on: pc.participant_id == p.id,
        join: c in Campaign,
        on: pc.campaign_id == c.id,
        where:
          pc.challenge_id == ^challenge_id and
            p.tenant_id == ^tenant_id and
            c.tenant_id == ^tenant_id,
        order_by: [desc: pc.inserted_at],
        select: %{p | inserted_at: pc.inserted_at}

    Pagination.paginate(Repo, query, opts)
  end

  # Private Helpers

  defp find_campaign_participant(tenant_id, participant_id, campaign_id) do
    CampaignParticipant
    |> join(:inner, [cp], p in Participant, on: cp.participant_id == p.id)
    |> join(:inner, [cp], c in Campaign, on: cp.campaign_id == c.id)
    |> where(
      [cp, p, c],
      cp.participant_id == ^participant_id and
        cp.campaign_id == ^campaign_id and
        p.tenant_id == ^tenant_id and
        c.tenant_id == ^tenant_id
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
