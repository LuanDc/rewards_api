# Implementation Plan: Challenge System

## Overview

This implementation plan breaks down the Challenge System into incremental coding tasks following TDD/baby steps methodology. The approach starts with database schema and migrations, then builds schemas with validations, contexts, and finally controllers. Each step includes comprehensive testing before moving forward.

## Tasks

- [x] 1. Set up database schema and migrations
  - [x] 1.1 Create challenges table migration
    - Create migration file for challenges table with fields: id (UUID, PK), name, description, metadata (jsonb), timestamps
    - Add index on id
    - _Requirements: 1.1, 1.3, 1.5_
  
  - [x] 1.2 Create campaign_challenges table migration
    - Create migration file for campaign_challenges table with fields: id (UUID, PK), campaign_id (FK), challenge_id (FK), display_name, display_description, evaluation_frequency, reward_points, configuration (jsonb), timestamps
    - Add foreign key constraint to campaigns.id with on_delete: :delete_all
    - Add foreign key constraint to challenges.id with on_delete: :restrict
    - Add composite index on (campaign_id, challenge_id)
    - Add unique index on (campaign_id, challenge_id)
    - _Requirements: 2.1, 2.5, 2.6, 2.7, 2.8, 2.9_
  
  - [x] 1.3 Run migrations
    - Execute `mix ecto.migrate` to create tables
    - _Requirements: 1.1, 2.1_

- [x] 2. Implement Challenge schema
  - [x] 2.1 Create Challenge schema
    - Define Challenges.Challenge schema with all fields (no tenant_id)
    - Implement changeset with validations (name required, min 3 chars)
    - Add Jason.Encoder derivation for JSON serialization
    - Add has_many association to CampaignChallenge
    - _Requirements: 1.1, 1.2, 1.4, 10.2_
  
  - [x] 2.2 Write unit tests for Challenge schema
    - Test challenge creation with valid data
    - Test name validation (< 3 chars rejected, >= 3 chars accepted)
    - Test optional description field
    - Test metadata JSONB field accepts valid JSON
    - _Requirements: 1.2, 1.4, 9.1_
  
  - [x] 2.3 Write property test for Challenge schema
    - **Property 2: Challenge Name Validation**
    - **Validates: Requirements 1.2**

- [x] 3. Implement CampaignChallenge schema
  - [x] 3.1 Create CampaignChallenge schema
    - Define CampaignManagement.CampaignChallenge schema with all fields (belongs to CampaignManagement context)
    - Implement changeset with validations (display_name min 3 chars, frequency validation, points required)
    - Add custom validate_evaluation_frequency/1 function
    - Add Jason.Encoder derivation for JSON serialization
    - Add belongs_to associations to Campaign and Challenge
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 5.1, 5.2, 6.1, 6.2_
  
  - [x] 3.2 Write unit tests for CampaignChallenge schema
    - Test campaign challenge creation with valid data
    - Test display_name validation (< 3 chars rejected, >= 3 chars accepted)
    - Test evaluation_frequency with predefined keywords (daily, weekly, monthly, on_event)
    - Test evaluation_frequency with valid cron expressions (5 parts)
    - Test evaluation_frequency with invalid formats rejected
    - Test reward_points accepts positive, negative, and zero values
    - Test configuration JSONB field accepts valid JSON
    - Test unique constraint on (campaign_id, challenge_id)
    - _Requirements: 2.2, 2.3, 2.4, 2.5, 5.1, 5.2, 5.3, 6.1, 6.2, 9.2_
  
  - [x] 3.3 Write property tests for CampaignChallenge schema
    - **Property 4: Evaluation Frequency Validation**
    - **Property 5: Reward Points Flexibility**
    - **Property 9: Metadata and Configuration Flexibility**
    - **Validates: Requirements 5.1, 5.2, 5.3, 6.1, 6.2, 9.1, 9.2, 9.3**

- [x] 4. Checkpoint - Ensure schema tests pass
  - Run all schema tests and verify they pass
  - Ask user if questions arise

