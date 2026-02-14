defmodule CampaignsApi.Challenges.ChallengePropertyTest do
  use CampaignsApi.DataCase
  use ExUnitProperties

  alias CampaignsApi.Challenges.Challenge

  describe "Property 2: Challenge Name Validation" do
    # **Validates: Requirements 1.2**
    @tag :property
    property "names with fewer than 3 characters are rejected, names with 3+ characters are accepted" do
      check all(
              name <- string(:alphanumeric),
              max_runs: 100
            ) do
        attrs = %{name: name}
        changeset = Challenge.changeset(%Challenge{}, attrs)

        if String.length(name) < 3 do
          # Names with fewer than 3 characters should be invalid
          refute changeset.valid?,
                 "Expected name '#{name}' (length #{String.length(name)}) to be invalid"

          assert %{name: errors} = errors_on(changeset)

          # Empty string triggers "can't be blank", non-empty but < 3 chars triggers length validation
          if name == "" do
            assert "can't be blank" in errors
          else
            assert "should be at least 3 character(s)" in errors
          end
        else
          # Names with 3 or more characters should be valid
          assert changeset.valid?,
                 "Expected name '#{name}' (length #{String.length(name)}) to be valid"
        end
      end
    end
  end
end
