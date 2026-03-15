defmodule BackofficeApi.ChallengeManagement do
  @moduledoc """
  Challenge CRUD operations managed by backoffice.
  """

  import Ecto.Query

  alias BackofficeApi.ChallengeManagement.Challenge
  alias BackofficeApi.Repo
  alias BackofficeApi.Workers.PublishChallengeWorker
  alias Ecto.Multi

  @type create_error :: Ecto.Changeset.t() | {:enqueue_failed, Ecto.Changeset.t()}

  @spec list_challenges() :: [Challenge.t()]
  def list_challenges do
    Repo.all(from(c in Challenge, order_by: [desc: c.inserted_at]))
  end

  @spec get_challenge(Ecto.UUID.t()) :: Challenge.t() | nil
  def get_challenge(challenge_id) do
    Repo.get(Challenge, challenge_id)
  end

  @spec create_challenge(map()) :: {:ok, Challenge.t()} | {:error, create_error()}
  def create_challenge(attrs) do
    attrs = ensure_external_id(attrs)

    changeset = Challenge.changeset(%Challenge{}, attrs)

    Multi.new()
    |> Multi.insert(:challenge, changeset)
    |> Oban.insert(:publish_challenge_job, fn %{challenge: challenge} ->
      PublishChallengeWorker.new(%{"challenge" => challenge_payload(challenge)})
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{challenge: challenge}} ->
        {:ok, challenge}

      {:error, :challenge, %Ecto.Changeset{} = changeset, _changes_so_far} ->
        {:error, changeset}

      {:error, :publish_challenge_job, %Ecto.Changeset{} = changeset, _changes_so_far} ->
        {:error, {:enqueue_failed, changeset}}
    end
  end

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

  @spec delete_challenge(Ecto.UUID.t()) :: {:ok, Challenge.t()} | {:error, :not_found}
  def delete_challenge(challenge_id) do
    case get_challenge(challenge_id) do
      nil ->
        {:error, :not_found}

      challenge ->
        Repo.delete(challenge)
    end
  end

  defp ensure_external_id(attrs) do
    external_id = get_field(attrs, :external_id) || Ecto.UUID.generate()

    attrs
    |> Enum.into(%{}, fn {key, value} -> {to_string(key), value} end)
    |> Map.put("external_id", external_id)
  end

  defp challenge_payload(challenge) do
    %{
      external_id: challenge.external_id,
      name: challenge.name,
      description: challenge.description,
      metadata: challenge.metadata || %{}
    }
  end

  defp get_field(map, key) when is_map(map) do
    Map.get(map, key) || Map.get(map, Atom.to_string(key))
  end
end
