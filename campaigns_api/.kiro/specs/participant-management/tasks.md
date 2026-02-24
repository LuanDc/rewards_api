# Implementation Plan: Participant Management System

## Overview

This implementation plan breaks down the Participant Management System into incremental, testable steps. Each task builds on previous work, with property-based tests integrated throughout to catch errors early. The plan follows the existing codebase patterns from campaign and challenge management.

## Pre-Implementation: Test Suite Refactoring (Optional)

**Context**: The existing codebase has excessive property-based tests that slow down the test suite. Before implementing this feature, we can optionally refactor existing tests to follow the new pragmatic PBT strategy.

**Decision Point**: Choose one approach:

### Option A: Refactor First (Recommended for Long-Term)
- **Pros**: Establishes correct pattern, faster test suite for all future work
- **Cons**: Delays feature delivery by ~1-2 days
- **When**: Choose if test suite is painfully slow (>2 minutes) or if multiple features are planned

### Option B: Implement Feature First, Refactor Later
- **Pros**: Faster feature delivery, refactoring can be separate task
- **Cons**: New feature tests may follow old patterns, test suite remains slow
- **When**: Choose if feature is urgent or test suite is acceptable (<1 minute)

### Option C: Parallel Approach
- **Pros**: Feature and refactoring progress simultaneously
- **Cons**: Requires coordination, potential merge conflicts
- **When**: Choose if you have multiple developers or can context-switch

**If choosing Option A, complete Task 0 before Task 1. Otherwise, skip to Task 1.**

---

## Task 0: Refactor Existing Tests (Optional - See Decision Point Above)

**Estimated Time**: 1-2 days
**Expected Impact**: 60-70% reduction in test execution time (~2,500 iterations eliminated)

