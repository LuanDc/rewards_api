# Feature Implementation Request

## Overview

Implement complete CRUD for Campaigns with multi-tenant support, OAuth2 Client Credentials authentication, and specific business rules for date and status management.

## Context

- Current state: Freshly created Phoenix application (mix phx.new), no schemas or contexts implemented yet
- Problem/Need: Need to manage reward campaigns for multiple clients (tenants) in an isolated and secure manner
- Related files/modules: None yet - first feature of the microservice

## Requirements

### Functional Requirements

- [ ] Implement multi-tenant authentication via OAuth2 Client Credentials flow (initial mock)
- [ ] Extract tenant_id from JWT token for data isolation
- [ ] JIT (Just-in-Time) Provisioning of tenants on first access
- [ ] Tenants table with soft delete
- [ ] Complete CRUD for campaigns (Create, Read, Update, Delete)
- [ ] Support for campaigns with flexible dates (with/without start, with/without end)
- [ ] Campaign status management (active/paused)
- [ ] Date validation when both are provided (start_time < end_time)
- [ ] Store dates in UTC

### Technical Requirements

- Technology/Framework: Phoenix 1.7+, Elixir, Ecto
- Database changes: Yes
  
  **Table `tenants`:**
    - `id` (string, primary key) # same value as tenant_id from JWT
    - `name` (string, not null)
    - `status` (enum: active/suspended/deleted, not null, default: active)
    - `deleted_at` (utc_datetime, nullable) # soft delete
    - `inserted_at`, `updated_at` (timestamps)
  
  **Table `campaigns`:**
    - `id` (UUID, primary key)
    - `tenant_id` (string, not null, foreign key -> tenants.id)
    - `name` (string, not null)
    - `description` (text, nullable)
    - `start_time` (utc_datetime, nullable)
    - `end_time` (utc_datetime, nullable)
    - `status` (enum: active/paused, not null, default: active)
    - `inserted_at`, `updated_at` (timestamps)
  
  **Indexes:**
    - `campaigns`: composite index on `(tenant_id, id)` for efficient queries
    - `tenants`: index on `status` for filters
  
- API endpoints:
  - `POST /api/campaigns` - Create campaign
  - `GET /api/campaigns` - List tenant's campaigns
  - `GET /api/campaigns/:id` - Get specific campaign
  - `PUT /api/campaigns/:id` - Update campaign
  - `DELETE /api/campaigns/:id` - Delete campaign
  
- Dependencies:
  - `joken` - To decode JWT (without signature validation in mock)
  - `plug` - For authentication middleware (already included in Phoenix)

## Acceptance Criteria

1. Authenticated client via Client Credentials can create campaign and it's associated with their tenant_id
2. Tenant is automatically created (JIT) on first access if it doesn't exist
3. Tenants with `deleted` or `suspended` status cannot access the API (403)
4. Campaigns are isolated by tenant - one tenant cannot see/edit another's campaigns
5. System accepts all date combinations:
   - Without start_time and without end_time ✓
   - With start_time and without end_time ✓
   - Without start_time and with end_time ✓
   - With start_time and end_time (validating start < end) ✓
6. Dates are stored in UTC in the database
7. Status can be changed between active and paused
8. Validations return clear and structured errors (JSON)
9. Access attempt without authentication returns 401
10. Attempt to access another tenant's campaign returns 404
11. Foreign key constraint prevents creating campaign for non-existent tenant

## Implementation Notes

### Architecture
- Follow Phoenix Contexts pattern:
  - `Tenants` context for tenant management
  - `CampaignManagement` context for campaigns
- Schemas:
  - `Tenants.Tenant`
  - `CampaignManagement.Campaign`
- Controller: `CampaignsManagmentApiWeb.CampaignController`
- Plugs:
  - `CampaignsManagmentApiWeb.Plugs.RequireAuth` - validates JWT and extracts tenant_id
  - `CampaignsManagmentApiWeb.Plugs.AssignTenant` - JIT provisioning of tenant

### JIT (Just-in-Time) Provisioning
- On first access with a new tenant_id, automatically create record in `tenants` table
- Extract `name` from JWT claim (if available) or use tenant_id as fallback
- Initial status: `active`
- If tenant already exists, just load and assign to conn
- If tenant has `deleted` status, return 403 Forbidden

### Security Considerations
- Validate and decode JWT (mock without signature validation)
- Extract tenant_id from `tenant_id` claim
- All campaign queries must filter by tenant_id automatically
- Block access to tenants with `deleted` or `suspended` status
- Foreign key constraint ensures referential integrity

### Performance Considerations
- Composite index (tenant_id, id) for fast queries
- Pagination in listings (consider for future)

### Error Handling
- Return structured JSON with errors
- Appropriate status codes (400, 401, 404, 422, 500)
- Clear error messages in English

### Validations
- Name required, minimum 3 characters
- Description optional
- If start_time and end_time provided: start_time < end_time
- Status must be "active" or "paused"
- Dates must be valid and in ISO8601 format

## Out of Scope

- Rewards system (next feature)
- Participation rules
- Participant tracking
- Points system
- Notifications
- Change auditing
- Campaign soft delete
- Campaign versioning
- Web interface/dashboard

## Decisions Made

### Authentication & Multi-tenancy
1. **OAuth2 Provider**: Simple mock initially, future migration to Keycloak
2. **JWT Claim**: `tenant_id` (multi-tenant standard, Keycloak compatible)
3. **tenant_id Format**: String (e.g., "acme-corp", "tech-startup") - readable and flexible
4. **Mock Auth**: Simple plug that extracts `tenant_id` from `Authorization: Bearer <token>` header where token contains `tenant_id` claim
5. **Tenant Management**: `tenants` table in database with JIT provisioning
6. **Soft Delete**: Tenants marked as deleted (not physically removed)

### Implementation Details
- **Token validation**: Initial mock only validates presence of `tenant_id` claim, no signature verification
- **JIT Provisioning**: Tenant automatically created on first access
- **Tenant Status**: active (default), suspended (blocked), deleted (soft delete)
- **Timezone**: Always work in UTC, client sends/receives in UTC (ISO8601)
- **Pagination**: Not implemented initially, return all tenant's campaigns
- **Filters**: Not implemented initially, just list all
- **Ordering**: `inserted_at DESC` (most recent campaigns first)
- **Campaign Delete**: Hard delete (physical removal from database)

## Questions/Clarifications Needed

1. **Campaign name**: Must be unique per tenant or can repeat? → Can repeat
2. **Auditing**: Record who created/modified (user_id from token)? → Not for now
3. **Campaign limit**: Is there a limit per tenant? → Not for now
4. **Tenant name in JWT**: Besides `tenant_id`, will JWT have `tenant_name` claim? → Optional, use tenant_id as fallback

