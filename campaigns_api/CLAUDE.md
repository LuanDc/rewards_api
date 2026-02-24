# Campaigns API — Claude Instructions

## Language Policy

You MUST follow these language rules for all outputs:

### Always in English:
- All code (variables, functions, classes, modules, etc.)
- All comments and documentation in code
- All specs and technical documentation
- All test files and test descriptions
- All commit messages
- All file names and folder names
- All configuration files
- All error messages in code
- All logs and debug output

### User's Language (Portuguese, Spanish, etc.):
- Conversational responses to the user
- Explanations and clarifications
- Questions to the user
- Summaries of work completed

### Examples

✅ Correct — respond in Portuguese but write code in English:
```elixir
defmodule EmailValidator do
  @moduledoc """
  Validates email addresses according to RFC standards.
  """

  def valid?(email) when is_binary(email) do
    # Check if email matches basic pattern
    String.match?(email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/)
  end
end
```

❌ Incorrect — do not use Portuguese in code:
```elixir
defmodule ValidadorDeEmail do
  def valido?(email) do
    # Verifica se o email é válido
    String.match?(email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/)
  end
end
```

---

## Project Standards

@.claude/elixir-quality-standards.md
@.claude/property-based-testing-strategy.md
@.claude/phoenix-swagger-standard.md