- [x] 0. Refactor existing tests to follow new PBT strategy
  - [x] 0.1 DELETE challenge_controller_property_test.exs
    - **DECISION: DELETE ENTIRE FILE** (100% waste)
    - All tests are trivial: HTTP structure, ordering (tested in context), pagination (tested in module)
    - Extract 3-4 unit tests to challenge_controller_test.exs: status codes, response format
    - **Time saved**: ~80 property iterations eliminated
    - _Files: DELETE test/campaigns_api_web/controllers/challenge_controller_property_test.exs_
  
  - [x] 0.2 BRUTAL refactor of campaign_management_property_test.exs
    - **KEEP ONLY 1 property**: tenant isolation (critical business invariant)
    - **DELETE 10 properties**: UUID generation, default status, optional fields, UTC timezone, ordering, list queries, field presence, updates, status transitions, deletion
    - Merge the 1 property into campaign_management_test.exs
    - Convert deleted properties to 5-6 simple unit tests
    - **Time saved**: ~900 property iterations eliminated (9 properties × 100 runs)
    - _Files: test/campaigns_api/campaign_management_test.exs_
  
  - [x] 0.3 Refactor pagination_property_test.exs
    - **KEEP ONLY 1 property**: cursor ordering consistency (no duplicates, no gaps)
    - **DELETE 3 properties**: structure validation, limit enforcement, next_cursor presence
    - Merge the 1 property into pagination_test.exs
    - Convert deleted properties to 3 unit tests
    - **Time saved**: ~300 property iterations eliminated
    - _Files: test/campaigns_api/pagination_test.exs_
  
  - [x] 0.4 DELETE challenges_property_test.exs
    - **DECISION: DELETE ENTIRE FILE** (100% waste)
    - All tests are simple CRUD operations with no business invariants
    - Convert to 4-5 unit tests in challenges_test.exs
    - **Time saved**: ~700 property iterations eliminated
    - _Files: DELETE test/campaigns_api/challenges_property_test.exs_
  
  - [x] 0.5 Consolidate tenants_property_test.exs
    - **KEEP 3 properties**: tenant creation, no duplicates, status validation (all critical)
    - Merge into tenants_test.exs with max_runs: 50
    - **Time saved**: ~150 iterations (reduced from 100 to 50 runs per property)
    - _Files: test/campaigns_api/tenants_test.exs_
  
  - [x] 0.6 Refactor campaign_challenge_property_test.exs
    - **KEEP 3 properties**: unique association, cascade deletion, tenant validation
    - **DELETE redundant cross-tenant tests** (5 properties testing same thing)
    - Merge into campaign_management/campaign_challenge_test.exs with max_runs: 50
    - **Time saved**: ~500 property iterations eliminated
    - _Files: test/campaigns_api/campaign_management/campaign_challenge_test.exs_
  
  - [x] 0.7 DELETE challenge schema property test
    - **DECISION: DELETE** challenges/challenge_property_test.exs
    - Name length validation is trivial unit test
    - Convert to 2 unit tests in challenge schema test
    - **Time saved**: ~100 property iterations eliminated
    - _Files: DELETE test/campaigns_api/challenges/challenge_property_test.exs_
  
  - [x] 0.8 Evaluate plug property test
    - Review require_auth_property_test.exs
    - If testing JWT parsing with different types: KEEP with max_runs: 30
    - If testing simple auth flow: DELETE and convert to unit tests
    - _Files: test/campaigns_api_web/plugs/require_auth_test.exs_
  
  - [x] 0.9 Delete all removed property test files
    - DELETE: challenge_controller_property_test.exs
    - DELETE: challenges_property_test.exs
    - DELETE: challenges/challenge_property_test.exs
    - DELETE: campaign_management_property_test.exs (after merge)
    - DELETE: pagination_property_test.exs (after merge)
    - **Total files deleted**: 5-6 files
  
  - [x] 0.10 Update test configuration
    - Add to test_helper.exs: `ExUnitProperties.configure(max_runs: 50, max_run_time: 5_000)`
    - Add @tag :property to all remaining property tests
    - Document: `mix test --exclude property` for fast feedback
    - Document: `mix test --only property` for full validation
    - _Files: test/test_helper.exs_
  
  - [x] 0.11 Measure and verify results
    - Run `mix test` and measure time BEFORE refactoring
    - Complete refactoring
    - Run `mix test` and measure time AFTER refactoring
    - **Expected savings**: 60-70% reduction in test time
    - **Expected elimination**: ~2,500+ property iterations
    - Verify all tests pass
    - Run `mix credo --strict`
    - _Success criteria: <50% of original test time, all tests passing_

---

## Main Implementation Tasks

**Start here if you chose Option B or C above, or after completing Task 0 if you chose Option A.**

- [x] 1. Create database migrations for participant tables
  - Create migration for `participants` table with all fields and indexes
  - Create migration for `campaign_participants` join table with unique constraint
  - Create migration for `participant_challenges` join table with unique constraint
  - Ensure foreign key constraints with cascade delete are properly configured
  - _Requirements: 1.1-1.6, 2.1-2.5, 2.1.1-2.1.6_

- [ ] 2. Implement Participant schema
  - [x] 2.1 Create Participant schema module with all fields and associations
    - Define schema with id, name, nickname, tenant_id, status fields
    - Add belongs_to association with Tenant
    - Add has_many associations with CampaignParticipant and ParticipantChallenge
    - Define @type t specification
    - Add Jason.Encoder derivation
    - _Requirements: 1.1-1.10_
  
  - [x] 2.2 Implement Participant changeset with validations
    - Add cast for all fields
    - Add validate_required for name, nickname, tenant_id
    - Add validate_length for name (min: 1) and nickname (min: 3)
    - Add unique_constraint for nickname
    - Add foreign_key_constraint for tenant_id
    - _Requirements: 1.2-1.4, 9.1-9.5_
  
  - [x] 2.3 Write tests for participant schema
    - Unit test: valid participant creation
    - Unit test: nickname uniqueness constraint
    - Unit test: field length validations
    - Unit test: status enum validation
    - Property test: rejects all invalid types for fields
    - _Requirements: 1.2-1.5, 3.1, 3.2, 9.1-9.5_
    - _Property: Property 2 (Type Validation at Schema Layer)_


