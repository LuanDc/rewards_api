# Property-Based Testing Strategy

## Overview

Property-based testing (PBT) is a powerful technique for finding edge cases, but excessive use can slow down test suites without proportional value. This document defines a pragmatic approach to PBT that focuses on high-value scenarios while keeping test execution fast.

## Core Principles

1. **Test Business Invariants**: Use PBT for rules that must hold across all valid inputs
2. **Test at the Right Layer**: Test once at the deepest layer, avoid redundant testing in upper layers
3. **Co-locate Tests**: Keep property tests in the same file as unit/integration tests
4. **Keep It Fast**: Limit iterations to maintain fast feedback loops

## When to Use Property-Based Testing

### ✅ DO Use PBT For:

1. **Business Invariants**
   - Rules that must always hold (e.g., "tenant isolation must never be violated")
   - Mathematical properties (e.g., "create then delete returns to original state")
   - Data integrity constraints (e.g., "unique constraints are always enforced")

2. **Type Validation at Boundaries**
   - Generate all invalid types and verify proper rejection
   - Test that validation catches all malformed inputs
   - Verify error messages are consistent

3. **Complex State Transitions**
   - Multi-step workflows that must maintain consistency
   - Cascade operations (e.g., "deleting parent removes all children")

4. **Pagination and Ordering**
   - Cursor consistency across pages
   - No duplicates or missing records
   - Ordering is maintained

### ❌ DON'T Use PBT For:

1. **Simple CRUD Operations**
   - Basic create/read/update/delete with valid data
   - Use unit tests instead - they're faster and clearer

2. **Already Tested Lower Layers**
   - If context layer has PBT for validation, controller doesn't need it
   - Exception: Testing for unhandled exceptions in upper layers

3. **External API Contracts**
   - HTTP response formats
   - JSON serialization
   - Use integration tests instead

4. **UI/Presentation Logic**
   - View rendering
   - Response formatting
   - Use unit tests instead

## Test Organization

### File Structure

**DO NOT** create separate files for property tests. Co-locate them with unit tests:

```elixir
# ✅ Correct - Single test file
defmodule CampaignsApi.ParticipantManagementTest do
  use CampaignsApi.DataCase
  use ExUnitProperties  # Add this for property tests
  
  alias CampaignsApi.ParticipantManagement
  
  describe "create_participant/2" do
    # Unit tests for specific cases
    test "creates participant with valid attributes" do
      # ...
    end
    
    test "returns error for missing name" do
      # ...
    end
    
    # Property test for invariants
    property "rejects all invalid attribute combinations" do
      check all attrs <- invalid_participant_attrs() do
        assert {:error, changeset} = ParticipantManagement.create_participant("tenant-1", attrs)
        assert changeset.valid? == false
      end
    end
  end
end
```

```elixir
# ❌ Incorrect - Separate property test file
# test/campaigns_api/participant_management_property_test.exs
```

### Naming Convention

- Unit tests: `test "description"`
- Property tests: `property "invariant description"`

## Layer Selection Strategy

### Test Pyramid for PBT

```
┌─────────────────────────────────────┐
│   Controller Layer                  │  ← Minimal PBT (exception handling only)
│   - Integration tests (unit)        │
│   - PBT only for unhandled errors   │
├─────────────────────────────────────┤
│   Context Layer                     │  ← PRIMARY PBT LAYER
│   - Business logic tests (unit)     │  ← Test invariants here
│   - Property tests for invariants   │  ← Test validation here
├─────────────────────────────────────┤
│   Schema Layer                      │  ← Minimal PBT (changeset validation)
│   - Changeset tests (unit)          │
│   - PBT for type validation         │
└─────────────────────────────────────┘
```

### Decision Tree

```
Is this a business invariant that must always hold?
├─ YES → Use PBT at Context layer
└─ NO → Is this input validation?
    ├─ YES → Use PBT at Schema layer (changeset)
    └─ NO → Is this already tested in lower layer?
        ├─ YES → Use unit test only (or skip)
        └─ NO → Use unit test
```

## Practical Examples

### Example 1: Tenant Isolation (Business Invariant)

