defmodule CampaignsApiWeb.CampaignChallengeController do
  @moduledoc """
  Controller for managing campaign challenge associations.

  Handles CRUD operations for associating challenges with campaigns,
  with tenant isolation enforced through campaign ownership.
  """

  use CampaignsApiWeb, :controller
  use PhoenixSwagger

  alias CampaignsApi.CampaignManagement

  def swagger_definitions do
    %{
      CampaignChallenge:
        swagger_schema do
          title("Campaign Challenge")
          description("Association between a campaign and a challenge with configuration")

          properties do
            id(:string, "Campaign Challenge UUID", required: true, format: "uuid")
            campaign_id(:string, "Campaign UUID", required: true, format: "uuid")
            challenge_id(:string, "Challenge UUID", required: true, format: "uuid")
            display_name(:string, "Display name for the challenge", required: true, minLength: 3)
            display_description(:string, "Display description for the challenge")

            evaluation_frequency(
              :string,
              "Evaluation frequency (cron expression or keyword)",
              required: true
            )

            reward_points(:integer, "Reward points (can be positive, negative, or zero)", required: true)
            configuration(:object, "Additional configuration as JSON")
            inserted_at(:string, "Creation timestamp", format: "date-time")
            updated_at(:string, "Last update timestamp", format: "date-time")
          end

          example(%{
            id: "550e8400-e29b-41d4-a716-446655440000",
            campaign_id: "660e8400-e29b-41d4-a716-446655440001",
            challenge_id: "770e8400-e29b-41d4-a716-446655440002",
            display_name: "Buy+ Challenge",
            display_description: "Earn points for purchases",
            evaluation_frequency: "daily",
            reward_points: 100,
            configuration: %{"threshold" => 10},
            inserted_at: "2024-05-01T10:00:00Z",
            updated_at: "2024-05-01T10:00:00Z"
          })
        end,
      CampaignChallengeRequest:
        swagger_schema do
          title("Campaign Challenge Request")
          description("Campaign challenge creation/update request")

          properties do
            challenge_id(:string, "Challenge UUID", required: true, format: "uuid")
            display_name(:string, "Display name for the challenge", required: true, minLength: 3)
            display_description(:string, "Display description for the challenge")

            evaluation_frequency(
              :string,
              "Evaluation frequency (daily, weekly, monthly, on_event, or cron expression)",
              required: true
            )

            reward_points(:integer, "Reward points (can be positive, negative, or zero)", required: true)
            configuration(:object, "Additional configuration as JSON")
          end

          example(%{
            challenge_id: "770e8400-e29b-41d4-a716-446655440002",
            display_name: "Buy+ Challenge",
            display_description: "Earn points for purchases",
            evaluation_frequency: "daily",
            reward_points: 100,
            configuration: %{"threshold" => 10}
          })
        end,
      CampaignChallengeListResponse:
        swagger_schema do
          title("Campaign Challenge List Response")
          description("Paginated list of campaign challenges")

          properties do
            data(Schema.array(:CampaignChallenge), "List of campaign challenges")
            next_cursor(:string, "Cursor for next page", format: "date-time")
            has_more(:boolean, "Whether more results are available")
          end

          example(%{
            data: [
              %{
                id: "550e8400-e29b-41d4-a716-446655440000",
                campaign_id: "660e8400-e29b-41d4-a716-446655440001",
                challenge_id: "770e8400-e29b-41d4-a716-446655440002",
                display_name: "Buy+ Challenge",
                evaluation_frequency: "daily",
                reward_points: 100
              }
            ],
            next_cursor: "2024-05-01T10:00:00Z",
            has_more: true
          })
        end,
      CampaignChallengeErrorResponse:
        swagger_schema do
          title("Error Response")
          description("Error response")

          properties do
            error(:string, "Error message")
          end

          example(%{
            error: "Campaign challenge not found"
          })
        end,
      CampaignChallengeValidationErrorResponse:
        swagger_schema do
          title("Validation Error Response")
          description("Validation error response")

          properties do
            errors(:object, "Validation errors by field")
          end

          example(%{
            errors: %{
              display_name: ["should be at least 3 character(s)"],
              evaluation_frequency: ["must be a valid cron expression or one of: daily, weekly, monthly, on_event"]
            }
          })
        end
    }
  end

  swagger_path :index do
    get("/campaigns/{campaign_id}/challenges")
    summary("List campaign challenges")
    description("Returns a paginated list of challenges associated with a campaign")
    tag("Campaign Challenge Management")
    security([%{Bearer: []}])

    parameters do
      campaign_id(:path, :string, "Campaign ID", required: true, format: "uuid")
      limit(:query, :integer, "Number of records to return (max: 100)", required: false)
      cursor(:query, :string, "Cursor for pagination (ISO8601 datetime)", required: false)
    end

    response(200, "Success", Schema.ref(:CampaignChallengeListResponse))
    response(401, "Unauthorized", Schema.ref(:CampaignChallengeErrorResponse))
    response(403, "Forbidden", Schema.ref(:CampaignChallengeErrorResponse))
  end

  @doc """
  Lists all campaign challenges for a specific campaign.
  """
  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, %{"campaign_id" => campaign_id} = params) do
    tenant_id = conn.assigns.tenant.id
    opts = [
      limit: parse_int(params["limit"]),
      cursor: parse_datetime(params["cursor"])
    ]

    result = CampaignManagement.list_campaign_challenges(tenant_id, campaign_id, opts)
    json(conn, result)
  end

  swagger_path :show do
    get("/campaigns/{campaign_id}/challenges/{id}")
    summary("Get campaign challenge")
    description("Returns a single campaign challenge by ID")
    tag("Campaign Challenge Management")
    security([%{Bearer: []}])

    parameters do
      campaign_id(:path, :string, "Campaign ID", required: true, format: "uuid")
      id(:path, :string, "Campaign Challenge ID", required: true, format: "uuid")
    end

    response(200, "Success", Schema.ref(:CampaignChallenge))
    response(401, "Unauthorized", Schema.ref(:CampaignChallengeErrorResponse))
    response(403, "Forbidden", Schema.ref(:CampaignChallengeErrorResponse))
    response(404, "Not Found", Schema.ref(:CampaignChallengeErrorResponse))
  end

  @doc """
  Shows a specific campaign challenge.
  """
  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"campaign_id" => campaign_id, "id" => id}) do
    tenant_id = conn.assigns.tenant.id

    case CampaignManagement.get_campaign_challenge(tenant_id, campaign_id, id) do
      nil -> send_not_found(conn)
      campaign_challenge -> json(conn, campaign_challenge)
    end
  end

  swagger_path :create do
    post("/campaigns/{campaign_id}/challenges")
    summary("Create campaign challenge")
    description("Creates a new campaign challenge association")
    tag("Campaign Challenge Management")
    security([%{Bearer: []}])

    parameters do
      campaign_id(:path, :string, "Campaign ID", required: true, format: "uuid")

      campaign_challenge(
        :body,
        Schema.ref(:CampaignChallengeRequest),
        "Campaign challenge attributes",
        required: true
      )
    end

    response(201, "Created", Schema.ref(:CampaignChallenge))
    response(401, "Unauthorized", Schema.ref(:CampaignChallengeErrorResponse))
    response(403, "Forbidden", Schema.ref(:CampaignChallengeErrorResponse))
    response(404, "Campaign Not Found", Schema.ref(:CampaignChallengeErrorResponse))
    response(422, "Validation Error", Schema.ref(:CampaignChallengeValidationErrorResponse))
  end

  @doc """
  Creates a new campaign challenge association.
  """
  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, %{"campaign_id" => campaign_id} = params) do
    tenant_id = conn.assigns.tenant.id

    case CampaignManagement.create_campaign_challenge(tenant_id, campaign_id, params) do
      {:ok, campaign_challenge} ->
        conn
        |> put_status(:created)
        |> json(campaign_challenge)

      {:error, :campaign_not_found} ->
        send_not_found(conn, "Campaign not found")

      {:error, changeset} ->
        send_validation_error(conn, changeset)
    end
  end

  swagger_path :update do
    put("/campaigns/{campaign_id}/challenges/{id}")
    summary("Update campaign challenge")
    description("Updates an existing campaign challenge")
    tag("Campaign Challenge Management")
    security([%{Bearer: []}])

    parameters do
      campaign_id(:path, :string, "Campaign ID", required: true, format: "uuid")
      id(:path, :string, "Campaign Challenge ID", required: true, format: "uuid")

      campaign_challenge(
        :body,
        Schema.ref(:CampaignChallengeRequest),
        "Campaign challenge attributes",
        required: true
      )
    end

    response(200, "Success", Schema.ref(:CampaignChallenge))
    response(401, "Unauthorized", Schema.ref(:CampaignChallengeErrorResponse))
    response(403, "Forbidden", Schema.ref(:CampaignChallengeErrorResponse))
    response(404, "Not Found", Schema.ref(:CampaignChallengeErrorResponse))
    response(422, "Validation Error", Schema.ref(:CampaignChallengeValidationErrorResponse))
  end

  @doc """
  Updates an existing campaign challenge.
  """
  @spec update(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update(conn, %{"campaign_id" => campaign_id, "id" => id} = params) do
    tenant_id = conn.assigns.tenant.id

    case CampaignManagement.update_campaign_challenge(tenant_id, campaign_id, id, params) do
      {:ok, campaign_challenge} -> json(conn, campaign_challenge)
      {:error, :not_found} -> send_not_found(conn)
      {:error, changeset} -> send_validation_error(conn, changeset)
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/campaigns/{campaign_id}/challenges/{id}")
    summary("Delete campaign challenge")
    description("Permanently deletes a campaign challenge association")
    tag("Campaign Challenge Management")
    security([%{Bearer: []}])

    parameters do
      campaign_id(:path, :string, "Campaign ID", required: true, format: "uuid")
      id(:path, :string, "Campaign Challenge ID", required: true, format: "uuid")
    end

    response(204, "No Content")
    response(401, "Unauthorized", Schema.ref(:CampaignChallengeErrorResponse))
    response(403, "Forbidden", Schema.ref(:CampaignChallengeErrorResponse))
    response(404, "Not Found", Schema.ref(:CampaignChallengeErrorResponse))
  end

  @doc """
  Deletes a campaign challenge association.
  """
  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(conn, %{"campaign_id" => campaign_id, "id" => id}) do
    tenant_id = conn.assigns.tenant.id

    case CampaignManagement.delete_campaign_challenge(tenant_id, campaign_id, id) do
      {:ok, _} -> send_resp(conn, :no_content, "")
      {:error, :not_found} -> send_not_found(conn)
    end
  end

  # Private helper functions

  @spec send_not_found(Plug.Conn.t(), String.t()) :: Plug.Conn.t()
  defp send_not_found(conn, message \\ "Campaign challenge not found") do
    conn
    |> put_status(:not_found)
    |> json(%{error: message})
  end

  @spec send_validation_error(Plug.Conn.t(), Ecto.Changeset.t()) :: Plug.Conn.t()
  defp send_validation_error(conn, changeset) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{errors: translate_errors(changeset)})
  end

  @spec translate_errors(Ecto.Changeset.t()) :: map()
  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

  @spec parse_int(nil | String.t() | integer()) :: nil | integer()
  defp parse_int(nil), do: nil
  defp parse_int(""), do: nil
  defp parse_int(str) when is_binary(str) do
    case Integer.parse(str) do
      {int, _} -> int
      :error -> nil
    end
  end
  defp parse_int(int) when is_integer(int), do: int

  @spec parse_datetime(nil | String.t()) :: nil | DateTime.t()
  defp parse_datetime(nil), do: nil

  defp parse_datetime(str) when is_binary(str) do
    case DateTime.from_iso8601(str) do
      {:ok, dt, _} -> dt
      _ -> nil
    end
  end
end
