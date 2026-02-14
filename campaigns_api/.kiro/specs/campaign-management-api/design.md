# Design Document: Campaign Management API

## Overview

The Campaign Management API is a multi-tenant Phoenix application that provides secure CRUD operations for reward campaigns. The system uses OAuth2 Client Credentials authentication with JWT tokens, implements Just-in-Time tenant provisioning, and ensures complete data isolation between tenants.

The architecture follows Phoenix best practices with clear separation between contexts (Tenants, CampaignManagement), plugs for authentication/authorization, and Ecto schemas for data modeling. The API supports flexible campaign date configurations and cursor-based pagination for efficient data retrieval.

### Key Design Decisions

1. **Multi-tenancy Model**: Tenant ID extracted from JWT and used as partition key for all queries
2. **JIT Provisioning**: Automatic tenant creation on first authenticated access
3. **Authentication**: Mock JWT decoder (no signature validation) for initial implementation
4. **Pagination**: Cursor-based using inserted_at timestamp for consistent ordering
5. **Date Flexibility**: All four date combinations supported (none, start only, end only, both)
6. **Timezone**: All dates stored and transmitted in UTC (ISO8601 format)
7. **Deletion Strategy**: Hard delete for campaigns, soft delete for tenants

## Architecture

### System Components

```
┌─────────────────────────────────────────────────────────────┐
│                     HTTP Request                             │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                  Phoenix Router                              │
│  - Routes API requests to CampaignController                 │
│  - Applies authentication plugs                              │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              Plug Pipeline                                   │
│  1. RequireAuth - Validates JWT, extracts tenant_id         │
│  2. AssignTenant - JIT provisioning, loads tenant            │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│           CampaignController                                 │
│  - Handles HTTP requests/responses                           │
│  - Delegates business logic to contexts                      │
└────────────────────────┬────────────────────────────────────┘
                         │
                ┌────────┴────────┐
                ▼                 ▼
┌──────────────────────┐  ┌──────────────────────┐
│  Tenants Context     │  │ CampaignManagement   │
│  - get_tenant/1      │  │ Context              │
│  - create_tenant/1   │  │ - list_campaigns/2   │
│  - tenant_active?/1  │  │ - get_campaign/2     │
└──────────┬───────────┘  │ - create_campaign/2  │
           │              │ - update_campaign/3  │
           │              │ - delete_campaign/2  │
           │              └──────────┬───────────┘
           │                         │
           │                         ▼
           │              ┌──────────────────────┐
           │              │ Pagination Module    │
           │              │ - paginate/3         │
           │              │ (Reusable)           │
           │              └──────────┬───────────┘
           │                         │
           ▼                         ▼
┌─────────────────────────────────────────────────────────────┐
│                    Ecto / Database                           │
│  - tenants table (soft delete)                               │
│  - campaigns table (hard delete)                             │
│  - Indexes: (tenant_id, id), (status)                        │
└─────────────────────────────────────────────────────────────┘
```

### Context Boundaries

**Pagination Module**: Reusable cursor-based pagination for any Ecto query
- Accepts any query and applies cursor-based pagination
- Configurable cursor field, limit, and sort order
- Returns consistent pagination response structure
- Can be used across all contexts and resources

**Tenants Context**: Manages tenant lifecycle, status checks, and JIT provisioning
- Responsible for tenant CRUD operations
- Enforces tenant status rules (active/suspended/deleted)
- Handles soft delete logic

**CampaignManagement Context**: Manages campaign operations with tenant isolation
- All operations require tenant_id parameter
- Automatically filters queries by tenant_id
- Validates campaign business rules (dates, status)
- Implements cursor-based pagination

### Request Flow

1. Client sends request with `Authorization: Bearer <jwt>` header
2. `RequireAuth` plug decodes JWT and extracts tenant_id
3. `AssignTenant` plug loads or creates tenant (JIT provisioning)
4. `AssignTenant` plug checks tenant status (403 if not active)
5. Controller receives request with tenant assigned to `conn.assigns.tenant`
6. Controller calls context functions with tenant_id
7. Context queries database with tenant_id filter
8. Response returned to client

## Components and Interfaces

### Plugs

#### RequireAuth Plug

