defmodule CampaignsApiWeb.ParticipantController do
  @moduledoc """
  REST API controller for participant management operations.

  Provides endpoints for:
  - Participant CRUD operations (create, read, update, delete)
  - Campaign-participant associations (associate, disassociate, list)
  - Participant-challenge associations (associate, disassociate, list)

  All operations enforce tenant isolation, ensuring participants can only
  access and manage data within their own tenant context.

  ## Authentication

  All endpoints require authentication via Bearer token. The tenant context
  is extracted from the authenticated user and used to scope all operations.

  ## Pagination

  List endpoints support cursor-based pagination with the following parameters:
  - `limit`: Number of records to return (default: 50, max: 100)
  - `cursor`: ISO8601 datetime cursor for pagination

  ## Error Handling

  The controller returns appropriate HTTP status codes:
  - 200: Success (GET, PUT, DELETE)
  - 201: Created (POST)
  - 204: No Content (DELETE)
  - 401: Unauthorized (missing or invalid authentication)
  - 403: Forbidden (tenant mismatch)
  - 404: Not Found (resource doesn't exist)
  - 422: Unprocessable Entity (validation errors)
  """

  use CampaignsApiWeb, :controller
  use PhoenixSwagger

  alias CampaignsApi.CampaignManagement

  swagger_path :index do
    get("/participants")
    summary("List participants")
    description("Returns a paginated list of participants for the authenticated tenant")
    tag("Participant Management")
    security([%{Bearer: []}])

    parameters do
      limit(:query, :integer, "Number of records to return (max: 100)", required: false)
      cursor(:query, :string, "Cursor for pagination (ISO8601 datetime)", required: false)

      nickname(:query, :string, "Filter by nickname (case-insensitive substring match)",
        required: false
      )
    end

    response(200, "Success", Schema.ref(:ParticipantListResponse))
    response(401, "Unauthorized", Schema.ref(:ErrorResponse))
    response(403, "Forbidden", Schema.ref(:ErrorResponse))
  end

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, params) do
    tenant_id = conn.assigns.tenant_id

    opts = [
      limit: parse_int(params["limit"]),
      cursor: parse_datetime(params["cursor"]),
      nickname: params["nickname"]
    ]

    result = CampaignManagement.list_participants(tenant_id, opts)
    json(conn, result)
  end

  swagger_path :create do
    post("/participants")
    summary("Create participant")
    description("Creates a new participant for the authenticated tenant")
    tag("Participant Management")
    security([%{Bearer: []}])

    parameters do
      participant(:body, Schema.ref(:ParticipantRequest), "Participant attributes",
        required: true
      )
    end

    response(201, "Created", Schema.ref(:Participant))
    response(401, "Unauthorized", Schema.ref(:ErrorResponse))
    response(403, "Forbidden", Schema.ref(:ErrorResponse))
    response(422, "Validation Error", Schema.ref(:ValidationErrorResponse))
  end

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, params) do
    tenant_id = conn.assigns.tenant_id
    attrs = atomize_keys(params)

    case CampaignManagement.create_participant(tenant_id, attrs) do
      {:ok, participant} ->
        conn
        |> put_status(:created)
        |> json(participant)

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: translate_errors(changeset)})
    end
  end

  swagger_path :show do
    get("/participants/{id}")
    summary("Get participant")
    description("Returns a single participant by ID for the authenticated tenant")
    tag("Participant Management")
    security([%{Bearer: []}])

    parameters do
      id(:path, :string, "Participant ID", required: true, format: "uuid")
    end

    response(200, "Success", Schema.ref(:Participant))
    response(401, "Unauthorized", Schema.ref(:ErrorResponse))
    response(403, "Forbidden", Schema.ref(:ErrorResponse))
    response(404, "Not Found", Schema.ref(:ErrorResponse))
  end

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    tenant_id = conn.assigns.tenant_id

    case CampaignManagement.get_participant(tenant_id, id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Participant not found"})

      participant ->
        json(conn, participant)
    end
  end

  swagger_path :update do
    put("/participants/{id}")
    summary("Update participant")
    description("Updates an existing participant for the authenticated tenant")
    tag("Participant Management")
    security([%{Bearer: []}])

    parameters do
      id(:path, :string, "Participant ID", required: true, format: "uuid")

      participant(:body, Schema.ref(:ParticipantRequest), "Participant attributes",
        required: true
      )
    end

    response(200, "Success", Schema.ref(:Participant))
    response(401, "Unauthorized", Schema.ref(:ErrorResponse))
    response(403, "Forbidden", Schema.ref(:ErrorResponse))
    response(404, "Not Found", Schema.ref(:ErrorResponse))
    response(422, "Validation Error", Schema.ref(:ValidationErrorResponse))
  end

  @spec update(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update(conn, %{"id" => id} = params) do
    tenant_id = conn.assigns.tenant_id
    attrs = atomize_keys(params)

    case CampaignManagement.update_participant(tenant_id, id, attrs) do
      {:ok, participant} ->
        json(conn, participant)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Participant not found"})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: translate_errors(changeset)})
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/participants/{id}")
    summary("Delete participant")
    description("Permanently deletes a participant for the authenticated tenant")
    tag("Participant Management")
    security([%{Bearer: []}])

    parameters do
      id(:path, :string, "Participant ID", required: true, format: "uuid")
    end

    response(200, "Success", Schema.ref(:Participant))
    response(401, "Unauthorized", Schema.ref(:ErrorResponse))
    response(403, "Forbidden", Schema.ref(:ErrorResponse))
    response(404, "Not Found", Schema.ref(:ErrorResponse))
  end

  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    tenant_id = conn.assigns.tenant_id

    case CampaignManagement.delete_participant(tenant_id, id) do
      {:ok, participant} ->
        json(conn, participant)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Participant not found"})
    end
  end

  swagger_path :associate_campaign do
    post("/participants/{participant_id}/campaigns/{campaign_id}")
    summary("Associate participant with campaign")

    description(
      "Creates an association between a participant and a campaign within the authenticated tenant"
    )

    tag("Participant Management")
    security([%{Bearer: []}])

    parameters do
      participant_id(:path, :string, "Participant ID", required: true, format: "uuid")
      campaign_id(:path, :string, "Campaign ID", required: true, format: "uuid")
    end

    response(201, "Created", Schema.ref(:CampaignParticipant))
    response(401, "Unauthorized", Schema.ref(:ErrorResponse))
    response(403, "Forbidden - Tenant mismatch", Schema.ref(:ErrorResponse))
    response(422, "Validation Error", Schema.ref(:ValidationErrorResponse))
  end

  @spec associate_campaign(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def associate_campaign(conn, %{"participant_id" => participant_id, "campaign_id" => campaign_id}) do
    tenant_id = conn.assigns.tenant_id

    case CampaignManagement.associate_participant_with_campaign(
           tenant_id,
           participant_id,
           campaign_id
         ) do
      {:ok, association} ->
        conn
        |> put_status(:created)
        |> json(association)

      {:error, :tenant_mismatch} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Participant or campaign not found in tenant"})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: translate_errors(changeset)})
    end
  end

  swagger_path :disassociate_campaign do
    PhoenixSwagger.Path.delete("/participants/{participant_id}/campaigns/{campaign_id}")
    summary("Disassociate participant from campaign")

    description(
      "Removes the association between a participant and a campaign within the authenticated tenant. All participant-challenge associations for this campaign will also be removed."
    )

    tag("Participant Management")
    security([%{Bearer: []}])

    parameters do
      participant_id(:path, :string, "Participant ID", required: true, format: "uuid")
      campaign_id(:path, :string, "Campaign ID", required: true, format: "uuid")
    end

    response(200, "Success", Schema.ref(:CampaignParticipant))
    response(401, "Unauthorized", Schema.ref(:ErrorResponse))
    response(403, "Forbidden", Schema.ref(:ErrorResponse))
    response(404, "Not Found", Schema.ref(:ErrorResponse))
  end

  @spec disassociate_campaign(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def disassociate_campaign(conn, %{
        "participant_id" => participant_id,
        "campaign_id" => campaign_id
      }) do
    tenant_id = conn.assigns.tenant_id

    case CampaignManagement.disassociate_participant_from_campaign(
           tenant_id,
           participant_id,
           campaign_id
         ) do
      {:ok, association} ->
        json(conn, association)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Association not found"})
    end
  end

  swagger_path :list_campaigns do
    get("/participants/{participant_id}/campaigns")
    summary("List campaigns for participant")
    description("Returns a paginated list of campaigns that a participant is enrolled in")
    tag("Participant Management")
    security([%{Bearer: []}])

    parameters do
      participant_id(:path, :string, "Participant ID", required: true, format: "uuid")
      limit(:query, :integer, "Number of records to return (max: 100)", required: false)
      cursor(:query, :string, "Cursor for pagination (ISO8601 datetime)", required: false)
    end

    response(200, "Success", Schema.ref(:CampaignListResponse))
    response(401, "Unauthorized", Schema.ref(:ErrorResponse))
    response(403, "Forbidden", Schema.ref(:ErrorResponse))
  end

  @spec list_campaigns(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def list_campaigns(conn, %{"participant_id" => participant_id} = params) do
    tenant_id = conn.assigns.tenant_id

    opts = [
      limit: parse_int(params["limit"]),
      cursor: parse_datetime(params["cursor"])
    ]

    result = CampaignManagement.list_campaigns_for_participant(tenant_id, participant_id, opts)
    json(conn, result)
  end

  swagger_path :list_participants do
    get("/campaigns/{campaign_id}/participants")
    summary("List participants for campaign")
    description("Returns a paginated list of participants enrolled in a specific campaign")
    tag("Participant Management")
    security([%{Bearer: []}])

    parameters do
      campaign_id(:path, :string, "Campaign ID", required: true, format: "uuid")
      limit(:query, :integer, "Number of records to return (max: 100)", required: false)
      cursor(:query, :string, "Cursor for pagination (ISO8601 datetime)", required: false)
    end

    response(200, "Success", Schema.ref(:ParticipantListResponse))
    response(401, "Unauthorized", Schema.ref(:ErrorResponse))
    response(403, "Forbidden", Schema.ref(:ErrorResponse))
  end

  @spec list_participants(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def list_participants(conn, %{"campaign_id" => campaign_id} = params) do
    tenant_id = conn.assigns.tenant_id

    opts = [
      limit: parse_int(params["limit"]),
      cursor: parse_datetime(params["cursor"])
    ]

    result = CampaignManagement.list_participants_for_campaign(tenant_id, campaign_id, opts)
    json(conn, result)
  end

  swagger_path :associate_challenge do
    post("/participants/{participant_id}/challenges/{challenge_id}")
    summary("Associate participant with challenge")

    description(
      "Creates an association between a participant and a challenge within the authenticated tenant. The participant must already be associated with the challenge's campaign."
    )

    tag("Participant Management")
    security([%{Bearer: []}])

    parameters do
      participant_id(:path, :string, "Participant ID", required: true, format: "uuid")
      challenge_id(:path, :string, "Challenge ID", required: true, format: "uuid")
    end

    response(201, "Created", Schema.ref(:ParticipantChallenge))
    response(401, "Unauthorized", Schema.ref(:ErrorResponse))
    response(403, "Forbidden - Tenant mismatch", Schema.ref(:ErrorResponse))

    response(
      422,
      "Validation Error - Participant not in campaign or duplicate association",
      Schema.ref(:ValidationErrorResponse)
    )
  end

  @spec associate_challenge(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def associate_challenge(conn, %{
        "participant_id" => participant_id,
        "challenge_id" => challenge_id
      }) do
    tenant_id = conn.assigns.tenant_id

    case CampaignManagement.associate_participant_with_challenge(
           tenant_id,
           participant_id,
           challenge_id
         ) do
      {:ok, association} ->
        conn
        |> put_status(:created)
        |> json(association)

      {:error, :tenant_mismatch} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Participant or challenge not found in tenant"})

      {:error, :participant_not_in_campaign} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Participant not associated with challenge's campaign"})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: translate_errors(changeset)})
    end
  end

  swagger_path :disassociate_challenge do
    PhoenixSwagger.Path.delete("/participants/{participant_id}/challenges/{challenge_id}")
    summary("Disassociate participant from challenge")

    description(
      "Removes the association between a participant and a challenge within the authenticated tenant"
    )

    tag("Participant Management")
    security([%{Bearer: []}])

    parameters do
      participant_id(:path, :string, "Participant ID", required: true, format: "uuid")
      challenge_id(:path, :string, "Challenge ID", required: true, format: "uuid")
    end

    response(200, "Success", Schema.ref(:ParticipantChallenge))
    response(401, "Unauthorized", Schema.ref(:ErrorResponse))
    response(403, "Forbidden", Schema.ref(:ErrorResponse))
    response(404, "Not Found", Schema.ref(:ErrorResponse))
  end

  @spec disassociate_challenge(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def disassociate_challenge(conn, %{
        "participant_id" => participant_id,
        "challenge_id" => challenge_id
      }) do
    tenant_id = conn.assigns.tenant_id

    case CampaignManagement.disassociate_participant_from_challenge(
           tenant_id,
           participant_id,
           challenge_id
         ) do
      {:ok, association} ->
        json(conn, association)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Association not found"})
    end
  end

  swagger_path :list_challenges do
    get("/participants/{participant_id}/challenges")
    summary("List challenges for participant")

    description(
      "Returns a paginated list of challenges that a participant is enrolled in. Optionally filter by campaign_id to show only challenges from a specific campaign."
    )

    tag("Participant Management")
    security([%{Bearer: []}])

    parameters do
      participant_id(:path, :string, "Participant ID", required: true, format: "uuid")
      limit(:query, :integer, "Number of records to return (max: 100)", required: false)
      cursor(:query, :string, "Cursor for pagination (ISO8601 datetime)", required: false)
      campaign_id(:query, :string, "Filter by campaign ID", required: false, format: "uuid")
    end

    response(200, "Success", Schema.ref(:ChallengeListResponse))
    response(401, "Unauthorized", Schema.ref(:ErrorResponse))
    response(403, "Forbidden", Schema.ref(:ErrorResponse))
  end

  @spec list_challenges(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def list_challenges(conn, %{"participant_id" => participant_id} = params) do
    tenant_id = conn.assigns.tenant_id

    opts = [
      limit: parse_int(params["limit"]),
      cursor: parse_datetime(params["cursor"]),
      campaign_id: params["campaign_id"]
    ]

    result = CampaignManagement.list_challenges_for_participant(tenant_id, participant_id, opts)
    json(conn, result)
  end

  swagger_path :list_challenge_participants do
    get("/challenges/{challenge_id}/participants")
    summary("List participants for challenge")
    description("Returns a paginated list of participants enrolled in a specific challenge")
    tag("Participant Management")
    security([%{Bearer: []}])

    parameters do
      challenge_id(:path, :string, "Challenge ID", required: true, format: "uuid")
      limit(:query, :integer, "Number of records to return (max: 100)", required: false)
      cursor(:query, :string, "Cursor for pagination (ISO8601 datetime)", required: false)
    end

    response(200, "Success", Schema.ref(:ParticipantListResponse))
    response(401, "Unauthorized", Schema.ref(:ErrorResponse))
    response(403, "Forbidden", Schema.ref(:ErrorResponse))
  end

  @spec list_challenge_participants(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def list_challenge_participants(conn, %{"challenge_id" => challenge_id} = params) do
    tenant_id = conn.assigns.tenant_id

    opts = [
      limit: parse_int(params["limit"]),
      cursor: parse_datetime(params["cursor"])
    ]

    result = CampaignManagement.list_participants_for_challenge(tenant_id, challenge_id, opts)
    json(conn, result)
  end

  def swagger_definitions do
    %{
      Participant:
        swagger_schema do
          title("Participant")
          description("A participant who can participate in campaigns and challenges")

          properties do
            id(:string, "Participant UUID", required: true, format: "uuid")
            name(:string, "Participant full name", required: true, minLength: 1)
            nickname(:string, "Unique participant identifier", required: true, minLength: 3)
            tenant_id(:string, "Tenant ID", required: true)

            status(:string, "Participant status",
              enum: [:active, :inactive, :ineligible],
              default: :active
            )

            inserted_at(:string, "Creation timestamp", format: "date-time")
            updated_at(:string, "Last update timestamp", format: "date-time")
          end

          example(%{
            id: "550e8400-e29b-41d4-a716-446655440000",
            name: "John Doe",
            nickname: "johndoe",
            tenant_id: "tenant-123",
            status: "active",
            inserted_at: "2024-05-01T10:00:00Z",
            updated_at: "2024-05-01T10:00:00Z"
          })
        end,
      ParticipantRequest:
        swagger_schema do
          title("Participant Request")
          description("Participant creation/update request")

          properties do
            name(:string, "Participant full name", required: true, minLength: 1)
            nickname(:string, "Unique participant identifier", required: true, minLength: 3)
            status(:string, "Participant status", enum: [:active, :inactive, :ineligible])
          end

          example(%{
            name: "John Doe",
            nickname: "johndoe",
            status: "active"
          })
        end,
      ParticipantListResponse:
        swagger_schema do
          title("Participant List Response")
          description("Paginated list of participants")

          properties do
            data(Schema.array(:Participant), "List of participants")

            next_cursor(:string, "Cursor for next page (null if no more pages)",
              format: "date-time",
              "x-nullable": true
            )

            has_more(:boolean, "Whether more results are available")
          end

          example(%{
            data: [
              %{
                id: "550e8400-e29b-41d4-a716-446655440000",
                name: "John Doe",
                nickname: "johndoe",
                tenant_id: "tenant-123",
                status: "active"
              }
            ],
            next_cursor: "2024-05-01T10:00:00Z",
            has_more: true
          })
        end,
      Campaign:
        swagger_schema do
          title("Campaign")
          description("A reward campaign")

          properties do
            id(:string, "Campaign UUID", required: true, format: "uuid")
            name(:string, "Campaign name", required: true)
            description(:string, "Campaign description")
            tenant_id(:string, "Tenant ID", required: true)
            inserted_at(:string, "Creation timestamp", format: "date-time")
            updated_at(:string, "Last update timestamp", format: "date-time")
          end

          example(%{
            id: "770e8400-e29b-41d4-a716-446655440002",
            name: "Summer Campaign",
            description: "Summer rewards campaign",
            tenant_id: "tenant-123",
            inserted_at: "2024-05-01T10:00:00Z",
            updated_at: "2024-05-01T10:00:00Z"
          })
        end,
      CampaignListResponse:
        swagger_schema do
          title("Campaign List Response")
          description("Paginated list of campaigns")

          properties do
            data(Schema.array(:Campaign), "List of campaigns")

            next_cursor(:string, "Cursor for next page (null if no more pages)",
              format: "date-time",
              "x-nullable": true
            )

            has_more(:boolean, "Whether more results are available")
          end

          example(%{
            data: [
              %{
                id: "770e8400-e29b-41d4-a716-446655440002",
                name: "Summer Campaign",
                description: "Summer rewards campaign",
                tenant_id: "tenant-123"
              }
            ],
            next_cursor: "2024-05-01T10:00:00Z",
            has_more: true
          })
        end,
      CampaignParticipant:
        swagger_schema do
          title("Campaign Participant")
          description("Association between a participant and a campaign")

          properties do
            id(:string, "Association UUID", required: true, format: "uuid")
            participant_id(:string, "Participant UUID", required: true, format: "uuid")
            campaign_id(:string, "Campaign UUID", required: true, format: "uuid")
            inserted_at(:string, "Creation timestamp", format: "date-time")
            updated_at(:string, "Last update timestamp", format: "date-time")
          end

          example(%{
            id: "550e8400-e29b-41d4-a716-446655440000",
            participant_id: "660e8400-e29b-41d4-a716-446655440001",
            campaign_id: "770e8400-e29b-41d4-a716-446655440002",
            inserted_at: "2024-05-01T10:00:00Z",
            updated_at: "2024-05-01T10:00:00Z"
          })
        end,
      ParticipantChallenge:
        swagger_schema do
          title("Participant Challenge")
          description("Association between a participant and a challenge within a campaign")

          properties do
            id(:string, "Association UUID", required: true, format: "uuid")
            participant_id(:string, "Participant UUID", required: true, format: "uuid")
            challenge_id(:string, "Challenge UUID", required: true, format: "uuid")
            campaign_id(:string, "Campaign UUID for context", required: true, format: "uuid")
            inserted_at(:string, "Creation timestamp", format: "date-time")
            updated_at(:string, "Last update timestamp", format: "date-time")
          end

          example(%{
            id: "550e8400-e29b-41d4-a716-446655440000",
            participant_id: "660e8400-e29b-41d4-a716-446655440001",
            challenge_id: "770e8400-e29b-41d4-a716-446655440002",
            campaign_id: "880e8400-e29b-41d4-a716-446655440003",
            inserted_at: "2024-05-01T10:00:00Z",
            updated_at: "2024-05-01T10:00:00Z"
          })
        end,
      Challenge:
        swagger_schema do
          title("Challenge")
          description("A reusable challenge evaluation mechanism")

          properties do
            id(:string, "Challenge UUID", required: true, format: "uuid")
            name(:string, "Challenge name", required: true, minLength: 3)
            description(:string, "Challenge description")
            metadata(:object, "Challenge metadata")
            inserted_at(:string, "Creation timestamp", format: "date-time")
            updated_at(:string, "Last update timestamp", format: "date-time")
          end

          example(%{
            id: "990e8400-e29b-41d4-a716-446655440004",
            name: "Daily Login Challenge",
            description: "Log in daily for 7 consecutive days",
            metadata: %{"type" => "evaluation", "points" => 100},
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

            next_cursor(:string, "Cursor for next page (null if no more pages)",
              format: "date-time",
              "x-nullable": true
            )

            has_more(:boolean, "Whether more results are available")
          end

          example(%{
            data: [
              %{
                id: "990e8400-e29b-41d4-a716-446655440004",
                name: "Daily Login Challenge",
                description: "Log in daily for 7 consecutive days",
                metadata: %{"type" => "evaluation"}
              }
            ],
            next_cursor: "2024-05-01T10:00:00Z",
            has_more: true
          })
        end,
      ErrorResponse:
        swagger_schema do
          title("Error Response")
          description("Error response")

          properties do
            error(:string, "Error message")
          end

          example(%{
            error: "Participant not found"
          })
        end,
      ValidationErrorResponse:
        swagger_schema do
          title("Validation Error Response")
          description("Validation error response")

          properties do
            errors(:object, "Validation errors by field")
          end

          example(%{
            errors: %{
              name: ["can't be blank"],
              nickname: ["should be at least 3 character(s)"]
            }
          })
        end
    }
  end

  @spec translate_errors(Ecto.Changeset.t()) :: map()
  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

  @spec atomize_keys(map()) :: map()
  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn
      {key, value} when is_binary(key) ->
        if key == "id" do
          {key, value}
        else
          {String.to_existing_atom(key), value}
        end

      {key, value} ->
        {key, value}
    end)
    |> Map.delete("id")
  rescue
    ArgumentError ->
      map
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
