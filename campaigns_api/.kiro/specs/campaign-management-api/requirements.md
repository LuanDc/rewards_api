# Requirements Document: Campaign Management API

## Introduction

This document specifies the requirements for a multi-tenant Campaign Management API built with Phoenix/Elixir. The system enables multiple clients (tenants) to manage reward campaigns in an isolated and secure manner using OAuth2 Client Credentials authentication. The API provides complete CRUD operations for campaigns with flexible date management and status controls.

## Glossary

- **System**: The Campaign Management API application
- **Tenant**: An isolated client organization identified by a unique tenant_id
- **Campaign**: A reward campaign entity belonging to a specific tenant
- **JWT**: JSON Web Token used for authentication
- **JIT_Provisioning**: Just-in-Time automatic creation of tenant records on first access
- **Client_Credentials**: OAuth2 authentication flow for machine-to-machine communication
- **Soft_Delete**: Marking a record as deleted without physical removal from database
- **UTC**: Coordinated Universal Time timezone standard

## Requirements

### Requirement 1: Multi-Tenant Authentication

**User Story:** As a client application, I want to authenticate using OAuth2 Client Credentials, so that I can securely access the API with my tenant identity.

#### Acceptance Criteria

1. WHEN a request includes a valid JWT in the Authorization header, THE System SHALL extract the tenant_id from the token's tenant_id claim
2. WHEN a request does not include an Authorization header, THE System SHALL return HTTP 401 Unauthorized
3. WHEN a request includes a JWT without a tenant_id claim, THE System SHALL return HTTP 401 Unauthorized
4. THE System SHALL decode JWT tokens without signature validation in the initial mock implementation

### Requirement 2: Just-in-Time Tenant Provisioning

**User Story:** As a new client, I want my tenant account to be automatically created on first access, so that I can start using the API immediately after authentication.

#### Acceptance Criteria

1. WHEN a request contains a tenant_id that does not exist in the tenants table, THE System SHALL create a new tenant record with status "active"
2. WHEN creating a new tenant record, THE System SHALL use the tenant_id from the JWT as the primary key
3. WHEN creating a new tenant record, THE System SHALL extract the name from the JWT name claim if available, otherwise use the tenant_id as the name
4. WHEN a request contains a tenant_id that already exists, THE System SHALL load the existing tenant record
5. THE System SHALL store tenant records with fields: id, name, status, deleted_at, inserted_at, updated_at

### Requirement 3: Tenant Access Control

**User Story:** As a system administrator, I want to control tenant access based on their status, so that I can suspend or remove problematic tenants.

#### Acceptance Criteria

1. WHEN a tenant has status "deleted", THE System SHALL return HTTP 403 Forbidden for all API requests
2. WHEN a tenant has status "suspended", THE System SHALL return HTTP 403 Forbidden for all API requests
3. WHEN a tenant has status "active", THE System SHALL allow API access
4. THE System SHALL support tenant status values: active, suspended, deleted

### Requirement 4: Campaign Creation

**User Story:** As an authenticated client, I want to create campaigns for my tenant, so that I can manage reward programs.

#### Acceptance Criteria

1. WHEN an authenticated client sends a POST request to /api/campaigns with valid campaign data, THE System SHALL create a new campaign associated with the client's tenant_id
2. WHEN creating a campaign, THE System SHALL generate a UUID as the campaign id
3. WHEN creating a campaign, THE System SHALL set the default status to "active" if not provided
4. WHEN creating a campaign, THE System SHALL store the tenant_id from the authenticated client
5. THE System SHALL require the name field with minimum 3 characters
6. THE System SHALL accept optional description field
7. THE System SHALL accept optional start_time field in ISO8601 format
8. THE System SHALL accept optional end_time field in ISO8601 format
9. WHEN both start_time and end_time are provided, THE System SHALL validate that start_time is before end_time
10. THE System SHALL store all datetime values in UTC timezone
11. WHEN campaign creation fails validation, THE System SHALL return HTTP 422 with structured JSON error details

### Requirement 5: Campaign Retrieval

**User Story:** As an authenticated client, I want to retrieve my campaigns with pagination support, so that I can efficiently view and manage large numbers of campaigns.

#### Acceptance Criteria

1. WHEN an authenticated client sends a GET request to /api/campaigns, THE System SHALL return campaigns belonging to the client's tenant_id with cursor-based pagination
2. WHEN returning campaign lists, THE System SHALL order campaigns by inserted_at in descending order
3. WHEN a client provides a cursor parameter, THE System SHALL return campaigns after that cursor position
4. WHEN a client provides a limit parameter, THE System SHALL return at most that number of campaigns (default 50, maximum 100)
5. WHEN returning paginated results, THE System SHALL include a next_cursor field if more campaigns exist
6. WHEN no cursor parameter is provided, THE System SHALL return the first page of campaigns
7. WHEN an authenticated client sends a GET request to /api/campaigns/:id, THE System SHALL return the campaign if it belongs to the client's tenant_id
8. WHEN an authenticated client requests a campaign belonging to a different tenant, THE System SHALL return HTTP 404 Not Found
9. WHEN an authenticated client requests a non-existent campaign, THE System SHALL return HTTP 404 Not Found
10. THE System SHALL return campaign data including: id, tenant_id, name, description, start_time, end_time, status, inserted_at, updated_at