```elixir
# ✅ Test at Context layer
describe "tenant isolation" do
  property "never returns data from other tenants" do
    check all tenant_a <- tenant_id_generator(),
              tenant_b <- tenant_id_generator(),
              tenant_a != tenant_b do
      
      participant = insert(:participant, tenant_id: tenant_a)
      
      # Tenant B should never see Tenant A's data
      assert nil == ParticipantManagement.get_participant(tenant_b, participant.id)
    end
  end
end
```

### Example 2: Type Validation (Boundary Testing)

```elixir
# ✅ Test at Schema layer (changeset)
describe "participant changeset validation" do
  property "rejects invalid types for all fields" do
    check all invalid_attrs <- one_of([
            %{name: invalid_type()},  # Generate non-string types
            %{nickname: invalid_type()},
            %{status: invalid_type()},
            %{tenant_id: invalid_type()}
          ]) do
      
      changeset = Participant.changeset(%Participant{}, invalid_attrs)
      refute changeset.valid?
    end
  end
end

# Helper generator
defp invalid_type do
  one_of([
    constant(nil),
    integer(),
    float(),
    boolean(),
    list_of(string()),
    map_of(string(), string())
  ])
end
```

### Example 3: CRUD Round Trip (Don't Use PBT)

```elixir
# ✅ Use simple unit test instead
test "create, read, update, delete cycle" do
  tenant_id = "tenant-1"
  
  # Create
  {:ok, participant} = ParticipantManagement.create_participant(tenant_id, %{
    name: "John Doe",
    nickname: "johndoe"
  })
  
  # Read
  assert ^participant = ParticipantManagement.get_participant(tenant_id, participant.id)
  
  # Update
  {:ok, updated} = ParticipantManagement.update_participant(tenant_id, participant.id, %{
    name: "Jane Doe"
  })
  assert updated.name == "Jane Doe"
  
  # Delete
  {:ok, _} = ParticipantManagement.delete_participant(tenant_id, participant.id)
  assert nil == ParticipantManagement.get_participant(tenant_id, participant.id)
end
```

### Example 4: Controller (Minimal PBT)

```elixir
# ✅ Controller tests are mostly unit tests
describe "POST /api/participants" do
  test "creates participant with valid data" do
    conn = post(conn, "/api/participants", %{name: "John", nickname: "john"})
    assert json_response(conn, 201)
  end
  
  test "returns 422 for invalid data" do
    conn = post(conn, "/api/participants", %{name: ""})
    assert json_response(conn, 422)
  end
  
  # ❌ Don't duplicate context layer PBT here
  # The context layer already tests validation thoroughly
end
```

## Performance Guidelines

### Iteration Limits

Configure StreamData to use fewer iterations for faster feedback:

```elixir
# In test_helper.exs or individual test files
ExUnitProperties.configure(
  max_runs: 50,  # Default is 100, reduce for speed
  max_run_time: 5_000  # 5 seconds max per property
)
```

### Selective Property Testing

Use tags to run property tests selectively:

```elixir
@tag :property
property "tenant isolation is never violated" do
  # ...
end
```

Run only property tests:
```bash
mix test --only property
```

Skip property tests for fast feedback:
```bash
mix test --exclude property
```

## Migration Strategy for Existing Tests

If you have excessive property tests slowing down your suite:

1. **Identify Redundant Tests**
   - Find property tests that duplicate unit tests
   - Find property tests in upper layers that duplicate lower layer tests

2. **Consolidate**
   - Move property tests to the deepest relevant layer
   - Convert simple property tests to unit tests
   - Remove redundant tests

3. **Optimize Remaining Tests**
   - Reduce iteration counts
   - Simplify generators
   - Add tags for selective execution

## Summary Checklist

Before writing a property test, ask:

- [ ] Is this a business invariant that must always hold?
- [ ] Am I testing at the deepest relevant layer?
- [ ] Is this already covered by a lower layer test?
- [ ] Will this test provide value proportional to its execution time?
- [ ] Can this be tested more simply with a unit test?

If you answer "no" to any of these, consider using a unit test instead.

## Rationale

**Why This Approach:**
- Maintains fast test suite execution
- Focuses PBT on high-value scenarios
- Reduces test maintenance burden
- Keeps tests co-located for better discoverability
- Prevents redundant testing across layers
- Provides clear guidelines for when to use PBT

**Benefits:**
- Faster CI/CD pipelines
- Quicker local development feedback
- Better test signal-to-noise ratio
- Easier onboarding for new developers
- More maintainable test suite
