defmodule CampaignsApi.Challenges.ChallengeTest do
  use CampaignsApi.DataCase, async: true

  alias CampaignsApi.Challenges.Challenge

  describe "changeset/2" do
    test "creates valid challenge with all fields" do
      attrs = %{
        name: "Valid Challenge",
        description: "A valid challenge description",
        metadata: %{"type" => "evaluation", "version" => 1}
      }

      changeset = Challenge.changeset(%Challenge{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :name) == "Valid Challenge"
      assert get_change(changeset, :description) == "A valid challenge description"
      assert get_change(changeset, :metadata) == %{"type" => "evaluation", "version" => 1}
    end

    test "creates valid challenge with only required fields" do
      attrs = %{name: "Minimal Challenge"}

      changeset = Challenge.changeset(%Challenge{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :name) == "Minimal Challenge"
      assert get_change(changeset, :description) == nil
      assert get_change(changeset, :metadata) == nil
    end

    test "rejects challenge with name less than 3 characters" do
      attrs = %{name: "ab"}

      changeset = Challenge.changeset(%Challenge{}, attrs)

      refute changeset.valid?
      assert %{name: ["should be at least 3 character(s)"]} = errors_on(changeset)
    end

    test "accepts challenge with name exactly 3 characters" do
      attrs = %{name: "abc"}

      changeset = Challenge.changeset(%Challenge{}, attrs)

      assert changeset.valid?
    end

    test "accepts challenge with name more than 3 characters" do
      attrs = %{name: "Valid Challenge Name"}

      changeset = Challenge.changeset(%Challenge{}, attrs)

      assert changeset.valid?
    end

    test "rejects challenge without name" do
      attrs = %{description: "Description without name"}

      changeset = Challenge.changeset(%Challenge{}, attrs)

      refute changeset.valid?
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "accepts challenge with nil description" do
      attrs = %{name: "Challenge", description: nil}

      changeset = Challenge.changeset(%Challenge{}, attrs)

      assert changeset.valid?
    end

    test "accepts challenge with empty string description" do
      attrs = %{name: "Challenge", description: ""}

      changeset = Challenge.changeset(%Challenge{}, attrs)

      assert changeset.valid?
    end

    test "accepts challenge with nil metadata" do
      attrs = %{name: "Challenge", metadata: nil}

      changeset = Challenge.changeset(%Challenge{}, attrs)

      assert changeset.valid?
    end

    test "accepts challenge with empty map metadata" do
      attrs = %{name: "Challenge", metadata: %{}}

      changeset = Challenge.changeset(%Challenge{}, attrs)

      assert changeset.valid?
    end

    test "accepts challenge with nested JSON metadata" do
      attrs = %{
        name: "Challenge",
        metadata: %{
          "config" => %{
            "threshold" => 100,
            "enabled" => true
          },
          "tags" => ["important", "active"]
        }
      }

      changeset = Challenge.changeset(%Challenge{}, attrs)

      assert changeset.valid?
      metadata = get_change(changeset, :metadata)
      assert metadata["config"]["threshold"] == 100
      assert metadata["config"]["enabled"] == true
      assert metadata["tags"] == ["important", "active"]
    end

    test "accepts challenge with various JSON data types in metadata" do
      attrs = %{
        name: "Challenge",
        metadata: %{
          "string" => "value",
          "integer" => 42,
          "float" => 3.14,
          "boolean" => true,
          "null" => nil,
          "array" => [1, 2, 3],
          "object" => %{"nested" => "data"}
        }
      }

      changeset = Challenge.changeset(%Challenge{}, attrs)

      assert changeset.valid?
      metadata = get_change(changeset, :metadata)
      assert metadata["string"] == "value"
      assert metadata["integer"] == 42
      assert metadata["float"] == 3.14
      assert metadata["boolean"] == true
      assert metadata["null"] == nil
      assert metadata["array"] == [1, 2, 3]
      assert metadata["object"] == %{"nested" => "data"}
    end
  end
end
