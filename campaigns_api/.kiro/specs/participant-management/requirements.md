# Requirements Document

## Introduction

The Participant Management System enables tenants to manage participants and associate them with campaigns in a multi-tenant environment. Participants represent individuals who can participate in reward campaigns, with full tenant isolation ensuring data security and privacy. The system provides CRUD operations, pagination, and flexible campaign associations while maintaining consistency with existing campaign and challenge management patterns.

## Glossary

- **Participant**: An individual who can participate in one or more campaigns and challenges within a tenant, identified by a unique nickname
- **Tenant**: A client organization in the multi-tenant system that owns participants, campaigns, and challenges
- **Campaign**: A reward campaign that can have multiple participants and challenges
- **Challenge**: A specific task or activity within a campaign that participants can be assigned to
- **Campaign_Participant**: The association entity linking participants to campaigns
- **Participant_Challenge**: The association entity linking participants to specific challenges within campaigns
- **Participant_Status**: The current state of a participant (active, inactive, or ineligible)
- **Tenant_Isolation**: Security mechanism ensuring participants can only access data within their tenant
- **Cursor_Based_Pagination**: Pagination mechanism using timestamps as cursors for efficient data retrieval
- **API**: Application Programming Interface exposing participant management functionality

## Requirements

### Requirement 1: Participant Schema and Data Model

**User Story:** As a system architect, I want a well-defined participant schema with tenant isolation, so that participant data is properly structured and secured.

#### Acceptance Criteria

1. THE Participant_Schema SHALL include an id field of type UUID as the primary key
2. THE Participant_Schema SHALL include a name field of type string that is required and represents the full name
3. THE Participant_Schema SHALL include a nickname field of type string that is required and must be unique across all participants
4. THE Participant_Schema SHALL include a tenant_id field that is required for tenant isolation
5. THE Participant_Schema SHALL include a status field of type enum with values (active, inactive, ineligible) and default value active
6. THE Participant_Schema SHALL include inserted_at and updated_at timestamp fields
7. THE Participant_Schema SHALL define a belongs_to association with the Tenant entity
8. THE Participant_Schema SHALL define a @type t specification for type safety
9. THE Participant_Schema SHALL derive Jason.Encoder for JSON serialization
10. THE Participant_Schema SHALL enforce a unique constraint on the nickname field

### Requirement 2: Campaign-Participant Association

**User Story:** As a campaign manager, I want to associate participants with campaigns, so that I can track who is participating in each campaign.

#### Acceptance Criteria

1. THE Campaign_Participant_Schema SHALL create a many-to-many relationship between participants and campaigns
2. THE Campaign_Participant_Schema SHALL include an id field of type UUID as the primary key
3. THE Campaign_Participant_Schema SHALL include a participant_id field referencing the participants table
4. THE Campaign_Participant_Schema SHALL include a campaign_id field referencing the campaigns table
5. THE Campaign_Participant_Schema SHALL include inserted_at and updated_at timestamp fields
6. WHEN creating a campaign-participant association, THE System SHALL validate that both participant and campaign belong to the same tenant
7. THE Campaign_Participant_Schema SHALL enforce a unique constraint on the combination of participant_id and campaign_id
8. THE Campaign_Participant_Schema SHALL define belongs_to associations with both Participant and Campaign entities

### Requirement 2.1: Participant-Challenge Association

**User Story:** As a campaign manager, I want to associate participants with specific challenges within campaigns, so that I can control which challenges each participant can participate in.

#### Acceptance Criteria

