# Implementation Plan: Campaign Management API

## Overview

This implementation plan breaks down the Campaign Management API into incremental coding tasks. The approach follows Phoenix best practices, starting with database schema and migrations, then building contexts, plugs, and finally the controller layer. Testing tasks are included as optional sub-tasks to validate correctness properties and edge cases.

## Tasks

- [ ] 1. Set up database schema and migrations
  - [x] 1.1 Create tenants table migration
    - Create migration file for tenants table with fields: id (string, PK), name, status (enum), deleted_at, timestamps
    - Add index on status field
    - _Requirements: 2.5, 10.1_
  
  - [x] 1.2 Create campaigns table migration
    - Create migration file for campaigns table with fields: id (UUID, PK), tenant_id (FK), name, description, start_time, end_time, status (enum), timestamps
    - Add foreign key constraint to tenants.id with on_delete: :restrict
    - Add composite index on (tenant_id, id)
    - Add index on (tenant_id, inserted_at) for pagination
    - _Requirements: 4.1, 8.3, 10.2_
  
  - [x] 1.3 Run migrations
    - Execute `mix ecto.migrate` to create tables
    - _Requirements: 10.1, 10.2_

- [ ] 2. Implement Tenant schema and context
  - [x] 2.1 Create Tenant schema
    - Define Tenants.Tenant schema with all fields and Ecto.Enum for status
    - Implement changeset with validations (name required, min length 1)
    - Add Jason.Encoder derivation for JSON serialization
    - _Requirements: 2.5, 10.1_
  
  - [x] 2.2 Write property test for Tenant schema
    - **Property 4: Tenant Schema Completeness**
    - **Validates: Requirements 2.5, 10.1**
  
  - [x] 2.3 Create Tenants context
    - Implement get_tenant/1 function
    - Implement create_tenant/2 function with JIT provisioning logic
    - Implement get_or_create_tenant/1 function
    - Implement tenant_active?/1 function to check status
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 3.1, 3.2, 3.3_
  
  - [x] 2.4 Write property tests for Tenants context
    - **Property 2: JIT Tenant Creation**
    - **Property 3: JIT Tenant Idempotence**
    - **Property 5: Non-Active Tenant Access Denial**
    - **Property 6: Active Tenant Access Permission**
    - **Validates: Requirements 2.1, 2.2, 2.3, 2.4, 3.1, 3.2, 3.3**
  
  - [x] 2.5 Write unit tests for Tenants context
    - Test tenant creation with explicit name from JWT claim
    - Test tenant creation with fallback to tenant_id as name
    - Test loading existing tenant
    - Test tenant_active? with all status values
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 3.1, 3.2, 3.3_

- [ ] 3. Implement Campaign schema and Pagination module
  - [x] 3.1 Create Campaign schema
    - Define CampaignManagement.Campaign schema with all fields
    - Implement changeset with validations (name min 3 chars, date order validation)
    - Add custom validate_date_order/1 function
    - Add Jason.Encoder derivation for JSON serialization
    - _Requirements: 4.5, 4.9, 10.2_
  
  - [x] 3.2 Write property tests for Campaign schema
    - **Property 9: Campaign Name Validation**
    - **Property 11: Date Order Validation**
    - **Validates: Requirements 4.5, 4.9**
  
  - [x] 3.3 Write unit tests for Campaign schema
    - Test all four date combinations (none, start only, end only, both valid)
    - Test invalid date order (start > end)
    - Test name validation (< 3 chars, >= 3 chars)
    - Test optional description field
    - _Requirements: 4.5, 4.6, 4.7, 4.8, 4.9, 9.1, 9.2, 9.3, 9.4_
  
  - [x] 3.4 Create reusable Pagination module
    - Implement Pagination.paginate/3 function
    - Support configurable cursor_field, limit, order parameters
    - Apply cursor filtering based on sort order
    - Return consistent structure with data, next_cursor, has_more
    - Enforce max limit of 100
    - _Requirements: 5.2, 5.3, 5.4, 5.5, 5.6_
  
  - [x] 3.5 Write property tests for Pagination module
    - **Property 26: Pagination Module Reusability**
    - **Property 15: Cursor-Based Pagination**
    - **Property 16: Pagination Limit Enforcement**
    - **Property 17: Pagination Next Cursor**
    - **Validates: Requirements 5.2, 5.3, 5.4, 5.5, 5.6**

