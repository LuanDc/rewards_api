defmodule CampaignsApi.Challenges do
  @moduledoc """
  Context for managing challenges.

  Challenges are reusable evaluation mechanisms that can be associated
  with multiple campaigns. This context handles internal challenge CRUD
  operations only. Campaign challenge associations are managed by the
  CampaignManagement context.
  """

  import Ecto.Query
  alias CampaignsApi.CampaignManagement.CampaignChallenge
  alias CampaignsApi.Challenges.Challenge
  alias CampaignsApi.Outbox
  alias CampaignsApi.Pagination
  alias CampaignsApi.Repo
  alias Ecto.Multi

  # Challenge Operations

  @doc """
  Lists all challenges with pagination support.

  Challenges are globally available to all products, so no product filtering is applied.

  ## Options

    * `:limit` - Maximum number of records to return (default: 50, max: 100)
    * `:cursor` - DateTime cursor for pagination

  ## Examples

      iex> list_challenges()
      %{data: [%Challenge{}, ...], next_cursor: ~U[2024-01-01 00:00:00Z], has_more: true}

      iex> list_challenges(limit: 10, cursor: ~U[2024-01-01 00:00:00Z])
      %{data: [%Challenge{}, ...], next_cursor: nil, has_more: false}

  """
  @spec list_challenges(Pagination.pagination_opts()) ::
          Pagination.pagination_result(Challenge.t())
  def list_challenges(opts \\ []) do
    query = from(c in Challenge)
    Pagination.paginate(Repo, query, opts)
  end

  @doc """
  Gets a single challenge by ID.

  Returns `nil` if the challenge does not exist.

  ## Examples

      iex> get_challenge("valid-uuid")
      %Challenge{}

      iex> get_challenge("invalid-uuid")
      nil

  """
  @spec get_challenge(Ecto.UUID.t()) :: Challenge.t() | nil
  def get_challenge(challenge_id) do
    Repo.get(Challenge, challenge_id)
  end

  @doc """
  Creates a new challenge.

  ## Examples

      iex> create_challenge(%{name: "TransactionsChecker", description: "Checks transactions"})
      {:ok, %Challenge{}}

      iex> create_challenge(%{name: "ab"})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_challenge(map()) :: {:ok, Challenge.t()} | {:error, Ecto.Changeset.t()}
  def create_challenge(attrs) do
    attrs = ensure_external_id(attrs)

    Multi.new()
    |> Multi.insert(:challenge, Challenge.changeset(%Challenge{}, attrs))
    |> Outbox.enqueue_multi(:challenge_created,
      aggregate_type: "challenge",
      event_type: "challenge.created",
      aggregate_id: fn %{challenge: challenge} -> challenge.id end,
      payload: fn %{challenge: challenge} -> challenge_payload(challenge) end
    )
    |> Repo.transaction()
    |> case do
      {:ok, %{challenge: challenge}} -> {:ok, challenge}
      {:error, :challenge, changeset, _changes} -> {:error, changeset}
      {:error, _step, reason, _changes} -> {:error, reason}
    end
  end

  @doc """
  Creates or updates a challenge using `external_id` as idempotency key.
  """
  @spec upsert_challenge(map()) ::
          {:ok, Challenge.t()} | {:error, Ecto.Changeset.t() | :missing_external_id}
  def upsert_challenge(attrs) do
    attrs = normalize_attrs(attrs)

    case attrs[:external_id] do
      nil ->
        {:error, :missing_external_id}

      external_id ->
        case get_challenge_by_external_id(external_id) do
          nil ->
            create_challenge(attrs)

          challenge ->
            update_challenge_record(challenge, attrs)
        end
    end
  end

  @doc """
  Updates an existing challenge.

  Returns `{:error, :not_found}` if the challenge does not exist.

  ## Examples

      iex> update_challenge("valid-uuid", %{name: "UpdatedName"})
      {:ok, %Challenge{}}

      iex> update_challenge("invalid-uuid", %{name: "UpdatedName"})
      {:error, :not_found}

      iex> update_challenge("valid-uuid", %{name: "ab"})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_challenge(Ecto.UUID.t(), map()) ::
          {:ok, Challenge.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def update_challenge(challenge_id, attrs) do
    case get_challenge(challenge_id) do
      nil ->
        {:error, :not_found}

      challenge ->
        update_challenge_record(challenge, attrs)
    end
  end

  @doc """
  Deletes a challenge.

  Returns `{:error, :not_found}` if the challenge does not exist.
  Returns `{:error, :has_associations}` if the challenge has campaign associations.

  ## Examples

      iex> delete_challenge("valid-uuid-without-associations")
      {:ok, %Challenge{}}

      iex> delete_challenge("valid-uuid-with-associations")
      {:error, :has_associations}

      iex> delete_challenge("invalid-uuid")
      {:error, :not_found}

  """
  @spec delete_challenge(Ecto.UUID.t()) ::
          {:ok, Challenge.t()} | {:error, :not_found | :has_associations}
  def delete_challenge(challenge_id) do
    case get_challenge(challenge_id) do
      nil ->
        {:error, :not_found}

      challenge ->
        if has_campaign_associations?(challenge.id) do
          {:error, :has_associations}
        else
          Multi.new()
          |> Multi.delete(:challenge, challenge)
          |> Outbox.enqueue_multi(:challenge_deleted,
            aggregate_type: "challenge",
            event_type: "challenge.deleted",
            aggregate_id: fn %{challenge: deleted_challenge} -> deleted_challenge.id end,
            payload: fn %{challenge: deleted_challenge} ->
              challenge_payload(deleted_challenge)
            end
          )
          |> Repo.transaction()
          |> case do
            {:ok, %{challenge: deleted_challenge}} -> {:ok, deleted_challenge}
            {:error, :challenge, reason, _changes} -> {:error, reason}
            {:error, _step, reason, _changes} -> {:error, reason}
          end
        end
    end
  end

  # Private Helpers

  defp has_campaign_associations?(challenge_id) do
    Repo.exists?(from(cc in CampaignChallenge, where: cc.challenge_id == ^challenge_id))
  end

  defp get_challenge_by_external_id(external_id) do
    Repo.get_by(Challenge, external_id: external_id)
  end

  defp ensure_external_id(attrs) do
    external_id = get_field(attrs, :external_id) || Ecto.UUID.generate()

    attrs
    |> Map.new()
    |> Map.put(:external_id, external_id)
  end

  defp normalize_attrs(attrs) do
    %{
      external_id: get_field(attrs, :external_id),
      name: get_field(attrs, :name),
      description: get_field(attrs, :description),
      metadata: get_field(attrs, :metadata)
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp get_field(attrs, key) do
    Map.get(attrs, key) || Map.get(attrs, Atom.to_string(key))
  end

  defp update_challenge_record(challenge, attrs) do
    Multi.new()
    |> Multi.update(:challenge, Challenge.changeset(challenge, attrs))
    |> Outbox.enqueue_multi(:challenge_updated,
      aggregate_type: "challenge",
      event_type: "challenge.updated",
      aggregate_id: fn %{challenge: updated_challenge} -> updated_challenge.id end,
      payload: fn %{challenge: updated_challenge} -> challenge_payload(updated_challenge) end
    )
    |> Repo.transaction()
    |> case do
      {:ok, %{challenge: updated_challenge}} -> {:ok, updated_challenge}
      {:error, :challenge, changeset, _changes} -> {:error, changeset}
      {:error, _step, reason, _changes} -> {:error, reason}
    end
  end

  defp challenge_payload(challenge) do
    %{
      id: challenge.id,
      external_id: challenge.external_id,
      name: challenge.name,
      description: challenge.description,
      metadata: challenge.metadata,
      inserted_at: challenge.inserted_at,
      updated_at: challenge.updated_at
    }
  end
end