```elixir
defmodule CampaignsManagmentApiWeb.Plugs.RequireAuth do
  import Plug.Conn
  
  def init(opts), do: opts
  
  def call(conn, _opts) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] ->
        case decode_jwt(token) do
          {:ok, %{"tenant_id" => tenant_id}} ->
            assign(conn, :tenant_id, tenant_id)
          _ ->
            unauthorized(conn)
        end
      _ ->
        unauthorized(conn)
    end
  end
  
  defp decode_jwt(token) do
    # Mock implementation - decode without verification
    # Uses Joken to parse JWT structure
    case Joken.peek_claims(token) do
      {:ok, claims} -> {:ok, claims}
      {:error, _} -> {:error, :invalid_token}
    end
  end
  
  defp unauthorized(conn) do
    conn
    |> put_status(:unauthorized)
    |> Phoenix.Controller.json(%{error: "Unauthorized"})
    |> halt()
  end
end
```

#### AssignTenant Plug

```elixir
defmodule CampaignsManagmentApiWeb.Plugs.AssignTenant do
  import Plug.Conn
  alias CampaignsManagmentApi.Tenants
  
  def init(opts), do: opts
  
  def call(conn, _opts) do
    tenant_id = conn.assigns.tenant_id
    
    case Tenants.get_or_create_tenant(tenant_id) do
      {:ok, tenant} ->
        if Tenants.tenant_active?(tenant) do
          assign(conn, :tenant, tenant)
        else
          forbidden(conn)
        end
      {:error, _} ->
        server_error(conn)
    end
  end
  
  defp forbidden(conn) do
    conn
    |> put_status(:forbidden)
    |> Phoenix.Controller.json(%{error: "Tenant access denied"})
    |> halt()
  end
  
  defp server_error(conn) do
    conn
    |> put_status(:internal_server_error)
    |> Phoenix.Controller.json(%{error: "Internal server error"})
    |> halt()
  end
end
```

### Contexts

#### Tenants Context

```elixir
defmodule CampaignsManagmentApi.Tenants do
  import Ecto.Query
  alias CampaignsManagmentApi.Repo
  alias CampaignsManagmentApi.Tenants.Tenant
  
  # Get existing tenant or create new one (JIT)
  def get_or_create_tenant(tenant_id) do
    case get_tenant(tenant_id) do
      nil -> create_tenant(tenant_id)
      tenant -> {:ok, tenant}
    end
  end
  
  # Get tenant by ID
  def get_tenant(tenant_id) do
    Repo.get(Tenant, tenant_id)
  end
  
  # Create new tenant with JIT provisioning
  def create_tenant(tenant_id, attrs \\ %{}) do
    %Tenant{}
    |> Tenant.changeset(Map.merge(%{id: tenant_id, name: tenant_id}, attrs))
    |> Repo.insert()
  end
  
  # Check if tenant can access API
  def tenant_active?(%Tenant{status: :active}), do: true
  def tenant_active?(_), do: false
end
```

#### Pagination Module

```elixir
defmodule CampaignsManagmentApi.Pagination do
  import Ecto.Query
  
  @default_limit 50
  @max_limit 100
  
  @doc """
  Applies cursor-based pagination to any Ecto query.
  
  ## Options
  - `:limit` - Number of records to return (default: 50, max: 100)
  - `:cursor` - Cursor value (datetime) to paginate from
  - `:cursor_field` - Field to use for cursor (default: :inserted_at)
  - `:order` - Sort order, :desc or :asc (default: :desc)
  
  ## Returns
  %{
    data: [records],
    next_cursor: datetime | nil,
    has_more: boolean
  }
  """
  def paginate(repo, query, opts \\ []) do
    limit = opts |> Keyword.get(:limit, @default_limit) |> min(@max_limit)
    cursor = Keyword.get(opts, :cursor)
    cursor_field = Keyword.get(opts, :cursor_field, :inserted_at)
    order = Keyword.get(opts, :order, :desc)
    
    # Apply ordering
    query = from q in query,
      order_by: [{^order, field(q, ^cursor_field)}],
      limit: ^(limit + 1)
    
    # Apply cursor filter
    query = if cursor do
      case order do
        :desc -> from q in query, where: field(q, ^cursor_field) < ^cursor
        :asc -> from q in query, where: field(q, ^cursor_field) > ^cursor
      end
    else
      query
    end
    
    # Execute query
    records = repo.all(query)
    
    # Check if there are more records
    {results, has_more} = if length(records) > limit do
      {Enum.take(records, limit), true}
    else
      {records, false}
    end
    
    # Get next cursor
    next_cursor = if has_more do
      results |> List.last() |> Map.get(cursor_field)
    else
      nil
    end
    
    %{
      data: results,
      next_cursor: next_cursor,
      has_more: has_more
    }
  end
end
```

