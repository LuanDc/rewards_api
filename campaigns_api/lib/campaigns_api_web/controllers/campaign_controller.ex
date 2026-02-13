defmodule CampaignsApiWeb.CampaignController do
  use CampaignsApiWeb, :controller
  use PhoenixSwagger

  alias CampaignsApi.CampaignManagement

  def swagger_definitions do
    %{
      Campaign:
        swagger_schema do
          title("Campaign")
          description("A reward campaign belonging to a tenant")

          properties do
            id(:string, "Campaign UUID", required: true, format: "uuid")
            tenant_id(:string, "Tenant ID", required: true)
            name(:string, "Campaign name", required: true, minLength: 3)
            description(:string, "Campaign description")
            start_time(:string, "Campaign start time", format: "date-time")
            end_time(:string, "Campaign end time", format: "date-time")
            status(:string, "Campaign status", enum: [:active, :paused], default: :active)
            inserted_at(:string, "Creation timestamp", format: "date-time")
            updated_at(:string, "Last update timestamp", format: "date-time")
          end

          example(%{
            id: "550e8400-e29b-41d4-a716-446655440000",
            tenant_id: "tenant-123",
            name: "Summer Sale Campaign",
            description: "A great summer promotion",
            start_time: "2024-06-01T00:00:00Z",
            end_time: "2024-08-31T23:59:59Z",
            status: "active",
            inserted_at: "2024-05-01T10:00:00Z",
            updated_at: "2024-05-01T10:00:00Z"
          })
        end,
      CampaignRequest:
        swagger_schema do
          title("Campaign Request")
          description("Campaign creation/update request")

          properties do
            name(:string, "Campaign name", required: true, minLength: 3)
            description(:string, "Campaign description")
            start_time(:string, "Campaign start time", format: "date-time")
            end_time(:string, "Campaign end time", format: "date-time")
            status(:string, "Campaign status", enum: [:active, :paused])
          end

          example(%{
            name: "Summer Sale Campaign",
            description: "A great summer promotion",
            start_time: "2024-06-01T00:00:00Z",
            end_time: "2024-08-31T23:59:59Z",
            status: "active"
          })
        end,
      CampaignListResponse:
        swagger_schema do
          title("Campaign List Response")
          description("Paginated list of campaigns")

          properties do
            data(Schema.array(:Campaign), "List of campaigns")
            next_cursor(:string, "Cursor for next page", format: "date-time")
            has_more(:boolean, "Whether more results are available")
          end

          example(%{
            data: [
              %{
                id: "550e8400-e29b-41d4-a716-446655440000",
                tenant_id: "tenant-123",
                name: "Summer Sale Campaign",
                status: "active"
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
            error: "Campaign not found"
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
              name: ["should be at least 3 character(s)"],
              start_time: ["must be before end_time"]
            }
          })
        end
    }
  end

  swagger_path :index do
    get("/campaigns")
    summary("List campaigns")
    description("Returns a paginated list of campaigns for the authenticated tenant")
    tag("Campaign Management")
    security([%{Bearer: []}])

    parameters do
      limit(:query, :integer, "Number of records to return (max: 100)", required: false)
      cursor(:query, :string, "Cursor for pagination (ISO8601 datetime)", required: false)
    end

    response(200, "Success", Schema.ref(:CampaignListResponse))
    response(401, "Unauthorized", Schema.ref(:ErrorResponse))
    response(403, "Forbidden", Schema.ref(:ErrorResponse))
  end

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, params) do
    tenant_id = conn.assigns.tenant.id

    opts = [
      limit: parse_int(params["limit"]),
      cursor: parse_datetime(params["cursor"])
    ]

    result = CampaignManagement.list_campaigns(tenant_id, opts)
    json(conn, result)
  end

  swagger_path :create do
    post("/campaigns")
    summary("Create campaign")
    description("Creates a new campaign for the authenticated tenant")
    tag("Campaign Management")
    security([%{Bearer: []}])

    parameters do
      campaign(:body, Schema.ref(:CampaignRequest), "Campaign attributes", required: true)
    end

    response(201, "Created", Schema.ref(:Campaign))
    response(401, "Unauthorized", Schema.ref(:ErrorResponse))
    response(403, "Forbidden", Schema.ref(:ErrorResponse))
    response(422, "Validation Error", Schema.ref(:ValidationErrorResponse))
  end

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, params) do
    tenant_id = conn.assigns.tenant.id

    # Convert string keys to atom keys for Ecto
    attrs = atomize_keys(params)

    case CampaignManagement.create_campaign(tenant_id, attrs) do
      {:ok, campaign} ->
        conn
        |> put_status(:created)
        |> json(campaign)

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: translate_errors(changeset)})
    end
  end

  swagger_path :show do
    get("/campaigns/{id}")
    summary("Get campaign")
    description("Returns a single campaign by ID for the authenticated tenant")
    tag("Campaign Management")
    security([%{Bearer: []}])

    parameters do
      id(:path, :string, "Campaign ID", required: true, format: "uuid")
    end

    response(200, "Success", Schema.ref(:Campaign))
    response(401, "Unauthorized", Schema.ref(:ErrorResponse))
    response(403, "Forbidden", Schema.ref(:ErrorResponse))
    response(404, "Not Found", Schema.ref(:ErrorResponse))
  end

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    tenant_id = conn.assigns.tenant.id

    case CampaignManagement.get_campaign(tenant_id, id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Campaign not found"})

      campaign ->
        json(conn, campaign)
    end
  end

  swagger_path :update do
    put("/campaigns/{id}")
    summary("Update campaign")
    description("Updates an existing campaign for the authenticated tenant")
    tag("Campaign Management")
    security([%{Bearer: []}])

    parameters do
      id(:path, :string, "Campaign ID", required: true, format: "uuid")
      campaign(:body, Schema.ref(:CampaignRequest), "Campaign attributes", required: true)
    end

    response(200, "Success", Schema.ref(:Campaign))
    response(401, "Unauthorized", Schema.ref(:ErrorResponse))
    response(403, "Forbidden", Schema.ref(:ErrorResponse))
    response(404, "Not Found", Schema.ref(:ErrorResponse))
    response(422, "Validation Error", Schema.ref(:ValidationErrorResponse))
  end

  @spec update(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update(conn, %{"id" => id} = params) do
    tenant_id = conn.assigns.tenant.id

    # Convert string keys to atom keys for Ecto
    attrs = atomize_keys(params)

    case CampaignManagement.update_campaign(tenant_id, id, attrs) do
      {:ok, campaign} ->
        json(conn, campaign)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Campaign not found"})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: translate_errors(changeset)})
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/campaigns/{id}")
    summary("Delete campaign")
    description("Permanently deletes a campaign for the authenticated tenant")
    tag("Campaign Management")
    security([%{Bearer: []}])

    parameters do
      id(:path, :string, "Campaign ID", required: true, format: "uuid")
    end

    response(204, "No Content")
    response(401, "Unauthorized", Schema.ref(:ErrorResponse))
    response(403, "Forbidden", Schema.ref(:ErrorResponse))
    response(404, "Not Found", Schema.ref(:ErrorResponse))
  end

  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    tenant_id = conn.assigns.tenant.id

    case CampaignManagement.delete_campaign(tenant_id, id) do
      {:ok, _} ->
        send_resp(conn, :no_content, "")

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Campaign not found"})
    end
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
        # Skip "id" key as it's used for routing
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
      # If atom doesn't exist, return original map
      map
  end

  @spec parse_int(String.t() | integer() | nil) :: integer() | nil
  defp parse_int(nil), do: nil
  defp parse_int(str) when is_binary(str), do: String.to_integer(str)
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