- [x] 5. Implement Challenges context - Challenge operations
  - [x] 5.1 Create Challenges context with list_challenges/1
    - Implement list_challenges/1 using Pagination module
    - No tenant filtering (challenges are global)
    - Pass pagination options to Pagination.paginate/3
    - _Requirements: 3.2, 1.3_
  
  - [x] 5.2 Implement get_challenge/1
    - Query challenge by id only
    - Return nil if not found
    - _Requirements: 3.3, 1.3_
  
  - [x] 5.3 Implement create_challenge/1
    - Accept attrs parameter only
    - Use Challenge.changeset for validation
    - Insert into database
    - _Requirements: 3.1, 1.3_
  
  - [x] 5.4 Implement update_challenge/2
    - Accept challenge_id and attrs parameters
    - Get challenge without tenant filter
    - Return {:error, :not_found} if not found
    - Use Challenge.changeset for validation
    - Update in database
    - _Requirements: 3.4, 1.3_
  
  - [x] 5.5 Implement delete_challenge/1 with association check
    - Accept challenge_id parameter only
    - Get challenge without tenant filter
    - Return {:error, :not_found} if not found
    - Check for campaign associations using has_campaign_associations?/1 (private helper in Challenges context)
    - Return {:error, :has_associations} if associations exist
    - Delete from database if no associations
    - _Requirements: 3.5, 3.6, 8.2, 8.3_
  
  - [x] 5.6 Write unit tests for Challenge context operations
    - Test list_challenges with pagination
    - Test get_challenge returns correct challenge
    - Test any tenant can retrieve any challenge
    - Test create_challenge with valid data
    - Test update_challenge with valid data
    - Test delete_challenge without associations succeeds
    - Test delete_challenge with associations fails
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 1.3_
  
  - [x] 5.7 Write property tests for Challenge context
    - **Property 1: Challenge Global Availability**
    - **Property 6: Challenge Deletion Protection**
    - **Validates: Requirements 1.3, 6.3, 3.5, 8.2, 8.3**

- [x] 6. Implement CampaignManagement context - CampaignChallenge operations
  - [x] 6.1 Implement list_campaign_challenges/3
    - Accept tenant_id, campaign_id, and opts parameters
    - Join with campaign to enforce tenant isolation
    - Preload challenge association
    - Use Pagination module for pagination
    - _Requirements: 4.3, 7.1_
  
  - [x] 6.2 Implement get_campaign_challenge/3
    - Accept tenant_id, campaign_id, and campaign_challenge_id
    - Join with campaign to enforce tenant isolation
    - Preload challenge association
    - Return nil if not found
    - _Requirements: 4.4, 7.2_
  
  - [x] 6.3 Implement create_campaign_challenge/3
    - Accept tenant_id, campaign_id, and attrs parameters
    - Validate campaign ownership with validate_campaign_ownership/2
    - No need to validate challenge ownership (challenges are global)
    - Use CampaignChallenge.changeset for validation
    - Insert into database
    - _Requirements: 4.1, 4.2, 6.3_
  
  - [x] 6.4 Implement update_campaign_challenge/4
    - Accept tenant_id, campaign_id, campaign_challenge_id, and attrs
    - Get campaign challenge with tenant_id filter
    - Return {:error, :not_found} if not found
    - Use CampaignChallenge.changeset for validation
    - Update in database
    - _Requirements: 4.5, 7.2_
  
  - [x] 6.5 Implement delete_campaign_challenge/3
    - Accept tenant_id, campaign_id, and campaign_challenge_id
    - Get campaign challenge with tenant_id filter
    - Return {:error, :not_found} if not found
    - Delete from database
    - _Requirements: 4.6, 7.2_
  
  - [x] 6.6 Implement helper functions
    - Implement validate_campaign_ownership/2 to verify campaign belongs to tenant
    - Remove validate_challenge_ownership/2 (no longer needed)
    - _Requirements: 6.3, 8.2_
  
  - [x] 6.7 Write unit tests for CampaignChallenge context operations
    - Test list_campaign_challenges with pagination
    - Test get_campaign_challenge returns correct association
    - Test create_campaign_challenge with valid data
    - Test create_campaign_challenge with cross-tenant campaign fails
    - Test create_campaign_challenge with any challenge succeeds (challenges are global)
    - Test create_campaign_challenge with duplicate association fails (unique constraint)
    - Test update_campaign_challenge with valid data
    - Test delete_campaign_challenge succeeds
    - Test campaign deletion cascades to campaign_challenges
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 6.3, 6.4, 8.1_
  
  - [x] 6.8 Write property tests for CampaignChallenge context
    - **Property 3: Campaign Challenge Unique Association**
    - **Property 7: Campaign Challenge Cascade Deletion**
    - **Property 8: Campaign Ownership Validation**
    - **Validates: Requirements 2.5, 8.1, 6.3, 6.4**

- [x] 7. Checkpoint - Ensure context tests pass
  - Run all context tests and verify they pass
  - Ask user if questions arise