#### CampaignManagement Context

```elixir
defmodule CampaignsManagmentApi.CampaignManagement do
  import Ecto.Query
  alias CampaignsManagmentApi.Repo
  alias CampaignsManagmentApi.CampaignManagement.Campaign
  alias CampaignsManagmentApi.Pagination
  
  # List campaigns with cursor-based pagination
  def list_campaigns(tenant_id, opts \\ []) do
    query = from c in Campaign,
      where: c.tenant_id == ^tenant_id
    
    Pagination.paginate(Repo, query, opts)
  end
  
  # Get single campaign by ID and tenant
  def get_campaign(tenant_id, campaign_id) do
    Repo.get_by(Campaign, id: campaign_id, tenant_id: tenant_id)
  end
  
  # Create new campaign
  def create_campaign(tenant_id, attrs) do
    %Campaign{}
    |> Campaign.changeset(Map.put(attrs, :tenant_id, tenant_id))
    |> Repo.insert()
  end
  
  # Update existing campaign
  def update_campaign(tenant_id, campaign_id, attrs) do
    case get_campaign(tenant_id, campaign_id) do
      nil -> {:error, :not_found}
      campaign ->
        campaign
        |> Campaign.changeset(attrs)
        |> Repo.update()
    end
  end
  
  # Delete campaign (hard delete)
  def delete_campaign(tenant_id, campaign_id) do
    case get_campaign(tenant_id, campaign_id) do
      nil -> {:error, :not_found}
      campaign -> Repo.delete(campaign)
    end
  end
end
```

### Controller

```elixir
defmodule CampaignsManagmentApiWeb.CampaignController do
  use CampaignsManagmentApiWeb, :controller
  alias CampaignsManagmentApi.CampaignManagement
  
  # POST /api/campaigns
  def create(conn, params) do
    tenant_id = conn.assigns.tenant.id
    
    case CampaignManagement.create_campaign(tenant_id, params) do
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
  
  # GET /api/campaigns
  def index(conn, params) do
    tenant_id = conn.assigns.tenant.id
    opts = [
      limit: parse_int(params["limit"]),
      cursor: parse_datetime(params["cursor"])
    ]
    
    result = CampaignManagement.list_campaigns(tenant_id, opts)
    json(conn, result)
  end
  
  # GET /api/campaigns/:id
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
  
  # PUT /api/campaigns/:id
  def update(conn, %{"id" => id} = params) do
    tenant_id = conn.assigns.tenant.id
    
    case CampaignManagement.update_campaign(tenant_id, id, params) do
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
  
  # DELETE /api/campaigns/:id
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
  
  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
  
  defp parse_int(nil), do: nil
  defp parse_int(str) when is_binary(str), do: String.to_integer(str)
  defp parse_int(int) when is_integer(int), do: int
  
  defp parse_datetime(nil), do: nil
  defp parse_datetime(str) when is_binary(str) do
    case DateTime.from_iso8601(str) do
      {:ok, dt, _} -> dt
      _ -> nil
    end
  end
end
```

## Data Models

### Tenant Schema

```elixir
defmodule CampaignsManagmentApi.Tenants.Tenant do
  use Ecto.Schema
  import Ecto.Changeset
  
  @primary_key {:id, :string, autogenerate: false}
  @derive {Jason.Encoder, only: [:id, :name, :status, :inserted_at, :updated_at]}
  
  schema "tenants" do
    field :name, :string
    field :status, Ecto.Enum, values: [:active, :suspended, :deleted], default: :active
    field :deleted_at, :utc_datetime
    
    has_many :campaigns, CampaignsManagmentApi.CampaignManagement.Campaign
    
    timestamps(type: :utc_datetime)
  end
  
  def changeset(tenant, attrs) do
    tenant
    |> cast(attrs, [:id, :name, :status, :deleted_at])
    |> validate_required([:id, :name])
    |> validate_length(:name, min: 1)
    |> unique_constraint(:id, name: :tenants_pkey)
  end
end
```

### Campaign Schema