1. THE Participant_Challenge_Schema SHALL create a many-to-many relationship between participants and challenges
2. THE Participant_Challenge_Schema SHALL include an id field of type UUID as the primary key
3. THE Participant_Challenge_Schema SHALL include a participant_id field referencing the participants table
4. THE Participant_Challenge_Schema SHALL include a challenge_id field referencing the challenges table
5. THE Participant_Challenge_Schema SHALL include a campaign_id field referencing the campaigns table to maintain campaign context
6. THE Participant_Challenge_Schema SHALL include inserted_at and updated_at timestamp fields
7. WHEN creating a participant-challenge association, THE System SHALL validate that the participant is associated with the campaign
8. WHEN creating a participant-challenge association, THE System SHALL validate that the challenge belongs to the campaign
9. WHEN creating a participant-challenge association, THE System SHALL validate that participant, challenge, and campaign all belong to the same tenant
10. THE Participant_Challenge_Schema SHALL enforce a unique constraint on the combination of participant_id and challenge_id
11. THE Participant_Challenge_Schema SHALL define belongs_to associations with Participant, Challenge, and Campaign entities

### Requirement 3: Participant CRUD Operations

**User Story:** As a tenant administrator, I want to create, read, update, and delete participants, so that I can manage my participant database.

#### Acceptance Criteria

1. WHEN creating a participant with valid attributes, THE System SHALL create a new participant record and return {:ok, participant}
2. WHEN creating a participant with invalid attributes, THE System SHALL return {:error, changeset} with validation errors
3. WHEN retrieving a participant by id within the tenant, THE System SHALL return the participant record
4. WHEN retrieving a participant by id from a different tenant, THE System SHALL return {:error, :not_found}
5. WHEN updating a participant with valid attributes, THE System SHALL update the record and return {:ok, participant}
6. WHEN updating a participant with invalid attributes, THE System SHALL return {:error, changeset} with validation errors
7. WHEN deleting a participant, THE System SHALL remove the participant record and return {:ok, participant}
8. WHEN deleting a participant that has campaign associations, THE System SHALL remove all associations and then delete the participant

### Requirement 4: Participant Listing with Pagination

**User Story:** As a tenant administrator, I want to list participants with pagination, so that I can efficiently browse large participant lists.

#### Acceptance Criteria

1. WHEN listing participants without a cursor, THE System SHALL return the first page of participants ordered by inserted_at descending
2. WHEN listing participants with a cursor, THE System SHALL return participants inserted before the cursor timestamp
3. WHEN listing participants with a limit parameter, THE System SHALL return at most that number of participants
4. WHEN the limit parameter exceeds 100, THE System SHALL cap the limit at 100
5. WHEN listing participants with a nickname filter parameter, THE System SHALL return only participants whose nickname contains the filter string (case-insensitive)
6. THE System SHALL return a response containing data (list of participants), next_cursor (timestamp for next page), and has_more (boolean)
7. WHEN there are more participants available, THE System SHALL set has_more to true and provide a next_cursor
8. WHEN there are no more participants available, THE System SHALL set has_more to false and next_cursor to nil
9. THE System SHALL only return participants belonging to the requesting tenant

### Requirement 5: Campaign-Participant Association Management

**User Story:** As a campaign manager, I want to associate and disassociate participants with campaigns, so that I can control campaign participation.

#### Acceptance Criteria

1. WHEN associating a participant with a campaign in the same tenant, THE System SHALL create the association and return {:ok, campaign_participant}
2. WHEN associating a participant with a campaign in a different tenant, THE System SHALL return {:error, :tenant_mismatch}
3. WHEN associating a participant that is already associated with the campaign, THE System SHALL return {:error, changeset} with a unique constraint violation
4. WHEN disassociating a participant from a campaign, THE System SHALL remove the association and all related participant-challenge associations, then return {:ok, campaign_participant}
5. WHEN disassociating a participant that is not associated with the campaign, THE System SHALL return {:error, :not_found}

### Requirement 5.1: Participant-Challenge Association Management

**User Story:** As a campaign manager, I want to associate and disassociate participants with specific challenges, so that I can control which challenges each participant can participate in.

#### Acceptance Criteria

