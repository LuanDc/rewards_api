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
  alias CampaignsApi.Pagination
  alias CampaignsApi.Repo

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
  @spec list_challenges(Pagination.pagination_opts()) :: Pagination.pagination_result(Challenge.t())
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

    %Challenge{}
    |> Challenge.changeset(attrs)
    |> Repo.insert()
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
            challenge
            |> Challenge.changeset(attrs)
            |> Repo.update()
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
        challenge
        |> Challenge.changeset(attrs)
        |> Repo.update()
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
          Repo.delete(challenge)
        end
    end
  end

  # Private Helpers

  @spec has_campaign_associations?(Ecto.UUID.t()) :: boolean()
  defp has_campaign_associations?(challenge_id) do
    Repo.exists?(from cc in CampaignChallenge, where: cc.challenge_id == ^challenge_id)
  end

  @spec get_challenge_by_external_id(String.t()) :: Challenge.t() | nil
  defp get_challenge_by_external_id(external_id) do
    Repo.get_by(Challenge, external_id: external_id)
  end

  @spec ensure_external_id(map()) :: %{required(:external_id) => term()}
  defp ensure_external_id(attrs) do
    external_id = get_field(attrs, :external_id) || Ecto.UUID.generate()

    attrs
    |> Map.new()
    |> Map.put(:external_id, external_id)
  end

  @spec normalize_attrs(map()) :: map()
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

  @spec get_field(map(), :description | :external_id | :metadata | :name) :: term()
  defp get_field(attrs, key) do
    Map.get(attrs, key) || Map.get(attrs, Atom.to_string(key))
  end
end