```elixir
defmodule CampaignsManagmentApi.CampaignManagement.Campaign do
  use Ecto.Schema
  import Ecto.Changeset
  
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :string
  @derive {Jason.Encoder, only: [:id, :tenant_id, :name, :description, 
                                   :start_time, :end_time, :status, 
                                   :inserted_at, :updated_at]}
  
  schema "campaigns" do
    field :name, :string
    field :description, :string
    field :start_time, :utc_datetime
    field :end_time, :utc_datetime
    field :status, Ecto.Enum, values: [:active, :paused], default: :active
    
    belongs_to :tenant, CampaignsManagmentApi.Tenants.Tenant, type: :string
    
    timestamps(type: :utc_datetime)
  end
  
  def changeset(campaign, attrs) do
    campaign
    |> cast(attrs, [:tenant_id, :name, :description, :start_time, :end_time, :status])
    |> validate_required([:tenant_id, :name])
    |> validate_length(:name, min: 3)
    |> validate_date_order()
    |> foreign_key_constraint(:tenant_id)
  end
  
  defp validate_date_order(changeset) do
    start_time = get_field(changeset, :start_time)
    end_time = get_field(changeset, :end_time)
    
    if start_time && end_time && DateTime.compare(start_time, end_time) != :lt do
      add_error(changeset, :start_time, "must be before end_time")
    else
      changeset
    end
  end
end
```

### Database Migrations

```elixir
# priv/repo/migrations/TIMESTAMP_create_tenants.exs
defmodule CampaignsManagmentApi.Repo.Migrations.CreateTenants do
  use Ecto.Migration
  
  def change do
    create table(:tenants, primary_key: false) do
      add :id, :string, primary_key: true
      add :name, :string, null: false
      add :status, :string, null: false, default: "active"
      add :deleted_at, :utc_datetime
      
      timestamps(type: :utc_datetime)
    end
    
    create index(:tenants, [:status])
  end
end

# priv/repo/migrations/TIMESTAMP_create_campaigns.exs
defmodule CampaignsManagmentApi.Repo.Migrations.CreateCampaigns do
  use Ecto.Migration
  
  def change do
    create table(:campaigns, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, type: :string, on_delete: :restrict), null: false
      add :name, :string, null: false
      add :description, :text
      add :start_time, :utc_datetime
      add :end_time, :utc_datetime
      add :status, :string, null: false, default: "active"
      
      timestamps(type: :utc_datetime)
    end
    
    create index(:campaigns, [:tenant_id, :id])
    create index(:campaigns, [:tenant_id, :inserted_at])
  end
end
```

### Router Configuration

```elixir
defmodule CampaignsManagmentApiWeb.Router do
  use CampaignsManagmentApiWeb, :router
  
  pipeline :api do
    plug :accepts, ["json"]
  end
  
  pipeline :authenticated do
    plug CampaignsManagmentApiWeb.Plugs.RequireAuth
    plug CampaignsManagmentApiWeb.Plugs.AssignTenant
  end
  
  scope "/api", CampaignsManagmentApiWeb do
    pipe_through [:api, :authenticated]
    
    resources "/campaigns", CampaignController, except: [:new, :edit]
  end
end
```

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: JWT Tenant ID Extraction

*For any* valid JWT token containing a tenant_id claim, extracting the tenant_id should successfully return the claim value.

**Validates: Requirements 1.1**

### Property 2: JIT Tenant Creation

*For any* tenant_id that does not exist in the database, making an authenticated request with that tenant_id should create a new tenant record with status "active" and the tenant_id as both the id and default name.

**Validates: Requirements 2.1, 2.2, 2.3**

### Property 3: JIT Tenant Idempotence

*For any* tenant_id that already exists in the database, making multiple authenticated requests with that tenant_id should not create duplicate tenant records.

**Validates: Requirements 2.4**

### Property 4: Tenant Schema Completeness

*For any* tenant record created or retrieved, it should contain all required fields: id, name, status, deleted_at, inserted_at, updated_at.

**Validates: Requirements 2.5, 10.1**

### Property 5: Non-Active Tenant Access Denial

*For any* tenant with status "deleted" or "suspended", all API requests authenticated with that tenant_id should return HTTP 403 Forbidden.

**Validates: Requirements 3.1, 3.2**

### Property 6: Active Tenant Access Permission

*For any* tenant with status "active", API requests authenticated with that tenant_id should be allowed to proceed.

