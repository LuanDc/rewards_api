defmodule CampaignsApi.ParticipantManagement.ParticipantTest do
  use CampaignsApi.DataCase
  use ExUnitProperties

  import CampaignsApi.Factory

  alias CampaignsApi.CampaignManagement.Participant

  describe "changeset/2 - valid participant creation" do
    test "creates valid participant with all fields" do
      attrs = %{
        tenant_id: "tenant-1",
        name: "John Doe",
        nickname: "johndoe",
        status: :inactive
      }

      changeset = Participant.changeset(%Participant{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :tenant_id) == "tenant-1"
      assert get_change(changeset, :name) == "John Doe"
      assert get_change(changeset, :nickname) == "johndoe"
      # Status is different from default, so it appears in changes
      assert get_change(changeset, :status) == :inactive
    end

    test "creates valid participant with only required fields" do
      attrs = %{
        tenant_id: "tenant-1",
        name: "Jane Doe",
        nickname: "janedoe"
      }

      changeset = Participant.changeset(%Participant{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :tenant_id) == "tenant-1"
      assert get_change(changeset, :name) == "Jane Doe"
      assert get_change(changeset, :nickname) == "janedoe"
      # Status defaults to :active
      assert get_change(changeset, :status) == nil
    end

    test "creates valid participant with inactive status" do
      attrs = %{
        tenant_id: "tenant-1",
        name: "Bob Smith",
        nickname: "bobsmith",
        status: :inactive
      }

      changeset = Participant.changeset(%Participant{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :status) == :inactive
    end

    test "creates valid participant with ineligible status" do
      attrs = %{
        tenant_id: "tenant-1",
        name: "Alice Johnson",
        nickname: "alicejohnson",
        status: :ineligible
      }

      changeset = Participant.changeset(%Participant{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :status) == :ineligible
    end
  end

  describe "changeset/2 - field length validations" do
    test "accepts name with exactly 1 character" do
      attrs = %{
        tenant_id: "tenant-1",
        name: "A",
        nickname: "abc"
      }

      changeset = Participant.changeset(%Participant{}, attrs)

      assert changeset.valid?
    end

    test "accepts name with more than 1 character" do
      attrs = %{
        tenant_id: "tenant-1",
        name: "John Doe",
        nickname: "johndoe"
      }

      changeset = Participant.changeset(%Participant{}, attrs)

      assert changeset.valid?
    end

    test "rejects name with empty string" do
      attrs = %{
        tenant_id: "tenant-1",
        name: "",
        nickname: "johndoe"
      }

      changeset = Participant.changeset(%Participant{}, attrs)

      refute changeset.valid?
      # Empty string triggers "can't be blank" before length validation
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "accepts nickname with exactly 3 characters" do
      attrs = %{
        tenant_id: "tenant-1",
        name: "John Doe",
        nickname: "abc"
      }

      changeset = Participant.changeset(%Participant{}, attrs)

      assert changeset.valid?
    end

    test "accepts nickname with more than 3 characters" do
      attrs = %{
        tenant_id: "tenant-1",
        name: "John Doe",
        nickname: "johndoe"
      }

      changeset = Participant.changeset(%Participant{}, attrs)

      assert changeset.valid?
    end

    test "rejects nickname with less than 3 characters" do
      attrs = %{
        tenant_id: "tenant-1",
        name: "John Doe",
        nickname: "ab"
      }

      changeset = Participant.changeset(%Participant{}, attrs)

      refute changeset.valid?
      assert %{nickname: ["should be at least 3 character(s)"]} = errors_on(changeset)
    end

    test "rejects nickname with empty string" do
      attrs = %{
        tenant_id: "tenant-1",
        name: "John Doe",
        nickname: ""
      }

      changeset = Participant.changeset(%Participant{}, attrs)

      refute changeset.valid?
      # Empty string triggers "can't be blank" before length validation
      assert %{nickname: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "changeset/2 - required field validations" do
    test "rejects participant without tenant_id" do
      attrs = %{
        name: "John Doe",
        nickname: "johndoe"
      }

      changeset = Participant.changeset(%Participant{}, attrs)

      refute changeset.valid?
      assert %{tenant_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects participant without name" do
      attrs = %{
        tenant_id: "tenant-1",
        nickname: "johndoe"
      }

      changeset = Participant.changeset(%Participant{}, attrs)

      refute changeset.valid?
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects participant without nickname" do
      attrs = %{
        tenant_id: "tenant-1",
        name: "John Doe"
      }

      changeset = Participant.changeset(%Participant{}, attrs)

      refute changeset.valid?
      assert %{nickname: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects participant with all required fields missing" do
      attrs = %{}

      changeset = Participant.changeset(%Participant{}, attrs)

      refute changeset.valid?
      errors = errors_on(changeset)
      assert %{tenant_id: ["can't be blank"]} = errors
      assert %{name: ["can't be blank"]} = errors
      assert %{nickname: ["can't be blank"]} = errors
    end
  end

  describe "changeset/2 - status enum validation" do
    test "accepts valid status values" do
      valid_statuses = [:active, :inactive, :ineligible]

      for status <- valid_statuses do
        attrs = %{
          tenant_id: "tenant-1",
          name: "John Doe",
          nickname: "user#{System.unique_integer([:positive])}",
          status: status
        }

        changeset = Participant.changeset(%Participant{}, attrs)

        assert changeset.valid?,
               "Expected status #{inspect(status)} to be valid, but got errors: #{inspect(errors_on(changeset))}"
      end
    end

    test "rejects invalid status value" do
      attrs = %{
        tenant_id: "tenant-1",
        name: "John Doe",
        nickname: "johndoe",
        status: :invalid_status
      }

      changeset = Participant.changeset(%Participant{}, attrs)

      refute changeset.valid?
      assert %{status: ["is invalid"]} = errors_on(changeset)
    end
  end

  describe "changeset/2 - nickname uniqueness constraint" do
    setup do
      # Create tenants for testing
      tenant1 = insert(:tenant, id: "tenant-unique-1")
      tenant2 = insert(:tenant, id: "tenant-unique-2")
      %{tenant1: tenant1, tenant2: tenant2}
    end

    test "enforces unique constraint on nickname", %{tenant1: tenant1, tenant2: tenant2} do
      # Insert first participant using changeset
      attrs1 = %{
        tenant_id: tenant1.id,
        name: "John Doe",
        nickname: "johndoe"
      }

      changeset1 = Participant.changeset(%Participant{}, attrs1)
      {:ok, _} = Repo.insert(changeset1)

      # Try to insert second participant with same nickname
      attrs2 = %{
        tenant_id: tenant2.id,
        name: "Jane Doe",
        nickname: "johndoe"
      }

      changeset2 = Participant.changeset(%Participant{}, attrs2)

      assert {:error, changeset} = Repo.insert(changeset2)
      assert %{nickname: ["has already been taken"]} = errors_on(changeset)
    end

    test "allows different nicknames for different participants", %{tenant1: tenant1} do
      # Insert first participant
      attrs1 = %{
        tenant_id: tenant1.id,
        name: "John Doe",
        nickname: "johndoe"
      }

      changeset1 = Participant.changeset(%Participant{}, attrs1)
      {:ok, _} = Repo.insert(changeset1)

      # Insert second participant with different nickname
      attrs2 = %{
        tenant_id: tenant1.id,
        name: "Jane Doe",
        nickname: "janedoe"
      }

      changeset2 = Participant.changeset(%Participant{}, attrs2)

      assert {:ok, _} = Repo.insert(changeset2)
    end
  end

  describe "Property 2: Type Validation at Schema Layer" do
    # **Validates: Requirements 1.2, 1.4, 3.2, 9.1, 9.2, 9.4**
    @tag :property
    property "rejects all invalid types for name field" do
      check all(
              invalid_value <- invalid_type_generator(),
              max_runs: 50
            ) do
        attrs = %{
          tenant_id: "tenant-1",
          name: invalid_value,
          nickname: "johndoe"
        }

        changeset = Participant.changeset(%Participant{}, attrs)

        refute changeset.valid?,
               "Expected name with invalid type #{inspect(invalid_value)} to be rejected"

        assert %{name: _errors} = errors_on(changeset)
      end
    end

    @tag :property
    property "rejects all invalid types for nickname field" do
      check all(
              invalid_value <- invalid_type_generator(),
              max_runs: 50
            ) do
        attrs = %{
          tenant_id: "tenant-1",
          name: "John Doe",
          nickname: invalid_value
        }

        changeset = Participant.changeset(%Participant{}, attrs)

        refute changeset.valid?,
               "Expected nickname with invalid type #{inspect(invalid_value)} to be rejected"

        assert %{nickname: _errors} = errors_on(changeset)
      end
    end

    @tag :property
    property "rejects all invalid types for tenant_id field" do
      check all(
              invalid_value <- invalid_type_generator(),
              max_runs: 50
            ) do
        attrs = %{
          tenant_id: invalid_value,
          name: "John Doe",
          nickname: "johndoe"
        }

        changeset = Participant.changeset(%Participant{}, attrs)

        refute changeset.valid?,
               "Expected tenant_id with invalid type #{inspect(invalid_value)} to be rejected"

        assert %{tenant_id: _errors} = errors_on(changeset)
      end
    end

    @tag :property
    property "rejects all invalid types for status field" do
      check all(
              invalid_value <-
                one_of([
                  integer(),
                  float(),
                  boolean(),
                  string(:alphanumeric, min_length: 1),
                  list_of(string(:alphanumeric)),
                  map_of(string(:alphanumeric), string(:alphanumeric))
                ]),
              # Filter out valid enum values
              invalid_value not in [:active, :inactive, :ineligible],
              max_runs: 50
            ) do
        attrs = %{
          tenant_id: "tenant-1",
          name: "John Doe",
          nickname: "johndoe",
          status: invalid_value
        }

        changeset = Participant.changeset(%Participant{}, attrs)

        refute changeset.valid?,
               "Expected status with invalid type #{inspect(invalid_value)} to be rejected"

        assert %{status: _errors} = errors_on(changeset)
      end
    end
  end

  # Helper generator for invalid types
  defp invalid_type_generator do
    one_of([
      constant(nil),
      integer(),
      float(),
      boolean(),
      list_of(string(:alphanumeric)),
      map_of(string(:alphanumeric), string(:alphanumeric))
    ])
  end
end