- [ ] 3. Implement CampaignParticipant schema
  - [x] 3.1 Create CampaignParticipant schema module
    - Define schema with id, participant_id, campaign_id fields
    - Add belongs_to associations with Participant and Campaign
    - Define @type t specification
    - Add Jason.Encoder derivation
    - _Requirements: 2.1-2.8_
  
  - [x] 3.2 Implement CampaignParticipant changeset
    - Add cast for participant_id and campaign_id
    - Add validate_required for both foreign keys
    - Add unique_constraint for (participant_id, campaign_id)
    - Add foreign_key_constraints
    - _Requirements: 2.7_
  
  - [x] 3.3 Write unit tests for campaign-participant schema
    - Unit test: valid association creation
    - Unit test: uniqueness constraint violation
    - _Requirements: 2.7, 5.3_

- [ ] 4. Implement ParticipantChallenge schema
  - [x] 4.1 Create ParticipantChallenge schema module
    - Define schema with id, participant_id, challenge_id, campaign_id fields
    - Add belongs_to associations with Participant, Challenge, and Campaign
    - Define @type t specification
    - Add Jason.Encoder derivation
    - _Requirements: 2.1.1-2.1.11_
  
  - [x] 4.2 Implement ParticipantChallenge changeset
    - Add cast for all foreign keys
    - Add validate_required for all foreign keys
    - Add unique_constraint for (participant_id, challenge_id)
    - Add foreign_key_constraints
    - _Requirements: 2.1.10_
  
  - [x] 4.3 Write unit tests for participant-challenge schema
    - Unit test: valid association creation
    - Unit test: uniqueness constraint violation
    - _Requirements: 2.1.10, 5.1.5_

- [ ] 5. Implement ParticipantManagement context - CRUD operations
  - [x] 5.1 Create ParticipantManagement context module with type definitions
    - Define all type specifications (tenant_id, participant_id, attrs, pagination_opts, pagination_result)
    - Add module documentation
    - Import Ecto.Query and alias necessary modules
    - _Requirements: 10.1-10.3_
  
  - [x] 5.2 Implement create_participant/2 function
    - Accept tenant_id and attrs parameters
    - Merge tenant_id into attrs
    - Create participant using changeset
    - Return {:ok, participant} or {:error, changeset}
    - Add @spec annotation
    - _Requirements: 3.1, 3.2, 11.2_
  
  - [x] 5.3 Implement get_participant/2 function
    - Accept tenant_id and participant_id parameters
    - Query participant by id and tenant_id
    - Return participant or nil
    - Add @spec annotation
    - _Requirements: 3.3, 3.4_
  
  - [x] 5.4 Implement update_participant/3 function
    - Accept tenant_id, participant_id, and attrs parameters
    - Get participant with tenant validation
    - Return {:error, :not_found} if not found
    - Update using changeset
    - Return {:ok, participant} or {:error, changeset}
    - Add @spec annotation
    - _Requirements: 3.5, 3.6, 11.3_
  
  - [x] 5.5 Implement delete_participant/2 function
    - Accept tenant_id and participant_id parameters
    - Get participant with tenant validation
    - Return {:error, :not_found} if not found
    - Delete participant (cascade will handle associations)
    - Return {:ok, participant}
    - Add @spec annotation
    - _Requirements: 3.7, 3.8, 11.4_
  
  - [x] 5.6 Write tests for CRUD operations
    - Unit test: create with valid attributes
    - Unit test: create with invalid attributes
    - Unit test: get existing participant
    - Unit test: get non-existent participant
    - Unit test: update with valid attributes
    - Unit test: update with invalid attributes
    - Unit test: delete participant
    - Unit test: CRUD round trip (create → read → update → read → delete)
    - Property test: tenant isolation (cross-tenant access always fails)
    - Property test: cascade deletion (all associations removed)
    - _Requirements: 3.1-3.8, 11.2-11.4_
    - _Properties: Property 1 (Tenant Isolation), Property 5 (Cascade Deletion)_

