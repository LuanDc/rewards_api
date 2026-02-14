# Requirements Document: Challenge System

## Introduction

This document specifies the requirements for a Challenge System that enables campaign creators to define evaluation criteria for campaign participants. Challenges are reusable evaluation mechanisms that can be associated with multiple campaigns through configurable criteria. Each challenge performs automated participant evaluations based on scheduled frequencies and awards or deducts points according to defined rules.

## Glossary

- **Challenge**: A reusable evaluation mechanism with a name, description, and metadata that defines how participant behavior is assessed
- **Campaign Challenge**: The association between a Challenge and a Campaign, including specific configuration for that campaign (frequency, points, custom name/description)
- **Evaluation Frequency**: The schedule pattern for running participant evaluations (e.g., daily, weekly, on-event)
- **Reward Points**: Points awarded (positive) or deducted (negative) when a participant meets the challenge criteria
- **Criteria**: The evaluation logic implemented by a Challenge (to be implemented in future iterations)
- **Participant**: A user enrolled in a campaign who is subject to challenge evaluations

## Requirements

### Requirement 1: Challenge Schema

**User Story:** As a system administrator, I want to register reusable challenges in the system, so that campaign creators from any tenant can associate them with their campaigns.

#### Acceptance Criteria

1. THE System SHALL store challenges with fields: id (UUID, PK), name (string, not null), description (text, nullable), metadata (jsonb, nullable), inserted_at, updated_at
2. THE System SHALL require the name field with minimum 3 characters
3. THE System SHALL allow challenges to be visible and usable by all tenants
4. THE System SHALL allow metadata to store arbitrary JSON data for future extensibility
5. THE System SHALL create an index on id

### Requirement 2: Campaign Challenge Association

**User Story:** As a campaign creator, I want to associate challenges with my campaigns with custom configurations, so that I can define specific evaluation rules for each campaign.

#### Acceptance Criteria

1. THE System SHALL store campaign_challenges with fields: id (UUID, PK), campaign_id (UUID, FK), challenge_id (UUID, FK), display_name (string, not null), display_description (text, nullable), evaluation_frequency (string, not null), reward_points (integer, not null), configuration (jsonb, nullable), inserted_at, updated_at
2. THE System SHALL require display_name field with minimum 3 characters
3. THE System SHALL require evaluation_frequency field (job scheduler format)
4. THE System SHALL allow reward_points to be positive (award) or negative (deduct)
5. THE System SHALL enforce unique constraint on (campaign_id, challenge_id) to prevent duplicate associations
6. THE System SHALL enforce foreign key constraint from campaign_challenges.campaign_id to campaigns.id with on_delete: :delete_all
7. THE System SHALL enforce foreign key constraint from campaign_challenges.challenge_id to challenges.id with on_delete: :restrict
8. THE System SHALL create composite index on (campaign_id, challenge_id)
9. THE System SHALL allow configuration to store arbitrary JSON data for challenge-specific settings

### Requirement 3: Campaign Challenge CRUD Operations

**User Story:** As a campaign creator, I want to manage challenge associations for my campaigns, so that I can configure evaluation rules.

#### Acceptance Criteria

1. WHEN an authenticated client sends a POST request to /api/campaigns/:campaign_id/challenges with valid data, THE System SHALL create a new campaign challenge association
2. WHEN creating a campaign challenge, THE System SHALL validate that the campaign belongs to the client's tenant_id
3. WHEN an authenticated client sends a GET request to /api/campaigns/:campaign_id/challenges, THE System SHALL return all challenge associations for that campaign
4. WHEN an authenticated client sends a GET request to /api/campaigns/:campaign_id/challenges/:id, THE System SHALL return the specific campaign challenge association
5. WHEN an authenticated client sends a PUT request to /api/campaigns/:campaign_id/challenges/:id with valid data, THE System SHALL update the campaign challenge configuration
6. WHEN an authenticated client sends a DELETE request to /api/campaigns/:campaign_id/challenges/:id, THE System SHALL remove the association
7. WHEN campaign challenge operations fail validation, THE System SHALL return HTTP 422 with structured JSON error details

### Requirement 4: Evaluation Frequency Validation

**User Story:** As a campaign creator, I want the system to validate evaluation frequency formats, so that I can ensure scheduled evaluations will work correctly.

#### Acceptance Criteria

1. THE System SHALL accept evaluation_frequency in cron-like format (e.g., "0 0 * * *" for daily at midnight)
2. THE System SHALL accept evaluation_frequency as predefined keywords: "daily", "weekly", "monthly", "on_event"
3. WHEN evaluation_frequency is invalid, THE System SHALL return validation error
4. THE System SHALL store evaluation_frequency as a string for future scheduler integration

### Requirement 5: Reward Points Validation

**User Story:** As a campaign creator, I want to configure positive or negative reward points, so that I can award or penalize participants based on their behavior.

#### Acceptance Criteria

1. THE System SHALL accept reward_points as any integer value (positive, negative, or zero)
2. THE System SHALL allow reward_points field to be optional (nullable, default 0)
3. WHEN reward_points is provided and not an integer, THE System SHALL return validation error

### Requirement 6: Data Isolation and Security

**User Story:** As a tenant, I want my campaign challenge configurations to be completely isolated from other tenants, so that my evaluation logic remains private.

#### Acceptance Criteria

1. THE System SHALL filter all campaign challenge queries by the authenticated tenant_id automatically through campaign ownership
2. THE System SHALL prevent any tenant from accessing campaign challenges belonging to other tenants' campaigns
3. WHEN associating a challenge with a campaign, THE System SHALL validate that the campaign belongs to the authenticated tenant
4. WHEN attempting cross-tenant operations, THE System SHALL return HTTP 404 Not Found

### Requirement 7: Cascade Deletion Rules

**User Story:** As a system administrator, I want proper cascade deletion rules, so that data integrity is maintained when campaigns or challenges are deleted.

#### Acceptance Criteria

1. WHEN a campaign is deleted, THE System SHALL automatically delete all associated campaign_challenges records
2. WHEN a challenge is deleted, THE System SHALL prevent deletion if any campaign_challenges associations exist
3. WHEN attempting to delete a challenge with associations, THE System SHALL return HTTP 422 with error message indicating active associations

### Requirement 8: Metadata and Configuration Flexibility

**User Story:** As a developer, I want flexible metadata and configuration storage, so that future challenge implementations can store custom data without schema changes.

#### Acceptance Criteria

1. THE System SHALL store challenges.metadata as JSONB for arbitrary challenge-specific data
2. THE System SHALL store campaign_challenges.configuration as JSONB for campaign-specific challenge settings
3. THE System SHALL accept any valid JSON structure in metadata and configuration fields
4. THE System SHALL return metadata and configuration as JSON in API responses

### Requirement 9: Phoenix Architecture Compliance

**User Story:** As a developer, I want the codebase to follow Phoenix best practices, so that the challenge system integrates seamlessly with existing code.

#### Acceptance Criteria

1. THE System SHALL organize challenge management logic in a Challenges context
2. THE System SHALL define a Challenges.Challenge schema
3. THE System SHALL define a Challenges.CampaignChallenge schema
4. THE System SHALL implement a CampaignsManagmentApiWeb.CampaignChallengeController for association management
5. THE System SHALL reuse existing authentication plugs (RequireAuth, AssignTenant)
6. THE System SHALL NOT expose Challenge CRUD operations via HTTP endpoints (reserved for queue-based implementation)
