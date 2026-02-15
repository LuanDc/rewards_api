defmodule CampaignsApiWeb.ChallengeController do
  @moduledoc """
  Controller for Challenge API endpoints.
  Provides read-only access to challenges (list and get by ID).
  """

  use CampaignsApiWeb, :controller
  use PhoenixSwagger

  alias CampaignsApi.Challenges

  def swagger_definitions do
    %{
      Challenge:
        swagger_schema do
          title("Challenge")
          description("A reusable challenge evaluation mechanism")

          properties do
            id(:string, "Challenge UUID", required: true, format: "uuid")
            name(:string, "Challenge name", required: true, minLength: 3)
            description(:string, "Challenge description")
            metadata(:object, "Challenge metadata (flexible JSONB)")
            inserted_at(:string, "Creation timestamp", format: "date-time")
            updated_at(:string, "Last update timestamp", format: "date-time")
          end

          example(%{
            id: "550e8400-e29b-41d4-a716-446655440000",
            name: "TransactionChecker",
            description: "Validates customer transaction patterns",
            metadata: %{
              "type" => "transaction_validation",
              "threshold" => 100
            },
            inserted_at: "2024-05-01T10:00:00Z",
            updated_at: "2024-05-01T10:00:00Z"
          })
        end,
      ChallengeListResponse:
        swagger_schema do
          title("Challenge List Response")
          description("Paginated list of challenges")

          properties do
            data(Schema.array(:Challenge), "List of challenges")
            next_cursor(:string, "Cursor for next page (null if no more pages)", format: "date-time", "x-nullable": true)
            has_more(:boolean, "Whether more results are available")
          end

          example(%{
            data: [
              %{
                id: "550e8400-e29b-41d4-a716-446655440000",
                name: "TransactionChecker",
                description: "Validates customer transaction patterns"
              }
            ],
            next_cursor: "2024-05-01T10:00:00Z",
            has_more: true
          })
        end
    }
  end

  swagger_path :index do
    get("/challenges")
    summary("List challenges")
    description("Returns a paginated list of all available challenges")
    tag("Challenge Management")
    security([%{Bearer: []}])

    parameters do
      limit(:query, :integer, "Number of records to return (max: 100)", required: false)
      cursor(:query, :string, "Cursor for pagination (ISO8601 datetime)", required: false)
    end

    response(200, "Success", Schema.ref(:ChallengeListResponse))
    response(401, "Unauthorized", Schema.ref(:ErrorResponse))
    response(403, "Forbidden", Schema.ref(:ErrorResponse))
  end

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, params) do
    opts = [
      limit: parse_int(params["limit"]),
      cursor: parse_datetime(params["cursor"])
    ]

    result = Challenges.list_challenges(opts)
    json(conn, result)
  end

  swagger_path :show do
    get("/challenges/{id}")
    summary("Get challenge")
    description("Returns a single challenge by ID")
    tag("Challenge Management")
    security([%{Bearer: []}])

    parameters do
      id(:path, :string, "Challenge ID", required: true, format: "uuid")
    end

    response(200, "Success", Schema.ref(:Challenge))
    response(401, "Unauthorized", Schema.ref(:ErrorResponse))
    response(403, "Forbidden", Schema.ref(:ErrorResponse))
    response(404, "Not Found", Schema.ref(:ErrorResponse))
  end

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    case Challenges.get_challenge(id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Challenge not found"})

      challenge ->
        json(conn, challenge)
    end
  end

  @spec parse_int(String.t() | integer() | nil) :: integer() | nil
  defp parse_int(nil), do: nil
  defp parse_int(""), do: nil

  defp parse_int(str) when is_binary(str) do
    case Integer.parse(str) do
      {int, _} -> int
      :error -> nil
    end
  end

  defp parse_int(int) when is_integer(int), do: int

  @spec parse_datetime(String.t() | nil) :: DateTime.t() | nil
  defp parse_datetime(nil), do: nil

  defp parse_datetime(str) when is_binary(str) do
    case DateTime.from_iso8601(str) do
      {:ok, dt, _} -> dt
      _ -> nil
    end
  end
end