- [x] 6. Checkpoint - Ensure all tests pass
  - Run mix test to verify all participant CRUD tests pass
  - Run mix credo --strict to check code quality
  - Ask the user if questions arise


- [ ] 7. Implement ParticipantManagement context - Pagination
  - [x] 7.1 Implement list_participants/2 function
    - Accept tenant_id and pagination_opts parameters
    - Build query filtering by tenant_id
    - Apply optional nickname filter (case-insensitive ILIKE)
    - Use Pagination.paginate/3 with query
    - Return pagination_result
    - Add @spec annotation
    - _Requirements: 4.1-4.9, 11.1_
  
  - [x] 7.2 Write tests for participant listing
    - Unit test: list without cursor
    - Unit test: list with cursor
    - Unit test: limit enforcement (100 max)
    - Unit test: nickname filtering
    - Unit test: pagination response structure
    - Unit test: empty results
    - Property test: pagination consistency (no duplicates, no gaps, correct ordering)
    - _Requirements: 4.1-4.9, 11.1_
    - _Property: Property 6 (Pagination Consistency)_

- [ ] 8. Implement ParticipantManagement context - Campaign associations
  - [x] 8.1 Implement associate_participant_with_campaign/3 function
    - Accept tenant_id, participant_id, campaign_id parameters
    - Validate participant belongs to tenant
    - Validate campaign belongs to tenant
    - Return {:error, :tenant_mismatch} if different tenants
    - Create CampaignParticipant association
    - Return {:ok, campaign_participant} or {:error, changeset}
    - Add @spec annotation
    - _Requirements: 2.6, 5.1, 5.2, 9.6, 11.5_
  
  - [x] 8.2 Implement disassociate_participant_from_campaign/3 function
    - Accept tenant_id, participant_id, campaign_id parameters
    - Query CampaignParticipant with tenant validation via joins
    - Return {:error, :not_found} if not found
    - Delete all ParticipantChallenge associations for this campaign
    - Delete CampaignParticipant association
    - Use transaction to ensure atomicity
    - Return {:ok, campaign_participant}
    - Add @spec annotation
    - _Requirements: 5.4, 5.5_
  
  - [x] 8.3 Implement list_campaigns_for_participant/3 function
    - Accept tenant_id, participant_id, and pagination_opts parameters
    - Build query joining CampaignParticipant with Campaign
    - Filter by participant_id and tenant_id
    - Order by CampaignParticipant.inserted_at descending
    - Use Pagination.paginate/3
    - Return pagination_result with campaigns
    - Add @spec annotation
    - _Requirements: 7.1-7.5, 11.7_
  
  - [x] 8.4 Implement list_participants_for_campaign/3 function
    - Accept tenant_id, campaign_id, and pagination_opts parameters
    - Build query joining CampaignParticipant with Participant
    - Filter by campaign_id and validate campaign belongs to tenant
    - Order by CampaignParticipant.inserted_at descending
    - Use Pagination.paginate/3
    - Return pagination_result with participants
    - Add @spec annotation
    - _Requirements: 6.1-6.5, 11.6_
  
  - [x] 8.5 Write tests for campaign associations
    - Unit test: associate same-tenant resources
    - Unit test: associate cross-tenant resources (should fail)
    - Unit test: duplicate association (should fail)
    - Unit test: disassociate existing association
    - Unit test: disassociate non-existent association
    - Unit test: list campaigns for participant
    - Unit test: list participants for campaign
    - Unit test: cross-tenant list returns empty
    - Property test: tenant validation (only same-tenant associations succeed)
    - _Requirements: 2.6, 5.1-5.5, 6.1-6.5, 7.1-7.5, 9.6, 11.5-11.7_
    - _Property: Property 3 (Campaign-Participant Tenant Validation)_