- [x] 4. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 5. Implement CampaignManagement context
  - [x] 5.1 Create CampaignManagement context with list_campaigns/2
    - Implement list_campaigns/2 using Pagination module
    - Filter by tenant_id automatically
    - Pass pagination options to Pagination.paginate/3
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6_
  
  - [x] 5.2 Implement get_campaign/2
    - Query campaign by id and tenant_id
    - Return nil if not found or belongs to different tenant
    - _Requirements: 5.7, 5.8_
  
  - [x] 5.3 Implement create_campaign/2
    - Accept tenant_id and attrs parameters
    - Merge tenant_id into attrs
    - Use Campaign.changeset for validation
    - Insert into database
    - _Requirements: 4.1, 4.2, 4.3, 4.4_
  
  - [x] 5.4 Implement update_campaign/3
    - Accept tenant_id, campaign_id, and attrs parameters
    - Get campaign with tenant_id filter
    - Return {:error, :not_found} if not found
    - Use Campaign.changeset for validation
    - Update in database
    - _Requirements: 6.1, 6.2, 6.3, 6.4_
  
  - [x] 5.5 Implement delete_campaign/2
    - Accept tenant_id and campaign_id parameters
    - Get campaign with tenant_id filter
    - Return {:error, :not_found} if not found
    - Delete from database (hard delete)
    - _Requirements: 7.1, 7.2_
  
  - [x] 5.6 Write property tests for CampaignManagement context
    - **Property 7: Campaign Creation with Tenant Association**
    - **Property 8: Campaign Default Status**
    - **Property 10: Optional Campaign Fields**
    - **Property 12: UTC Timezone Storage**
    - **Property 13: Tenant Data Isolation**
    - **Property 14: Campaign List Ordering**
    - **Property 18: Default Pagination Behavior**
    - **Property 19: Campaign Response Schema**
    - **Property 20: Campaign Field Mutability**
    - **Property 21: Campaign Status Transitions**
    - **Property 22: Hard Delete Behavior**
    - **Validates: Requirements 4.1, 4.2, 4.3, 4.4, 4.10, 5.1, 5.2, 5.6, 5.7, 5.8, 5.10, 6.1, 6.2, 6.6, 7.1**
  
  - [x] 5.7 Write unit tests for CampaignManagement context
    - Test cross-tenant access returns nil (not found)
    - Test campaign creation with foreign key violation
    - Test pagination with various dataset sizes
    - Test update with invalid data returns changeset errors
    - Test delete non-existent campaign
    - _Requirements: 5.8, 6.4, 7.2, 7.3, 8.3, 8.4_

- [ ] 6. Implement authentication plugs
  - [x] 6.1 Add joken dependency
    - Add `{:joken, "~> 2.6"}` to mix.exs deps
    - Run `mix deps.get`
    - _Requirements: 1.1_
  
  - [x] 6.2 Create RequireAuth plug
    - Implement init/1 and call/2 functions
    - Extract Authorization header
    - Parse "Bearer <token>" format
    - Use Joken.peek_claims/1 to decode JWT without verification
    - Extract tenant_id claim
    - Assign tenant_id to conn.assigns
    - Return 401 if auth fails
    - _Requirements: 1.1, 1.2, 1.3_
  
  - [x] 6.3 Write unit tests for RequireAuth plug
    - Test valid JWT with tenant_id claim extracts tenant_id
    - Test missing Authorization header returns 401
    - Test JWT without tenant_id claim returns 401
    - Test invalid JWT format returns 401
    - _Requirements: 1.1, 1.2, 1.3_
  
  - [x] 6.4 Write property test for RequireAuth plug
    - **Property 1: JWT Tenant ID Extraction**
    - **Validates: Requirements 1.1**
  
  - [x] 6.5 Create AssignTenant plug
    - Implement init/1 and call/2 functions
    - Get tenant_id from conn.assigns
    - Call Tenants.get_or_create_tenant/1
    - Check tenant status with Tenants.tenant_active?/1
    - Assign tenant to conn.assigns if active
    - Return 403 if tenant not active
    - Return 500 on unexpected errors
    - _Requirements: 2.1, 2.4, 3.1, 3.2, 3.3_
  
  - [x] 6.6 Write unit tests for AssignTenant plug
    - Test new tenant_id creates tenant (JIT)
    - Test existing tenant_id loads tenant
    - Test deleted tenant returns 403
    - Test suspended tenant returns 403
    - Test active tenant assigns to conn
    - _Requirements: 2.1, 2.4, 3.1, 3.2, 3.3_