1. WHEN associating a participant with a challenge, THE System SHALL verify the participant is associated with the challenge's campaign
2. WHEN associating a participant with a challenge where the participant is not in the campaign, THE System SHALL return {:error, :participant_not_in_campaign}
3. WHEN associating a participant with a challenge in the same tenant, THE System SHALL create the association and return {:ok, participant_challenge}
4. WHEN associating a participant with a challenge in a different tenant, THE System SHALL return {:error, :tenant_mismatch}
5. WHEN associating a participant that is already associated with the challenge, THE System SHALL return {:error, changeset} with a unique constraint violation
6. WHEN disassociating a participant from a challenge, THE System SHALL remove the association and return {:ok, participant_challenge}
7. WHEN disassociating a participant that is not associated with the challenge, THE System SHALL return {:error, :not_found}

### Requirement 6: List Participants for a Campaign

**User Story:** As a campaign manager, I want to list all participants in a campaign, so that I can see who is participating.

#### Acceptance Criteria

1. WHEN listing participants for a campaign without a cursor, THE System SHALL return the first page of participants ordered by association creation time descending
2. WHEN listing participants for a campaign with a cursor, THE System SHALL return participants associated before the cursor timestamp
3. THE System SHALL return a paginated response with data, next_cursor, and has_more fields
4. THE System SHALL only return participants for campaigns belonging to the requesting tenant
5. WHEN the campaign does not exist or belongs to a different tenant, THE System SHALL return an empty list

### Requirement 7: List Campaigns for a Participant

**User Story:** As a tenant administrator, I want to list all campaigns a participant is enrolled in, so that I can track their participation.

#### Acceptance Criteria

1. WHEN listing campaigns for a participant without a cursor, THE System SHALL return the first page of campaigns ordered by association creation time descending
2. WHEN listing campaigns for a participant with a cursor, THE System SHALL return campaigns associated before the cursor timestamp
3. THE System SHALL return a paginated response with data, next_cursor, and has_more fields
4. THE System SHALL only return campaigns for participants belonging to the requesting tenant
5. WHEN the participant does not exist or belongs to a different tenant, THE System SHALL return an empty list

### Requirement 7.1: List Challenges for a Participant

**User Story:** As a campaign manager, I want to list all challenges a participant is enrolled in, so that I can track which specific challenges they can participate in.

#### Acceptance Criteria

1. WHEN listing challenges for a participant without a cursor, THE System SHALL return the first page of challenges ordered by association creation time descending
2. WHEN listing challenges for a participant with a cursor, THE System SHALL return challenges associated before the cursor timestamp
3. THE System SHALL return a paginated response with data, next_cursor, and has_more fields
4. THE System SHALL only return challenges for participants belonging to the requesting tenant
5. WHEN the participant does not exist or belongs to a different tenant, THE System SHALL return an empty list
6. THE System SHALL optionally filter challenges by campaign_id when provided

### Requirement 7.2: List Participants for a Challenge

**User Story:** As a campaign manager, I want to list all participants enrolled in a specific challenge, so that I can see who can participate in that challenge.

#### Acceptance Criteria

1. WHEN listing participants for a challenge without a cursor, THE System SHALL return the first page of participants ordered by association creation time descending
2. WHEN listing participants for a challenge with a cursor, THE System SHALL return participants associated before the cursor timestamp
3. THE System SHALL return a paginated response with data, next_cursor, and has_more fields
4. THE System SHALL only return participants for challenges belonging to the requesting tenant
5. WHEN the challenge does not exist or belongs to a different tenant, THE System SHALL return an empty list

### Requirement 8: API Endpoints with Swagger Documentation

**User Story:** As an API consumer, I want well-documented API endpoints, so that I can integrate with the participant management system.

#### Acceptance Criteria