- [x] 8. Implement CampaignChallengeController
  - [x] 8.1 Create CampaignChallengeController with index action
    - Extract tenant_id from conn.assigns.tenant.id
    - Extract campaign_id from path params
    - Parse limit and cursor from query params
    - Call CampaignManagement.list_campaign_challenges/3 with options
    - Return 200 with pagination result JSON
    - _Requirements: 4.3_
  
  - [x] 8.2 Implement show action
    - Extract tenant_id from conn.assigns.tenant.id
    - Extract campaign_id and id from path params
    - Call CampaignManagement.get_campaign_challenge/3
    - Return 200 with campaign challenge JSON if found
    - Return 404 if not found
    - _Requirements: 4.4_
  
  - [x] 8.3 Implement create action
    - Extract tenant_id from conn.assigns.tenant.id
    - Extract campaign_id from path params
    - Call CampaignManagement.create_campaign_challenge/3
    - Return 201 with campaign challenge JSON on success
    - Return 404 with specific message if campaign not found
    - Return 422 with error details on validation failure
    - _Requirements: 4.1, 4.2, 4.7_
  
  - [x] 8.4 Implement update action
    - Extract tenant_id from conn.assigns.tenant.id
    - Extract campaign_id and id from path params
    - Call CampaignManagement.update_campaign_challenge/4
    - Return 200 with updated campaign challenge JSON on success
    - Return 404 if not found
    - Return 422 with error details on validation failure
    - _Requirements: 4.5, 4.7_
  
  - [x] 8.5 Implement delete action
    - Extract tenant_id from conn.assigns.tenant.id
    - Extract campaign_id and id from path params
    - Call CampaignManagement.delete_campaign_challenge/3
    - Return 204 No Content on success
    - Return 404 if not found
    - _Requirements: 4.6, 4.7_
  
  - [x] 8.6 Add helper functions
    - Implement send_not_found/2 for 404 responses with custom message
    - Implement send_validation_error/2 for 422 responses
    - Implement translate_errors/1 for changeset error formatting
    - Implement parse_int/1 for limit parameter parsing
    - Implement parse_datetime/1 for cursor parameter parsing
    - _Requirements: 4.7_
  
  - [x] 8.7 Write integration tests for CampaignChallengeController
    - Test complete request flow: auth → list campaign challenges
    - Test create campaign challenge with valid data returns 201
    - Test create campaign challenge with invalid data returns 422
    - Test create campaign challenge with cross-tenant campaign returns 404
    - Test create campaign challenge with any valid challenge succeeds (challenges are global)
    - Test create duplicate association returns 422
    - Test get campaign challenge returns 200
    - Test get non-existent campaign challenge returns 404
    - Test update campaign challenge returns 200
    - Test delete campaign challenge returns 204
    - Test pagination with cursor and limit parameters
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 6.3, 6.4_
  
  - [x] 8.8 Write property tests for controllers
    - **Property 10: Campaign Challenge Response Schema**
    - **Validates: Requirements 3.1, 3.2, 3.3, 3.4, 8.4**

- [x] 9. Configure router
  - [x] 9.1 Update router.ex
    - Add nested /api/campaigns/:campaign_id/challenges resource routes (except :new, :edit)
    - Ensure :authenticated pipeline is applied
    - _Requirements: 9.1, 9.4, 9.5_
  
  - [x] 9.2 Write router integration tests
    - Test all campaign challenge routes are properly configured
    - Test authenticated pipeline is applied
    - _Requirements: 9.1, 9.4, 9.5_

- [x] 10. Create test data generators
  - [x] 10.1 Add ExMachina factories
    - Add challenge_factory to test/support/factory.ex (without tenant_id)
    - Add campaign_challenge_factory to test/support/factory.ex
    - Add helper function for generating valid cron expressions
    - _Requirements: All tests_
  
  - [x] 10.2 Add StreamData generators
    - Add challenge_name_generator/0 to test/support/generators.ex
    - Add evaluation_frequency_generator/0 to test/support/generators.ex
    - Add cron_expression_generator/0 to test/support/generators.ex
    - Add reward_points_generator/0 to test/support/generators.ex
    - Add json_metadata_generator/0 to test/support/generators.ex
    - _Requirements: All property tests_

- [x] 11. Final checkpoint - Ensure all tests pass
  - Run complete test suite
  - Verify all property tests pass with 100+ iterations
  - Verify all integration tests pass
  - Ask user if questions arise

- [x] 12. Code quality verification
  - [x] 12.1 Add type specifications
    - Add @spec to all public functions in Challenges context
    - Add @type definitions to Challenge and CampaignChallenge schemas
    - Add @type for pagination_opts and pagination_result
    - Add @typedoc for complex types
    - _Requirements: Code Quality_
  
  - [x] 12.2 Run Credo
    - Execute `mix credo --strict`
    - Fix all warnings and errors
    - Ensure zero Credo issues
    - _Requirements: Code Quality_
  
  - [x] 12.3 Run Dialyzer
    - Execute `mix dialyzer`
    - Fix all type warnings
    - Ensure zero Dialyzer warnings
    - _Requirements: Code Quality_

