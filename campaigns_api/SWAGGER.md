# Swagger API Documentation

This project includes comprehensive OpenAPI (Swagger) documentation for the Campaign Management API.

## Accessing the Swagger UI

Once the server is running, you can access the interactive Swagger UI at:

```
http://localhost:4000/api/swagger
```

## Features

The Swagger documentation provides:

- **Interactive API Explorer**: Test all API endpoints directly from the browser
- **Request/Response Examples**: See example payloads for all operations
- **Schema Definitions**: Complete data models with validation rules
- **Authentication**: JWT Bearer token authentication support
- **Error Responses**: Documented error codes and formats

## API Endpoints Documented

### Campaign Management

- `GET /api/campaigns` - List campaigns with pagination
- `POST /api/campaigns` - Create a new campaign
- `GET /api/campaigns/{id}` - Get a single campaign
- `PUT /api/campaigns/{id}` - Update a campaign
- `DELETE /api/campaigns/{id}` - Delete a campaign

## Authentication

All endpoints require JWT authentication. To test in Swagger UI:

1. Click the "Authorize" button at the top
2. Enter your JWT token in the format: `Bearer <your_token>`
3. Click "Authorize"
4. Now you can test the endpoints

### Creating a Test JWT Token

For testing purposes, you can create a JWT token with a `tenant_id` claim:

```elixir
# In iex -S mix
header = %{"alg" => "HS256", "typ" => "JWT"}
payload = %{"tenant_id" => "test-tenant-123"}

encoded_header = header |> Jason.encode!() |> Base.url_encode64(padding: false)
encoded_payload = payload |> Jason.encode!() |> Base.url_encode64(padding: false)

token = "#{encoded_header}.#{encoded_payload}.dummy_signature"
```

## Generating Swagger Documentation

To regenerate the swagger.json file after making changes:

```bash
mix phx.swagger.generate
```

The generated file is located at: `priv/static/swagger.json`

## Swagger Configuration

Swagger is configured in:
- `config/config.exs` - Main configuration
- `lib/campaigns_api_web/controllers/swagger_info.ex` - API metadata
- `lib/campaigns_api_web/controllers/campaign_controller.ex` - Endpoint annotations

## Schema Definitions

The following schemas are documented:

- **Campaign**: Complete campaign resource
- **CampaignRequest**: Campaign creation/update payload
- **CampaignListResponse**: Paginated list response
- **ErrorResponse**: Standard error format
- **ValidationErrorResponse**: Validation error format

## Multi-Tenancy

The API implements strict tenant isolation:
- Each tenant can only access their own campaigns
- Tenants are automatically provisioned on first access (JIT)
- Tenant ID is extracted from the JWT token

## Pagination

List endpoints support cursor-based pagination:
- `limit`: Number of records (default: 50, max: 100)
- `cursor`: ISO8601 datetime for pagination

## Response Codes

- `200 OK`: Successful GET/PUT request
- `201 Created`: Successful POST request
- `204 No Content`: Successful DELETE request
- `401 Unauthorized`: Missing or invalid authentication
- `403 Forbidden`: Tenant access denied
- `404 Not Found`: Resource not found
- `422 Unprocessable Entity`: Validation errors

## Development

The Swagger UI is available in all environments. For production, consider:
- Adding authentication to the Swagger UI endpoint
- Restricting access to internal networks only
- Using environment-specific host configuration