**Validates: Requirements 3.3**

### Property 7: Campaign Creation with Tenant Association

*For any* authenticated client with valid campaign data, creating a campaign should associate it with the client's tenant_id and generate a UUID for the campaign id.

**Validates: Requirements 4.1, 4.2, 4.4**

### Property 8: Campaign Default Status

*For any* campaign created without an explicit status field, the campaign should have status "active".

**Validates: Requirements 4.3**

### Property 9: Campaign Name Validation

*For any* campaign creation or update, names with fewer than 3 characters should be rejected, and names with 3 or more characters should be accepted.

**Validates: Requirements 4.5**

### Property 10: Optional Campaign Fields

*For any* campaign, the description, start_time, and end_time fields should be optional and campaigns should be valid with or without these fields.

**Validates: Requirements 4.6, 4.7, 4.8**

### Property 11: Date Order Validation

*For any* campaign operation (create or update) where both start_time and end_time are provided, the operation should succeed only if start_time is before end_time, otherwise it should return a validation error.

**Validates: Requirements 4.9, 6.3**

### Property 12: UTC Timezone Storage

*For any* campaign with datetime fields, all stored and retrieved datetime values should be in UTC timezone.

**Validates: Requirements 4.10**

### Property 13: Tenant Data Isolation

*For any* two different tenants, one tenant should never be able to retrieve, update, or delete campaigns belonging to the other tenant (all cross-tenant operations should return HTTP 404).

**Validates: Requirements 5.1, 5.7, 5.8, 6.1, 6.4, 7.1, 7.2, 8.2**

### Property 14: Campaign List Ordering

*For any* tenant's campaign list, campaigns should be ordered by inserted_at in descending order (most recent first).

**Validates: Requirements 5.2**

### Property 15: Cursor-Based Pagination

*For any* campaign list request with a cursor parameter, the returned campaigns should all have inserted_at timestamps before the cursor value.

**Validates: Requirements 5.3**

### Property 16: Pagination Limit Enforcement

*For any* campaign list request with a limit parameter, the number of returned campaigns should not exceed the specified limit (with a maximum of 100).

**Validates: Requirements 5.4**

### Property 17: Pagination Next Cursor

*For any* paginated campaign list where more campaigns exist beyond the current page, the response should include a next_cursor field pointing to the last campaign's inserted_at timestamp.

**Validates: Requirements 5.5**

### Property 18: Default Pagination Behavior

*For any* campaign list request without a cursor parameter, the system should return the first page of campaigns starting from the most recent.

**Validates: Requirements 5.6**

### Property 19: Campaign Response Schema

*For any* campaign retrieved or created, the response should include all fields: id, tenant_id, name, description, start_time, end_time, status, inserted_at, updated_at.

**Validates: Requirements 5.10, 10.2**

### Property 20: Campaign Field Mutability

*For any* campaign update operation, the fields name, description, start_time, end_time, and status should be modifiable while tenant_id and id remain immutable.

**Validates: Requirements 6.2**

### Property 21: Campaign Status Transitions

*For any* campaign, status should be changeable between "active" and "paused" in any direction.

**Validates: Requirements 6.6**

### Property 22: Hard Delete Behavior

*For any* campaign that is successfully deleted, subsequent attempts to retrieve that campaign should return HTTP 404, and the campaign should not appear in any list queries.

**Validates: Requirements 7.1**

### Property 23: Successful Deletion Response

*For any* successful campaign deletion, the response should be HTTP 204 No Content.

**Validates: Requirements 7.4**

### Property 24: Foreign Key Constraint Enforcement

*For any* attempt to create a campaign with a tenant_id that does not exist in the tenants table, the operation should fail with a database constraint error.

**Validates: Requirements 8.3**

### Property 25: Structured Error Responses

*For any* validation error or client error (4xx), the response should be formatted as structured JSON with error details.

**Validates: Requirements 4.11, 6.5, 11.1, 11.6**

### Property 26: Pagination Module Reusability

*For any* Ecto query, the Pagination module should be able to apply cursor-based pagination with configurable cursor field, limit, and sort order, returning a consistent response structure.

**Validates: Requirements 5.2, 5.3, 5.4, 5.5, 5.6** (via reusable implementation)

### Example Tests for Flexible Date Management

The following are specific examples that should be tested to verify all date combinations work:

**Example 1: Campaign without dates**
- Create campaign with neither start_time nor end_time
- Should succeed
- **Validates: Requirements 9.1**

**Example 2: Campaign with start_time only**
- Create campaign with start_time but no end_time
- Should succeed
- **Validates: Requirements 9.2**

**Example 3: Campaign with end_time only**
- Create campaign with end_time but no start_time
- Should succeed
- **Validates: Requirements 9.3**

**Example 4: Campaign with both dates**
- Create campaign with start_time before end_time
- Should succeed
- **Validates: Requirements 9.4**

## Error Handling

### Error Response Format

All errors return JSON with consistent structure:

```json
{
  "error": "Human-readable error message",
  "errors": {
    "field_name": ["validation error 1", "validation error 2"]
  }
}
```

### HTTP Status Codes

- **200 OK**: Successful GET, PUT operations
- **201 Created**: Successful POST operations
- **204 No Content**: Successful DELETE operations
- **401 Unauthorized**: Missing or invalid authentication
- **403 Forbidden**: Valid authentication but tenant not active
- **404 Not Found**: Resource not found or cross-tenant access attempt
- **422 Unprocessable Entity**: Validation errors
- **500 Internal Server Error**: Unexpected server errors

### Validation Errors

Campaign validation errors:
- Name required (minimum 3 characters)
- start_time must be before end_time (when both provided)
- Invalid datetime format (must be ISO8601)
- Invalid status value (must be "active" or "paused")

Tenant validation errors:
- Invalid tenant status
- Tenant not active (deleted or suspended)

### Database Constraint Errors

- Foreign key violation: Campaign references non-existent tenant
- Unique constraint violation: Duplicate tenant_id (should not occur with JIT)

## Testing Strategy

### Dual Testing Approach

The testing strategy employs both unit tests and property-based tests to ensure comprehensive coverage:

**Unit Tests**: Focus on specific examples, edge cases, and integration points
- Specific date combination examples (4 scenarios)
- Error handling for missing authentication
- Error handling for non-existent resources
- Foreign key constraint violations
- Controller integration with contexts
- Plug pipeline behavior

**Property-Based Tests**: Verify universal properties across all inputs
- Minimum 100 iterations per property test
- Each test tagged with: **Feature: campaign-management-api, Property N: [property text]**
- Use ExUnitProperties or StreamData for Elixir property testing
- Generate random valid and invalid inputs to test properties

### Test Data Generation

The project uses **ExMachina** for test data generation with a simple, deterministic approach:

**ExMachina**: Factory pattern for creating test data
- Centralized factory definitions in `test/support/factory.ex`
- Consistent data creation across all tests
- Specialized factories for different scenarios (suspended tenants, paused campaigns, etc.)
- Use `insert/2` for persisted records, `build/2` for structs
- Simple, deterministic data generation using sequential IDs and predictable values
- No external dependencies for data generation (similar to property test approach)

**Data Generation Strategy**:
- Sequential IDs: `"tenant-#{System.unique_integer([:positive])}"`
- Predictable names: `"Tenant #{id}"`, `"Campaign #{id}"`
- Simple descriptions: `"Description for campaign #{id}"`
- Deterministic dates: Fixed offsets from current time (e.g., +1 hour, +2 hours)

```elixir
# In mix.exs
defp deps do
  [
    {:stream_data, "~> 1.1", only: [:test, :dev]},
    {:ex_machina, "~> 2.7", only: :test}
  ]
end
```

### Factory Usage Examples

```elixir
# Create and persist a tenant
tenant = insert(:tenant)
# Result: %Tenant{id: "tenant-1", name: "Tenant 1", status: :active}

# Create a campaign with associations
campaign = insert(:campaign, tenant: tenant)
# Result: %Campaign{name: "Campaign 2", description: "Description for campaign 2", ...}

# Create specialized variants
suspended_tenant = insert(:suspended_tenant)
paused_campaign = insert(:paused_campaign)

# Build without persisting
tenant_struct = build(:tenant)

# Override factory defaults
custom_campaign = insert(:campaign, name: "Custom Name", tenant: tenant)

# Generate JWT token for authentication
token = CampaignsApi.Factory.jwt_token(tenant.id)
```

### Property-Based Testing Library

