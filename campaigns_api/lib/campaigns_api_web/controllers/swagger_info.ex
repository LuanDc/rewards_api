defmodule CampaignsApiWeb.SwaggerInfo do
  @moduledoc """
  Swagger API documentation configuration.
  """

  def swagger_info do
    %{
      info: %{
        version: "1.0.0",
        title: "Campaign Management API",
        description: """
        Multi-tenant Campaign Management API with JWT authentication.

        Authentication: All API endpoints require JWT authentication via Bearer token in the Authorization header (Authorization: Bearer <jwt_token>). The JWT token must contain a tenant_id claim that identifies the tenant making the request.

        Multi-Tenancy: This API implements strict tenant isolation. Each tenant can only access their own campaigns. Tenants are automatically provisioned on first access (JIT provisioning).

        Pagination: List endpoints support cursor-based pagination with the following query parameters: limit (Number of records to return, default: 50, max: 100) and cursor (Cursor value, ISO8601 datetime, to paginate from).

        Error Responses: The API returns structured error responses (400 Bad Request: Invalid request parameters, 401 Unauthorized: Missing or invalid authentication, 403 Forbidden: Tenant access denied, 404 Not Found: Resource not found or belongs to different tenant, 422 Unprocessable Entity: Validation errors).
        """,
        contact: %{
          name: "API Support",
          email: "support@example.com"
        }
      },
      securityDefinitions: %{
        Bearer: %{
          type: "apiKey",
          name: "Authorization",
          description: "JWT Bearer token. Format: `Bearer <token>`",
          in: "header"
        }
      },
      security: [
        %{Bearer: []}
      ],
      consumes: ["application/json"],
      produces: ["application/json"],
      schemes: ["http", "https"],
      host: "localhost:4000",
      basePath: "/api"
    }
  end

  def swagger_path_info(path) do
    case path do
      "/campaigns" -> "Campaign Management"
      "/campaigns/{id}" -> "Campaign Management"
      _ -> ""
    end
  end
end