### Requirement 6: Campaign Updates

**User Story:** As an authenticated client, I want to update my campaigns, so that I can modify campaign details and status.

#### Acceptance Criteria

1. WHEN an authenticated client sends a PUT request to /api/campaigns/:id with valid data, THE System SHALL update the campaign if it belongs to the client's tenant_id
2. WHEN updating a campaign, THE System SHALL allow changing name, description, start_time, end_time, and status fields
3. WHEN updating a campaign with both start_time and end_time, THE System SHALL validate that start_time is before end_time
4. WHEN an authenticated client attempts to update a campaign belonging to a different tenant, THE System SHALL return HTTP 404 Not Found
5. WHEN campaign update fails validation, THE System SHALL return HTTP 422 with structured JSON error details
6. THE System SHALL allow status changes between "active" and "paused"

### Requirement 7: Campaign Deletion

**User Story:** As an authenticated client, I want to delete campaigns, so that I can remove campaigns that are no longer needed.

#### Acceptance Criteria

1. WHEN an authenticated client sends a DELETE request to /api/campaigns/:id, THE System SHALL permanently remove the campaign if it belongs to the client's tenant_id
2. WHEN an authenticated client attempts to delete a campaign belonging to a different tenant, THE System SHALL return HTTP 404 Not Found
3. WHEN deleting a non-existent campaign, THE System SHALL return HTTP 404 Not Found
4. WHEN a campaign is successfully deleted, THE System SHALL return HTTP 204 No Content

### Requirement 8: Data Isolation

**User Story:** As a tenant, I want my campaign data to be completely isolated from other tenants, so that my data remains private and secure.

#### Acceptance Criteria

1. THE System SHALL filter all campaign queries by the authenticated tenant_id automatically
2. THE System SHALL prevent any tenant from accessing campaigns belonging to other tenants
3. THE System SHALL enforce foreign key constraint between campaigns.tenant_id and tenants.id
4. WHEN attempting to create a campaign for a non-existent tenant_id, THE System SHALL reject the operation with a database constraint error

### Requirement 9: Flexible Date Management

**User Story:** As a campaign manager, I want to create campaigns with flexible date configurations, so that I can support various campaign types.

#### Acceptance Criteria

1. THE System SHALL accept campaigns without start_time and without end_time
2. THE System SHALL accept campaigns with start_time and without end_time
3. THE System SHALL accept campaigns without start_time and with end_time
4. THE System SHALL accept campaigns with both start_time and end_time when start_time is before end_time
5. WHEN both start_time and end_time are provided and start_time is not before end_time, THE System SHALL reject the campaign with validation error

### Requirement 10: Database Schema and Indexing

**User Story:** As a system architect, I want efficient database schema and indexing, so that the system performs well at scale.

#### Acceptance Criteria

1. THE System SHALL store tenants with fields: id (string, primary key), name (string, not null), status (enum, not null, default active), deleted_at (utc_datetime, nullable), inserted_at, updated_at
2. THE System SHALL store campaigns with fields: id (UUID, primary key), tenant_id (string, not null, foreign key), name (string, not null), description (text, nullable), start_time (utc_datetime, nullable), end_time (utc_datetime, nullable), status (enum, not null, default active), inserted_at, updated_at
3. THE System SHALL create a composite index on campaigns (tenant_id, id)
4. THE System SHALL create an index on tenants (status)
5. THE System SHALL enforce foreign key constraint from campaigns.tenant_id to tenants.id

### Requirement 11: Error Handling and Responses

**User Story:** As an API consumer, I want clear and structured error messages, so that I can understand and fix issues quickly.

#### Acceptance Criteria

1. WHEN validation fails, THE System SHALL return HTTP 422 with JSON containing error details
2. WHEN authentication fails, THE System SHALL return HTTP 401 with appropriate error message
3. WHEN authorization fails due to tenant status, THE System SHALL return HTTP 403 with appropriate error message
4. WHEN a resource is not found, THE System SHALL return HTTP 404
5. WHEN an operation succeeds, THE System SHALL return appropriate success status codes (200, 201, 204)
6. THE System SHALL format all error responses as structured JSON

### Requirement 12: Phoenix Architecture Compliance

**User Story:** As a developer, I want the codebase to follow Phoenix best practices, so that the application is maintainable and extensible.

#### Acceptance Criteria

1. THE System SHALL organize tenant management logic in a Tenants context
2. THE System SHALL organize campaign management logic in a CampaignManagement context
3. THE System SHALL define a Tenants.Tenant schema
4. THE System SHALL define a CampaignManagement.Campaign schema
5. THE System SHALL implement a CampaignsManagmentApiWeb.CampaignController for HTTP handling
6. THE System SHALL implement a CampaignsManagmentApiWeb.Plugs.RequireAuth plug for JWT validation
7. THE System SHALL implement a CampaignsManagmentApiWeb.Plugs.AssignTenant plug for JIT provisioning