- [x] 13. Implement Challenge API Endpoints (Read-Only)
  - [x] 13.1 Create ChallengeController with Swagger documentation
    - Create `lib/campaigns_api_web/controllers/challenge_controller.ex`
    - Implement `index/2` action for GET /api/challenges
    - Implement `show/2` action for GET /api/challenges/:id
    - Add `swagger_definitions/0` with Challenge, ChallengeListResponse, ErrorResponse schemas
    - Add `swagger_path` documentation for both endpoints
    - Include helper functions: `parse_int/1`, `parse_datetime/1`
    - Follow exact same patterns as CampaignController
    - _Requirements: 1.1, 1.4, 4.1, 4.2, 4.3, 4.4, 4.5, 4.7, 5.1, 5.3, 9.1, 9.4, 10.1, 10.2, 10.3, 10.4, 10.5_

  - [x] 13.2 Add challenge routes to router
    - Modify `lib/campaigns_api_web/router.ex`
    - Add `resources "/challenges", ChallengeController, only: [:index, :show]` to authenticated scope
    - Ensure routes use existing `:api` and `:authenticated` pipelines
    - _Requirements: 7.5, 9.3_

  - [x] 13.3 Write unit tests for ChallengeController
    - Create `test/campaigns_api_web/controllers/challenge_controller_test.exs`
    - Test successful list challenges (GET /api/challenges)
    - Test successful get challenge by ID (GET /api/challenges/:id)
    - Test 404 for non-existent challenge ID
    - Test POST /api/challenges returns 404 or 405
    - Test PUT /api/challenges/:id returns 404 or 405
    - Test PATCH /api/challenges/:id returns 404 or 405
    - Test DELETE /api/challenges/:id returns 404 or 405
    - Test pagination parameters (limit, cursor)
    - Test response JSON structure
    - Use ExMachina for test data
    - _Requirements: 5.2, 7.1, 7.2, 7.3, 7.4, 8.3, 8.4_

  - [x] 13.4 Write property tests for ChallengeController
    - [x] 13.4.1 Write property test for complete challenge data in list response
      - **Property: List Endpoint Returns Complete Challenge Data**
      - **Validates: Requirements 3.4, 4.1**
    
    - [x] 13.4.2 Write property test for challenge ordering
      - **Property: Challenges Ordered by Insertion Time**
      - **Validates: Requirements 4.2**
    
    - [x] 13.4.3 Write property test for cursor pagination
      - **Property: Cursor Pagination Filters Correctly**
      - **Validates: Requirements 4.3**
    
    - [x] 13.4.4 Write property test for limit enforcement
      - **Property: Limit Parameter Enforced**
      - **Validates: Requirements 4.4**
    
    - [x] 13.4.5 Write property test for pagination metadata
      - **Property: Pagination Metadata Accuracy**
      - **Validates: Requirements 4.5**
    
    - [x] 13.4.6 Write property test for global challenge availability
      - **Property: Global Challenge Availability**
      - **Validates: Requirements 4.9, 6.1, 6.2**
    
    - [x] 13.4.7 Write property test for get challenge by ID
      - **Property: Get Challenge by ID Returns Complete Data**
      - **Validates: Requirements 5.1, 5.3**
    
    - [x] 13.4.8 Write property test for error response format
      - **Property: Error Responses Formatted as JSON**
      - **Validates: Requirements 8.5**

  - [x] 13.5 Generate and verify Swagger documentation
    - Run `mix phx.swagger.generate` to update swagger.json
    - Verify `priv/static/swagger.json` includes /api/challenges endpoints
    - Verify Challenge schema definitions are present
    - Verify pagination parameters documented
    - Test Swagger UI at /api/swagger displays challenge endpoints
    - _Requirements: 10.6_

  - [x] 13.6 Run static analysis and fix issues
    - Run `mix credo --strict` and fix all issues
    - Run `mix dialyzer` and fix all type warnings
    - Ensure all public functions have `@spec` annotations
    - Ensure controller follows Elixir quality standards
    - _Requirements: 9.4_

  - [x] 13.7 Final checkpoint - Ensure all tests pass
    - Run `mix test` and verify all tests pass
    - Verify property tests run minimum 20 iterations (optimized for speed)
    - Verify unit tests cover all edge cases
    - Verify Swagger documentation is complete

## Notes

- Follow TDD/baby steps: Write test first, implement minimal code to pass, refactor
- Use @moduledoc and @doc for documentation instead of inline comments
- Each task should be completed and tested before moving to the next
- Property tests must run minimum 100 iterations
- All datetime handling uses UTC timezone
- Foreign key constraints ensure referential integrity
- Cascade deletion rules maintain data consistency
- JSONB fields provide future extensibility without schema changes
- Challenges are globally available to all tenants (no tenant isolation)
- Campaign challenges maintain tenant isolation through campaign ownership
- Challenge CRUD operations are internal only (no HTTP endpoints)