- [x] 9. Checkpoint - Ensure all tests pass
  - Run mix test to verify all campaign association tests pass
  - Run mix credo --strict to check code quality
  - Ask the user if questions arise


- [ ] 10. Implement ParticipantManagement context - Challenge associations
  - [x] 10.1 Implement associate_participant_with_challenge/3 function
    - Accept tenant_id, participant_id, challenge_id parameters
    - Validate participant belongs to tenant
    - Query challenge with campaign via CampaignChallenge join
    - Validate challenge's campaign belongs to tenant
    - Check if participant is associated with the campaign
    - Return {:error, :participant_not_in_campaign} if not associated
    - Return {:error, :tenant_mismatch} if different tenants
    - Create ParticipantChallenge association with campaign_id
    - Return {:ok, participant_challenge} or {:error, changeset}
    - Add @spec annotation
    - _Requirements: 2.1.7-2.1.9, 5.1.1-5.1.4_
  
  - [x] 10.2 Implement disassociate_participant_from_challenge/3 function
    - Accept tenant_id, participant_id, challenge_id parameters
    - Query ParticipantChallenge with tenant validation via joins
    - Return {:error, :not_found} if not found
    - Delete ParticipantChallenge association
    - Return {:ok, participant_challenge}
    - Add @spec annotation
    - _Requirements: 5.1.6, 5.1.7_
  
  - [x] 10.3 Implement list_challenges_for_participant/3 function
    - Accept tenant_id, participant_id, and pagination_opts parameters
    - Build query joining ParticipantChallenge with Challenge
    - Filter by participant_id and tenant_id
    - Apply optional campaign_id filter if provided in opts
    - Order by ParticipantChallenge.inserted_at descending
    - Use Pagination.paginate/3
    - Return pagination_result with challenges
    - Add @spec annotation
    - _Requirements: 7.1.1-7.1.6, 11.4_
  
  - [x] 10.4 Implement list_participants_for_challenge/3 function
    - Accept tenant_id, challenge_id, and pagination_opts parameters
    - Build query joining ParticipantChallenge with Participant
    - Filter by challenge_id and validate challenge belongs to tenant
    - Order by ParticipantChallenge.inserted_at descending
    - Use Pagination.paginate/3
    - Return pagination_result with participants
    - Add @spec annotation
    - _Requirements: 7.2.1-7.2.5, 11.4_
  
  - [x] 10.5 Write tests for challenge associations
    - Unit test: associate participant with challenge (valid campaign membership)
    - Unit test: associate without campaign membership (should fail)
    - Unit test: associate cross-tenant resources (should fail)
    - Unit test: duplicate association (should fail)
    - Unit test: disassociate existing association
    - Unit test: disassociate non-existent association
    - Unit test: list challenges for participant
    - Unit test: list challenges with campaign filter
    - Unit test: list participants for challenge
    - Unit test: cross-tenant list returns empty
    - Property test: campaign membership validation (only members can be assigned)
    - _Requirements: 2.1.7-2.1.9, 5.1.1-5.1.7, 7.1.1-7.1.6, 7.2.1-7.2.5_
    - _Property: Property 4 (Participant-Challenge Campaign Membership)_

- [x] 11. Checkpoint - Ensure all tests pass
  - Run mix test to verify all challenge association tests pass
  - Run mix credo --strict to check code quality
  - Ask the user if questions arise

- [x] 12. Create ExMachina factories for test data
  - [x] 12.1 Add participant_factory to test/support/factory.ex
    - Generate unique name and nickname using System.unique_integer
    - Set default status to :active
    - Generate random tenant_id
    - _Requirements: 10.6_
  
  - [x] 12.2 Add campaign_participant_factory to test/support/factory.ex
    - Build participant and campaign associations
    - Generate unique id
    - _Requirements: 10.6_
  
  - [x] 12.3 Add participant_challenge_factory to test/support/factory.ex
    - Build participant, challenge, and campaign associations
    - Generate unique id
    - _Requirements: 10.6_