Use **StreamData** (Elixir's property-based testing library) with ExUnit:

```elixir
# In mix.exs
defp deps do
  [
    {:stream_data, "~> 0.6", only: [:test, :dev]}
  ]
end
```

### Test Organization

```
test/
├── campaigns_managment_api/
│   ├── tenants/
│   │   ├── tenant_test.exs (unit tests)
│   │   └── tenant_property_test.exs (property tests)
│   └── campaign_management/
│       ├── campaign_test.exs (unit tests)
│       └── campaign_property_test.exs (property tests)
├── campaigns_managment_api_web/
│   ├── controllers/
│   │   ├── campaign_controller_test.exs (unit tests)
│   │   └── campaign_controller_property_test.exs (property tests)
│   └── plugs/
│       ├── require_auth_test.exs (unit tests)
│       └── assign_tenant_test.exs (unit tests)
└── support/
    ├── factory.ex (ExMachina factories)
    ├── generators.ex (StreamData generators)
    ├── data_case.ex (imports Factory)
    └── conn_case.ex (imports Factory)
```

### Available Factories

The following factories are available in `test/support/factory.ex`:

**Tenant Factories**:
- `:tenant` - Active tenant with random company name
- `:suspended_tenant` - Tenant with suspended status
- `:deleted_tenant` - Soft-deleted tenant with deleted_at timestamp

**Campaign Factories**:
- `:campaign` - Active campaign with random product name and description
- `:campaign_with_dates` - Campaign with valid start_time and end_time
- `:paused_campaign` - Campaign with paused status

**Helper Functions**:
- `jwt_token(tenant_id)` - Generate JWT token for authentication tests

### Property Test Configuration

Each property test must:
1. Run minimum 100 iterations
2. Include a comment tag referencing the design property
3. Use StreamData generators for input generation
4. Test the universal property across all generated inputs

Example property test structure:

```elixir
defmodule CampaignsManagmentApi.CampaignManagement.CampaignPropertyTest do
  use ExUnit.Case
  use ExUnitProperties
  
  # Feature: campaign-management-api, Property 11: Date Order Validation
  property "campaigns with both dates must have start_time before end_time" do
    check all start_time <- datetime_generator(),
              end_time <- datetime_generator(),
              start_time < end_time do
      
      attrs = %{
        name: "Test Campaign",
        start_time: start_time,
        end_time: end_time
      }
      
      assert {:ok, campaign} = CampaignManagement.create_campaign("tenant-1", attrs)
      assert DateTime.compare(campaign.start_time, campaign.end_time) == :lt
    end
  end
end
```

### Key Test Scenarios

**Authentication & Authorization**:
- Valid JWT with tenant_id → Success
- Missing Authorization header → 401
- JWT without tenant_id → 401
- Deleted tenant → 403
- Suspended tenant → 403
- Active tenant → Success

**JIT Provisioning**:
- New tenant_id → Creates tenant
- Existing tenant_id → Loads tenant
- Multiple requests with same tenant_id → No duplicates

**Data Isolation**:
- Tenant A cannot see Tenant B's campaigns
- Tenant A cannot update Tenant B's campaigns
- Tenant A cannot delete Tenant B's campaigns
- Cross-tenant access returns 404 (not 403 to avoid information leakage)

**Campaign CRUD**:
- Create with all date combinations (4 scenarios)
- Create with invalid dates (start > end) → 422
- Update campaign fields
- Update with invalid dates → 422
- Delete campaign → 204
- Get non-existent campaign → 404

**Pagination**:
- List without cursor → First page
- List with cursor → Campaigns after cursor
- List with limit → Respects limit (max 100)
- List with more data → Includes next_cursor
- List with no more data → No next_cursor

### Test Data Generators

**ExMachina Factories** (for unit and integration tests):
- Use simple, deterministic data generation
- Defined in `test/support/factory.ex`
- Provide consistent, reusable test data patterns
- Sequential IDs and predictable values for reproducibility

**StreamData Generators** (for property-based tests):
- Valid tenant_ids (strings)
- Valid campaign names (strings, min 3 chars)
- Optional descriptions
- Valid datetime values (UTC)
- Campaign status values (:active, :paused)
- Tenant status values (:active, :suspended, :deleted)
- Valid JWT tokens with tenant_id claims
- Defined in `test/support/generators.ex`

### Coverage Goals

- 100% of correctness properties implemented as property tests
- All edge cases covered by unit tests
- All error paths tested
- All controller actions tested
- All plug behaviors tested
- Integration tests for complete request flows