- [x] 7. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 8. Implement CampaignController
  - [x] 8.1 Create CampaignController with create action
    - Implement create/2 function
    - Extract tenant_id from conn.assigns.tenant.id
    - Call CampaignManagement.create_campaign/2
    - Return 201 with campaign JSON on success
    - Return 422 with error details on validation failure
    - Use translate_errors/1 helper for changeset errors
    - _Requirements: 4.1, 4.11_
  
  - [x] 8.2 Implement index action
    - Extract tenant_id from conn.assigns.tenant.id
    - Parse limit and cursor from query params
    - Call CampaignManagement.list_campaigns/2 with options
    - Return 200 with pagination result JSON
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6_
  
  - [x] 8.3 Implement show action
    - Extract tenant_id from conn.assigns.tenant.id
    - Extract campaign id from path params
    - Call CampaignManagement.get_campaign/2
    - Return 200 with campaign JSON if found
    - Return 404 if not found
    - _Requirements: 5.7, 5.8, 5.9_
  
  - [x] 8.4 Implement update action
    - Extract tenant_id from conn.assigns.tenant.id
    - Extract campaign id from path params
    - Call CampaignManagement.update_campaign/3
    - Return 200 with updated campaign JSON on success
    - Return 404 if not found
    - Return 422 with error details on validation failure
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5_
  
  - [x] 8.5 Implement delete action
    - Extract tenant_id from conn.assigns.tenant.id
    - Extract campaign id from path params
    - Call CampaignManagement.delete_campaign/2
    - Return 204 No Content on success
    - Return 404 if not found
    - _Requirements: 7.1, 7.2, 7.3, 7.4_
  
  - [x] 8.6 Add helper functions
    - Implement translate_errors/1 for changeset error formatting
    - Implement parse_int/1 for limit parameter parsing
    - Implement parse_datetime/1 for cursor parameter parsing
    - _Requirements: 4.11, 5.3, 5.4, 6.5, 11.1, 11.6_
  
  - [x] 8.7 Write integration tests for CampaignController
    - Test complete request flow: auth → JIT → create campaign
    - Test unauthenticated request returns 401
    - Test deleted tenant returns 403
    - Test cross-tenant access returns 404
    - Test all CRUD operations with valid data
    - Test validation errors return 422 with structured JSON
    - Test pagination with cursor and limit parameters
    - _Requirements: 1.2, 3.1, 4.1, 4.11, 5.1, 5.8, 6.4, 7.2, 11.1, 11.2, 11.3, 11.4, 11.6_
  
  - [x] 8.8 Write property tests for CampaignController
    - **Property 23: Successful Deletion Response**
    - **Property 24: Foreign Key Constraint Enforcement**
    - **Property 25: Structured Error Responses**
    - **Validates: Requirements 7.4, 8.3, 8.4, 11.1, 11.6**

- [ ] 9. Configure router and pipeline
  - [x] 9.1 Update router.ex
    - Define :authenticated pipeline with RequireAuth and AssignTenant plugs
    - Add /api scope with :api and :authenticated pipelines
    - Add campaigns resource routes (except :new, :edit)
    - _Requirements: 1.1, 2.1, 12.5, 12.6, 12.7_
  
  - [x] 9.2 Write router integration tests
    - Test all routes are properly configured
    - Test authenticated pipeline is applied
    - Test plugs are executed in correct order
    - _Requirements: 1.1, 2.1_

- [ ] 10. Create StreamData generators for property tests
  - [x] 10.1 Create test/support/generators.ex
    - Implement tenant_id_generator/0 for valid tenant IDs
    - Implement campaign_name_generator/0 for valid names (min 3 chars)
    - Implement datetime_generator/0 for UTC datetimes
    - Implement campaign_status_generator/0 for :active, :paused
    - Implement tenant_status_generator/0 for :active, :suspended, :deleted
    - Implement jwt_generator/1 for JWT tokens with claims
    - Implement optional_field_generator/1 for nullable fields
    - _Requirements: All property tests_
  
  - [x] 10.2 Write generator validation tests
    - Test generators produce valid data
    - Test generators cover edge cases
    - _Requirements: All property tests_

- [ ] 11. Add example tests for flexible date management
  - [x] 11.1 Write example test: Campaign without dates
    - Create campaign with neither start_time nor end_time
    - Verify creation succeeds
    - **Validates: Requirements 9.1**
  
  - [x] 11.2 Write example test: Campaign with start_time only
    - Create campaign with start_time but no end_time
    - Verify creation succeeds
    - **Validates: Requirements 9.2**
  
  - [x] 11.3 Write example test: Campaign with end_time only
    - Create campaign with end_time but no start_time
    - Verify creation succeeds
    - **Validates: Requirements 9.3**
  
  - [x] 11.4 Write example test: Campaign with both dates
    - Create campaign with start_time before end_time
    - Verify creation succeeds
    - **Validates: Requirements 9.4**

- [x] 12. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation at key milestones
- Property tests validate universal correctness properties (minimum 100 iterations each)
- Unit tests validate specific examples, edge cases, and integration points
- StreamData generators enable comprehensive property-based testing
- All datetime handling uses UTC timezone
- Foreign key constraints ensure referential integrity
- Pagination module is reusable across all future resources