- [x] 13. Implement ParticipantController with Swagger documentation
  - [x] 13.1 Create ParticipantController module with basic setup
    - Add `use CampaignsApiWeb, :controller`
    - Add `use PhoenixSwagger` immediately after
    - Import necessary modules
    - Add @moduledoc documentation
    - _Requirements: 8.14, 10.8_
  
  - [x] 13.2 Define swagger_definitions/0 function
    - Define Participant schema with all fields and example
    - Define ParticipantRequest schema for create/update
    - Define ParticipantListResponse schema with pagination fields
    - Define CampaignParticipant schema
    - Define ParticipantChallenge schema
    - Define ErrorResponse schema
    - Define ValidationErrorResponse schema
    - _Requirements: 8.15_
  
  - [x] 13.3 Implement create action with swagger_path documentation
    - Extract tenant_id from conn.assigns
    - Call ParticipantManagement.create_participant/2
    - Return 201 with participant on success
    - Return 422 with errors on validation failure
    - Add swagger_path with POST /api/participants
    - Document request body, responses, and security
    - Add @spec annotation
    - _Requirements: 8.1, 8.16, 9.9_
  
  - [x] 13.4 Implement index action with swagger_path documentation
    - Extract tenant_id from conn.assigns
    - Extract pagination params (limit, cursor, nickname)
    - Call ParticipantManagement.list_participants/2
    - Return 200 with paginated response
    - Add swagger_path with GET /api/participants
    - Document query parameters and responses
    - Add @spec annotation
    - _Requirements: 8.2, 8.16, 9.8_
  
  - [x] 13.5 Implement show action with swagger_path documentation
    - Extract tenant_id from conn.assigns
    - Extract participant_id from params
    - Call ParticipantManagement.get_participant/2
    - Return 200 with participant or 404 if not found
    - Add swagger_path with GET /api/participants/:id
    - Document path parameters and responses
    - Add @spec annotation
    - _Requirements: 8.3, 8.16, 9.8, 9.11_
  
  - [x] 13.6 Implement update action with swagger_path documentation
    - Extract tenant_id from conn.assigns
    - Extract participant_id from params
    - Call ParticipantManagement.update_participant/3
    - Return 200 with updated participant on success
    - Return 404 if not found, 422 on validation error
    - Add swagger_path with PUT /api/participants/:id
    - Document request body, path parameters, and responses
    - Add @spec annotation
    - _Requirements: 8.4, 8.16, 9.10, 9.11, 9.12_
  
  - [x] 13.7 Implement delete action with swagger_path documentation
    - Extract tenant_id from conn.assigns
    - Extract participant_id from params
    - Call ParticipantManagement.delete_participant/2
    - Return 200 with deleted participant on success
    - Return 404 if not found
    - Add swagger_path with DELETE /api/participants/:id
    - Document path parameters and responses
    - Add @spec annotation
    - _Requirements: 8.5, 8.16, 9.10, 9.11_


  - [x] 13.8 Implement associate_campaign action with swagger_path documentation
    - Extract tenant_id from conn.assigns
    - Extract participant_id and campaign_id from params
    - Call ParticipantManagement.associate_participant_with_campaign/3
    - Return 201 with association on success
    - Return 403 on tenant_mismatch, 422 on validation error
    - Add swagger_path with POST /api/participants/:participant_id/campaigns/:campaign_id
    - Document path parameters and responses
    - Add @spec annotation
    - _Requirements: 8.6, 8.16, 9.9, 9.12, 9.13_
  
  - [x] 13.9 Implement disassociate_campaign action with swagger_path documentation
    - Extract tenant_id from conn.assigns
    - Extract participant_id and campaign_id from params
    - Call ParticipantManagement.disassociate_participant_from_campaign/3
    - Return 200 with deleted association on success
    - Return 404 if not found
    - Add swagger_path with DELETE /api/participants/:participant_id/campaigns/:campaign_id
    - Document path parameters and responses
    - Add @spec annotation
    - _Requirements: 8.7, 8.16, 9.10, 9.11_
  
  - [x] 13.10 Implement list_campaigns action with swagger_path documentation
    - Extract tenant_id from conn.assigns
    - Extract participant_id from params
    - Extract pagination params (limit, cursor)
    - Call ParticipantManagement.list_campaigns_for_participant/3
    - Return 200 with paginated campaigns
    - Add swagger_path with GET /api/participants/:participant_id/campaigns
    - Document path and query parameters and responses
    - Add @spec annotation
    - _Requirements: 8.8, 8.16, 9.8_
  
  - [x] 13.11 Implement list_participants action with swagger_path documentation
    - Extract tenant_id from conn.assigns
    - Extract campaign_id from params
    - Extract pagination params (limit, cursor)
    - Call ParticipantManagement.list_participants_for_campaign/3
    - Return 200 with paginated participants
    - Add swagger_path with GET /api/campaigns/:campaign_id/participants
    - Document path and query parameters and responses
    - Add @spec annotation
    - _Requirements: 8.9, 8.16, 9.8_
  
  - [x] 13.12 Implement associate_challenge action with swagger_path documentation
    - Extract tenant_id from conn.assigns
    - Extract participant_id and challenge_id from params
    - Call ParticipantManagement.associate_participant_with_challenge/3
    - Return 201 with association on success
    - Return 403 on tenant_mismatch, 422 on validation or participant_not_in_campaign error
    - Add swagger_path with POST /api/participants/:participant_id/challenges/:challenge_id
    - Document path parameters and responses
    - Add @spec annotation
    - _Requirements: 8.10, 8.16, 9.9, 9.12, 9.13_
  
  - [x] 13.13 Implement disassociate_challenge action with swagger_path documentation
    - Extract tenant_id from conn.assigns
    - Extract participant_id and challenge_id from params
    - Call ParticipantManagement.disassociate_participant_from_challenge/3
    - Return 200 with deleted association on success
    - Return 404 if not found
    - Add swagger_path with DELETE /api/participants/:participant_id/challenges/:challenge_id
    - Document path parameters and responses
    - Add @spec annotation
    - _Requirements: 8.11, 8.16, 9.10, 9.11_
  
  - [x] 13.14 Implement list_challenges action with swagger_path documentation
    - Extract tenant_id from conn.assigns
    - Extract participant_id from params
    - Extract pagination params (limit, cursor, campaign_id)
    - Call ParticipantManagement.list_challenges_for_participant/3
    - Return 200 with paginated challenges
    - Add swagger_path with GET /api/participants/:participant_id/challenges
    - Document path and query parameters (including optional campaign_id filter) and responses
    - Add @spec annotation
    - _Requirements: 8.12, 8.16, 9.8_
  
  - [x] 13.15 Implement list_challenge_participants action with swagger_path documentation
    - Extract tenant_id from conn.assigns
    - Extract challenge_id from params
    - Extract pagination params (limit, cursor)
    - Call ParticipantManagement.list_participants_for_challenge/3
    - Return 200 with paginated participants
    - Add swagger_path with GET /api/challenges/:challenge_id/participants
    - Document path and query parameters and responses
    - Add @spec annotation
    - _Requirements: 8.13, 8.16, 9.8_


