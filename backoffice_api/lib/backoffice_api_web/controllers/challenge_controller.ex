defmodule BackofficeApiWeb.ChallengeController do
  use BackofficeApiWeb, :controller

  alias BackofficeApi.ChallengeManagement

  def index(conn, _params) do
    challenges = ChallengeManagement.list_challenges()
    json(conn, %{data: challenges})
  end

  def show(conn, %{"id" => challenge_id}) do
    case ChallengeManagement.get_challenge(challenge_id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Challenge not found"})

      challenge ->
        json(conn, challenge)
    end
  end

  def create(conn, params) do
    attrs = extract_challenge_attrs(params)

    case ChallengeManagement.create_challenge(attrs) do
      {:ok, challenge} ->
        conn
        |> put_status(:created)
        |> json(challenge)

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: translate_errors(changeset)})

      {:error, {:enqueue_failed, _changeset}} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Could not enqueue challenge publication"})
    end
  end

  def update(conn, %{"id" => challenge_id} = params) do
    attrs = extract_challenge_attrs(params)

    case ChallengeManagement.update_challenge(challenge_id, attrs) do
      {:ok, challenge} ->
        json(conn, challenge)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Challenge not found"})

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: translate_errors(changeset)})
    end
  end

  def delete(conn, %{"id" => challenge_id}) do
    case ChallengeManagement.delete_challenge(challenge_id) do
      {:ok, _challenge} ->
        send_resp(conn, :no_content, "")

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Challenge not found"})
    end
  end

  defp extract_challenge_attrs(%{"challenge" => challenge_params})
       when is_map(challenge_params) do
    challenge_params
  end

  defp extract_challenge_attrs(params) when is_map(params) do
    params
    |> Map.drop(["id"])
  end

  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
