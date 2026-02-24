# Elixir Code Quality Standards

## Overview

This document defines the code quality standards that must be followed for all Elixir implementations in this project.

## Type Specifications

### Required Type Annotations

All public functions MUST have `@spec` annotations:

```elixir
@spec create_challenge(map()) :: {:ok, Challenge.t()} | {:error, Ecto.Changeset.t()}
def create_challenge(attrs) do
  # implementation
end
```

### Schema Types

All schemas MUST define `@type t` for their struct:

```elixir
defmodule Challenge do
  use Ecto.Schema
  
  @type t :: %__MODULE__{
    id: Ecto.UUID.t(),
    name: String.t(),
    description: String.t() | nil,
    metadata: map() | nil,
    inserted_at: DateTime.t(),
    updated_at: DateTime.t()
  }
  
  schema "challenges" do
    field :name, :string
    field :description, :string
    field :metadata, :map
    timestamps(type: :utc_datetime)
  end
end
```

### Keyword List Options

Keyword list options MUST be typed:

```elixir
@type pagination_opts :: [
  limit: pos_integer(),
  cursor: DateTime.t() | nil
]

@spec list_challenges(pagination_opts()) :: pagination_result()
def list_challenges(opts \\ []) do
  # implementation
end
```

### Complex Types

Complex types MUST use `@typedoc` for documentation:

```elixir
@typedoc """
Pagination result containing data, cursor, and has_more flag.
"""
@type pagination_result :: %{
  data: [struct()],
  cursor: DateTime.t() | nil,
  has_more: boolean()
}
```

### Error Response Types

All error responses MUST be explicitly typed:

```elixir
@spec delete_challenge(Ecto.UUID.t()) :: 
  {:ok, Challenge.t()} | {:error, :not_found | :has_associations}
```

## Static Analysis

### Code Formatting

Run Elixir formatter to ensure consistent code style:

```bash
mix format
```

**Requirements:**
- All code must be formatted according to Elixir standards
- Run before committing changes
- Verify no formatting changes are needed: `mix format --check-formatted`

### Credo

Run Credo in strict mode at the end of implementation:

```bash
mix credo --strict
```

**Requirements:**
- Zero warnings
- Zero errors
- All issues must be fixed before considering implementation complete

### Dialyzer

Run Dialyzer to check type consistency:

```bash
mix dialyzer
```

**Requirements:**
- Zero type warnings
- All type inconsistencies must be fixed
- Ensure all specs match actual function signatures

## Test Data Setup

### ExMachina Usage

All test data MUST be created using ExMachina:

```elixir
# ✅ Correct
test "creates a challenge" do
  attrs = params_for(:challenge, name: "Test Challenge")
  assert {:ok, challenge} = Challenges.create_challenge(attrs)
end

# ❌ Incorrect - Don't manually create structs
test "creates a challenge" do
  attrs = %{name: "Test Challenge", description: "Test"}
  assert {:ok, challenge} = Challenges.create_challenge(attrs)
end
```

### Factory Definitions

Define factories in `test/support/factory.ex`:

```elixir
def challenge_factory do
  %Challenge{
    id: Ecto.UUID.generate(),
    name: "Challenge #{System.unique_integer([:positive])}",
    description: "Description for challenge",
    metadata: %{"type" => "evaluation"}
  }
end
```

### Factory Helpers

Use ExMachina helpers appropriately:
- `build/1` - Build struct without inserting
- `insert/1` - Build and insert into database
- `params_for/1` - Generate map of attributes

## Implementation Checklist

Before considering any implementation complete, verify:

- [ ] All public functions have `@spec` annotations
- [ ] All schemas have `@type t` definitions
- [ ] All keyword options are typed
- [ ] Complex types have `@typedoc` documentation
- [ ] `mix format` passes without changes
- [ ] `mix credo --strict` returns zero issues
- [ ] `mix dialyzer` returns zero warnings
- [ ] All tests use ExMachina for data setup
- [ ] No manual struct creation in tests

## Rationale

**Type Specifications:**
- Enable compile-time type checking with Dialyzer
- Serve as inline documentation
- Catch type errors early in development
- Improve code maintainability

**Static Analysis:**
- Credo enforces code consistency and best practices
- Dialyzer catches type errors and inconsistencies
- Both tools prevent common bugs before runtime

**ExMachina:**
- Provides consistent test data
- Reduces test boilerplate
- Makes tests more readable
- Easier to maintain test data as schemas evolve