- [x] 14. Add routes to router
  - Add POST /api/participants route to create action
  - Add GET /api/participants route to index action
  - Add GET /api/participants/:id route to show action
  - Add PUT /api/participants/:id route to update action
  - Add DELETE /api/participants/:id route to delete action
  - Add POST /api/participants/:participant_id/campaigns/:campaign_id route to associate_campaign action
  - Add DELETE /api/participants/:participant_id/campaigns/:campaign_id route to disassociate_campaign action
  - Add GET /api/participants/:participant_id/campaigns route to list_campaigns action
  - Add GET /api/campaigns/:campaign_id/participants route to list_participants action
  - Add POST /api/participants/:participant_id/challenges/:challenge_id route to associate_challenge action
  - Add DELETE /api/participants/:participant_id/challenges/:challenge_id route to disassociate_challenge action
  - Add GET /api/participants/:participant_id/challenges route to list_challenges action
  - Add GET /api/challenges/:challenge_id/participants route to list_challenge_participants action
  - _Requirements: 8.1-8.13_

- [x] 15. Write controller unit tests
  - [x] 15.1 Write unit tests for all controller actions
    - Test all CRUD endpoints (create, index, show, update, delete)
    - Test all campaign association endpoints (associate, disassociate, list)
    - Test all challenge association endpoints (associate, disassociate, list)
    - Test HTTP status codes (200, 201, 404, 422, 403)
    - Test JSON response formats
    - Test parameter extraction from conn.assigns
    - Use ExMachina to generate test data
    - Note: No property tests at controller layer - context layer already validates business logic
    - _Requirements: 8.1-8.13, 9.8-9.13, 10.6_

