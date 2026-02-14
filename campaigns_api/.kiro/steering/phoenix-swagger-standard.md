# Phoenix Swagger Standard

## Controller Configuration

All Phoenix controllers that expose API endpoints MUST include PhoenixSwagger configuration for automatic API documentation generation.

## Required Configuration

### Controllers

Every controller module must include `use PhoenixSwagger` immediately after `use CampaignsApiWeb, :controller`:

```elixir
defmodule CampaignsApiWeb.MyController do
  @moduledoc """
  Controller documentation.
  """

  use CampaignsApiWeb, :controller
  use PhoenixSwagger

  alias CampaignsApi.MyContext

  # Controller actions...
end
```

### Swagger Definitions

Every controller MUST include a `swagger_definitions/0` function that defines all schemas used by the controller's endpoints:

```elixir
def swagger_definitions do
  %{
    Resource:
      swagger_schema do
        title("Resource")
        description("A resource description")

        properties do
          id(:string, "Resource UUID", required: true, format: "uuid")
          name(:string, "Resource name", required: true, minLength: 3)
          description(:string, "Resource description")
          inserted_at(:string, "Creation timestamp", format: "date-time")
          updated_at(:string, "Last update timestamp", format: "date-time")
        end

        example(%{
          id: "550e8400-e29b-41d4-a716-446655440000",
          name: "Example Resource",
          description: "An example resource",
          inserted_at: "2024-05-01T10:00:00Z",
          updated_at: "2024-05-01T10:00:00Z"
        })
      end,
    ResourceRequest:
      swagger_schema do
        title("Resource Request")
        description("Resource creation/update request")

        properties do
          name(:string, "Resource name", required: true, minLength: 3)
          description(:string, "Resource description")
        end

        example(%{
          name: "Example Resource",
          description: "An example resource"
        })
      end,
    ResourceListResponse:
      swagger_schema do
        title("Resource List Response")
        description("Paginated list of resources")

        properties do
          data(Schema.array(:Resource), "List of resources")
          next_cursor(:string, "Cursor for next page", format: "date-time")
          has_more(:boolean, "Whether more results are available")
        end

        example(%{
          data: [
            %{
              id: "550e8400-e29b-41d4-a716-446655440000",
              name: "Example Resource"
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
          error: "Resource not found"
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
            name: ["should be at least 3 character(s)"]
          }
        })
      end
  }
end
```

### Swagger Path Documentation

Every controller action MUST have a corresponding `swagger_path` function that documents the endpoint:

```elixir
swagger_path :index do
  get("/resources")
  summary("List resources")
  description("Returns a paginated list of resources")
  tag("Resource Management")
  security([%{Bearer: []}])

  parameters do
    limit(:query, :integer, "Number of records to return (max: 100)", required: false)
    cursor(:query, :string, "Cursor for pagination (ISO8601 datetime)", required: false)
  end

  response(200, "Success", Schema.ref(:ResourceListResponse))
  response(401, "Unauthorized", Schema.ref(:ErrorResponse))
  response(403, "Forbidden", Schema.ref(:ErrorResponse))
end

@spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
def index(conn, params) do
  # Implementation
end
```

## Rules

1. **Always add PhoenixSwagger**: Every new controller must include `use PhoenixSwagger`
2. **Placement**: Must be placed immediately after `use CampaignsApiWeb, :controller`
3. **Before aliases**: PhoenixSwagger configuration comes before any alias declarations
4. **Swagger definitions required**: Every controller must define `swagger_definitions/0` with all schemas
5. **Path documentation required**: Every public action must have a `swagger_path` function
6. **Consistent naming**: Use consistent schema naming patterns (Resource, ResourceRequest, ResourceListResponse, ErrorResponse, ValidationErrorResponse)
7. **Complete examples**: All schemas must include realistic example data
8. **Proper types**: Use appropriate types and formats (uuid, date-time, etc.)

## Schema Naming Conventions

Follow these naming patterns for consistency:

- **Main resource**: `ResourceName` (e.g., `Campaign`, `CampaignChallenge`)
- **Request body**: `ResourceNameRequest` (e.g., `CampaignRequest`, `CampaignChallengeRequest`)
- **List response**: `ResourceNameListResponse` (e.g., `CampaignListResponse`)
- **Error responses**: `ErrorResponse` or `ResourceNameErrorResponse` for resource-specific errors
- **Validation errors**: `ValidationErrorResponse` or `ResourceNameValidationErrorResponse`

## Examples

### ✅ Correct

```elixir
defmodule CampaignsApiWeb.CampaignController do
  use CampaignsApiWeb, :controller
  use PhoenixSwagger

  alias CampaignsApi.CampaignManagement

  def swagger_definitions do
    %{
      Campaign: swagger_schema do
        # Schema definition
      end,
      CampaignRequest: swagger_schema do
        # Request schema
      end
    }
  end

  swagger_path :index do
    get("/campaigns")
    summary("List campaigns")
    # Path documentation
  end

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, params) do
    # Implementation
  end
end
```

### ❌ Incorrect

```elixir
defmodule CampaignsApiWeb.CampaignController do
  use CampaignsApiWeb, :controller
  # Missing: use PhoenixSwagger

  alias CampaignsApi.CampaignManagement

  # Missing: swagger_definitions/0

  # Missing: swagger_path documentation
  def index(conn, params) do
    # Implementation
  end
end
```

## Rationale

- Ensures consistent API documentation across all endpoints
- Enables automatic Swagger/OpenAPI spec generation
- Improves API discoverability and testing
- Maintains documentation standards across the codebase
- Required for integration with API documentation tools
- Provides clear contract for API consumers
- Enables automatic client SDK generation

## Verification

When creating or reviewing controllers, always verify:
1. `use PhoenixSwagger` is present
2. It's placed in the correct location (after `use CampaignsApiWeb, :controller`)
3. `swagger_definitions/0` function is defined with all necessary schemas
4. All public API endpoints have corresponding `swagger_path` documentation
5. All schemas include realistic examples
6. Schema naming follows the established conventions
7. All required response codes are documented (200, 201, 401, 403, 404, 422, etc.)