1. THE System SHALL provide a POST /api/participants endpoint for creating participants
2. THE System SHALL provide a GET /api/participants endpoint for listing participants with pagination
3. THE System SHALL provide a GET /api/participants/:id endpoint for retrieving a specific participant
4. THE System SHALL provide a PUT /api/participants/:id endpoint for updating a participant
5. THE System SHALL provide a DELETE /api/participants/:id endpoint for deleting a participant
6. THE System SHALL provide a POST /api/participants/:participant_id/campaigns/:campaign_id endpoint for associating a participant with a campaign
7. THE System SHALL provide a DELETE /api/participants/:participant_id/campaigns/:campaign_id endpoint for disassociating a participant from a campaign
8. THE System SHALL provide a GET /api/participants/:participant_id/campaigns endpoint for listing campaigns for a participant
9. THE System SHALL provide a GET /api/campaigns/:campaign_id/participants endpoint for listing participants for a campaign
10. THE System SHALL provide a POST /api/participants/:participant_id/challenges/:challenge_id endpoint for associating a participant with a challenge
11. THE System SHALL provide a DELETE /api/participants/:participant_id/challenges/:challenge_id endpoint for disassociating a participant from a challenge
12. THE System SHALL provide a GET /api/participants/:participant_id/challenges endpoint for listing challenges for a participant (with optional campaign_id filter)
13. THE System SHALL provide a GET /api/challenges/:challenge_id/participants endpoint for listing participants for a challenge
14. THE System SHALL include PhoenixSwagger configuration in the controller with use PhoenixSwagger
15. THE System SHALL define swagger_definitions/0 function with all schema definitions
16. THE System SHALL document each endpoint with swagger_path functions including parameters, responses, and security requirements

### Requirement 9: Validation and Error Handling

**User Story:** As a system developer, I want comprehensive validation and error handling, so that the system provides clear feedback and maintains data integrity.

#### Acceptance Criteria

1. WHEN a participant name is less than 1 character, THE System SHALL return a validation error
2. WHEN a participant nickname is less than 3 characters, THE System SHALL return a validation error
3. WHEN a participant nickname already exists in the system, THE System SHALL return a unique constraint violation error
4. WHEN a required field is missing, THE System SHALL return a validation error indicating which field is required
5. WHEN a tenant_id does not exist, THE System SHALL return a foreign key constraint error
6. WHEN attempting to associate a participant with a campaign from different tenants, THE System SHALL return a tenant mismatch error
7. WHEN a database operation fails, THE System SHALL return an appropriate error tuple
8. THE System SHALL return HTTP 200 for successful GET requests
9. THE System SHALL return HTTP 201 for successful POST requests
10. THE System SHALL return HTTP 200 for successful PUT and DELETE requests
11. THE System SHALL return HTTP 404 for not found resources
12. THE System SHALL return HTTP 422 for validation errors
13. THE System SHALL return HTTP 401 for unauthorized requests
14. THE System SHALL return HTTP 403 for forbidden requests

### Requirement 10: Type Safety and Code Quality

**User Story:** As a system developer, I want type-safe code with high quality standards, so that the system is maintainable and reliable.

#### Acceptance Criteria

1. THE System SHALL include @spec annotations for all public functions
2. THE System SHALL define @type t for all schema modules
3. THE System SHALL define @type specifications for all keyword list options
4. THE System SHALL pass mix credo --strict with zero issues
5. THE System SHALL pass mix dialyzer with zero warnings
6. THE System SHALL use ExMachina factories for all test data creation
7. THE System SHALL follow English naming conventions for all code elements
8. THE System SHALL include @moduledoc documentation for all modules
9. THE System SHALL include @doc documentation for all public functions

### Requirement 11: Tenant Isolation

**User Story:** As a security architect, I want strict tenant isolation, so that tenants cannot access each other's data.

#### Acceptance Criteria

1. WHEN querying participants, THE System SHALL filter results by the requesting tenant_id
2. WHEN creating a participant, THE System SHALL associate it with the requesting tenant_id
3. WHEN updating a participant, THE System SHALL verify it belongs to the requesting tenant
4. WHEN deleting a participant, THE System SHALL verify it belongs to the requesting tenant
5. WHEN associating a participant with a campaign, THE System SHALL verify both belong to the same tenant
6. WHEN listing participants for a campaign, THE System SHALL verify the campaign belongs to the requesting tenant
7. WHEN listing campaigns for a participant, THE System SHALL verify the participant belongs to the requesting tenant
8. THE System SHALL never expose participant data across tenant boundaries