- [x] 16. Checkpoint - Ensure all tests pass
  - Run mix test to verify all controller tests pass
  - Run mix credo --strict to check code quality
  - Ask the user if questions arise


- [x] 17. Generate Swagger documentation
  - Run mix phx.swagger.generate to create/update priv/static/swagger.json
  - Verify all participant endpoints appear in the generated file
  - Verify all schema definitions are present
  - Verify no syntax errors in the generated JSON
  - _Requirements: 8.14-8.16_

- [x] 18. Final quality checks
  - [x] 18.1 Run mix credo --strict
    - Fix any warnings or errors
    - Ensure zero issues reported
    - _Requirements: 10.4_
  
  - [x] 18.2 Run mix dialyzer
    - Fix any type warnings
    - Ensure all @spec annotations match implementations
    - Ensure zero warnings reported
    - _Requirements: 10.5_
  
  - [x] 18.3 Verify all documentation is complete
    - Check all modules have @moduledoc
    - Check all public functions have @doc
    - Check all public functions have @spec
    - Check all schemas have @type t
    - _Requirements: 10.1, 10.2, 10.8, 10.9_
  
  - [x] 18.4 Run full test suite
    - Run mix test to ensure all tests pass
    - Verify property tests run with 100+ iterations
    - Verify test coverage is comprehensive
    - _Requirements: 10.6_

- [x] 19. Final checkpoint - Complete implementation
  - Ensure all tests pass
  - Ensure mix credo --strict returns zero issues
  - Ensure mix dialyzer returns zero warnings
  - Ensure swagger.json is generated and valid
  - Ask the user if questions arise or if implementation is complete

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation throughout implementation
- Property tests (6 total) focus on business invariants at context layer
- Unit tests validate specific examples, edge cases, and integration points
- All tests co-located in same files (no separate property test files)
- All code must follow English naming conventions per workspace standards
- All code must include comprehensive type specifications per Elixir quality standards
- All test data must be created using ExMachina factories
- Swagger documentation must be generated after all controller changes
- Property tests configured with max_runs: 50 for faster feedback

## When to Create Separate Refactoring Specs

Consider creating a separate spec for test refactoring when:

1. **Large Scope**: Refactoring affects >10 test files or >1000 lines of test code
2. **Cross-Feature**: Refactoring benefits multiple features, not just one
3. **Independent Value**: Refactoring provides value even without new feature
4. **Team Coordination**: Multiple developers need to work on refactoring and feature simultaneously
5. **Risk Management**: Want to deploy refactoring separately to validate no regressions

**Example**: If test suite refactoring is a major initiative affecting the entire codebase, create:
- Spec: `test-suite-optimization` with its own requirements, design, and tasks
- Keep feature specs focused on feature implementation only

**Current Case**: Task 0 is included here because:
- Refactoring is small-to-medium scope (~6 files)
- Directly benefits this feature's test patterns
- Can be done by same developer in 1-2 days
- Makes sense as optional pre-work for this feature
