defmodule CampaignsApi.CampaignManagement.CampaignTest do
  use CampaignsApi.DataCase

  alias CampaignsApi.CampaignManagement.Campaign
  alias CampaignsApi.Tenants

  setup do
    # Create a test tenant for campaign tests
    {:ok, tenant} = Tenants.create_tenant("test-tenant-#{System.unique_integer([:positive])}")
    {:ok, tenant: tenant}
  end

  describe "campaign changeset validations" do
    test "accepts campaign without start_time and without end_time", %{tenant: tenant} do
      # Validates: Requirements 9.1
      attrs = %{
        tenant_id: tenant.id,
        name: "Campaign Without Dates"
      }

      changeset = Campaign.changeset(%Campaign{}, attrs)

      assert changeset.valid?
      assert get_field(changeset, :start_time) == nil
      assert get_field(changeset, :end_time) == nil
    end

    test "accepts campaign with start_time only", %{tenant: tenant} do
      # Validates: Requirements 9.2
      start_time = DateTime.utc_now() |> DateTime.truncate(:second)

      attrs = %{
        tenant_id: tenant.id,
        name: "Campaign With Start Only",
        start_time: start_time
      }

      changeset = Campaign.changeset(%Campaign{}, attrs)

      assert changeset.valid?
      assert get_field(changeset, :start_time) == start_time
      assert get_field(changeset, :end_time) == nil
    end

    test "accepts campaign with end_time only", %{tenant: tenant} do
      # Validates: Requirements 9.3
      end_time = DateTime.utc_now() |> DateTime.truncate(:second)

      attrs = %{
        tenant_id: tenant.id,
        name: "Campaign With End Only",
        end_time: end_time
      }

      changeset = Campaign.changeset(%Campaign{}, attrs)

      assert changeset.valid?
      assert get_field(changeset, :start_time) == nil
      assert get_field(changeset, :end_time) == end_time
    end

    test "accepts campaign with both start_time and end_time when start is before end", %{
      tenant: tenant
    } do
      # Validates: Requirements 9.4
      start_time = DateTime.utc_now() |> DateTime.truncate(:second)
      end_time = DateTime.add(start_time, 3600, :second)

      attrs = %{
        tenant_id: tenant.id,
        name: "Campaign With Both Dates",
        start_time: start_time,
        end_time: end_time
      }

      changeset = Campaign.changeset(%Campaign{}, attrs)

      assert changeset.valid?
      assert get_field(changeset, :start_time) == start_time
      assert get_field(changeset, :end_time) == end_time
    end

    test "rejects campaign when start_time is after end_time", %{tenant: tenant} do
      # Validates: Requirements 4.9
      end_time = DateTime.utc_now()
      start_time = DateTime.add(end_time, 3600, :second)

      attrs = %{
        tenant_id: tenant.id,
        name: "Invalid Date Order",
        start_time: start_time,
        end_time: end_time
      }

      changeset = Campaign.changeset(%Campaign{}, attrs)

      refute changeset.valid?
      assert Keyword.has_key?(changeset.errors, :start_time)
      {msg, _opts} = changeset.errors[:start_time]
      assert msg == "must be before end_time"
    end

    test "rejects campaign when start_time equals end_time", %{tenant: tenant} do
      # Validates: Requirements 4.9
      same_time = DateTime.utc_now()

      attrs = %{
        tenant_id: tenant.id,
        name: "Same Date Times",
        start_time: same_time,
        end_time: same_time
      }

      changeset = Campaign.changeset(%Campaign{}, attrs)

      refute changeset.valid?
      assert Keyword.has_key?(changeset.errors, :start_time)
      {msg, _opts} = changeset.errors[:start_time]
      assert msg == "must be before end_time"
    end

    test "rejects campaign with name less than 3 characters", %{tenant: tenant} do
      # Validates: Requirements 4.5
      attrs = %{
        tenant_id: tenant.id,
        name: "ab"
      }

      changeset = Campaign.changeset(%Campaign{}, attrs)

      refute changeset.valid?
      assert Keyword.has_key?(changeset.errors, :name)
      {_msg, opts} = changeset.errors[:name]
      assert opts[:count] == 3
    end

    test "accepts campaign with name of exactly 3 characters", %{tenant: tenant} do
      # Validates: Requirements 4.5
      attrs = %{
        tenant_id: tenant.id,
        name: "abc"
      }

      changeset = Campaign.changeset(%Campaign{}, attrs)

      assert changeset.valid?
    end

    test "accepts campaign with name longer than 3 characters", %{tenant: tenant} do
      # Validates: Requirements 4.5
      attrs = %{
        tenant_id: tenant.id,
        name: "Valid Campaign Name"
      }

      changeset = Campaign.changeset(%Campaign{}, attrs)

      assert changeset.valid?
    end

    test "accepts campaign without description field", %{tenant: tenant} do
      # Validates: Requirements 4.6
      attrs = %{
        tenant_id: tenant.id,
        name: "Campaign Without Description"
      }

      changeset = Campaign.changeset(%Campaign{}, attrs)

      assert changeset.valid?
      assert get_field(changeset, :description) == nil
    end

    test "accepts campaign with description field", %{tenant: tenant} do
      # Validates: Requirements 4.6
      attrs = %{
        tenant_id: tenant.id,
        name: "Campaign With Description",
        description: "This is a test campaign description"
      }

      changeset = Campaign.changeset(%Campaign{}, attrs)

      assert changeset.valid?
      assert get_field(changeset, :description) == "This is a test campaign description"
    end
  end
end
