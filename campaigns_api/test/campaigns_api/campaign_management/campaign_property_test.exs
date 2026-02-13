defmodule CampaignsApi.CampaignManagement.CampaignPropertyTest do
  use CampaignsApi.DataCase
  use ExUnitProperties

  alias CampaignsApi.CampaignManagement.Campaign
  alias CampaignsApi.Tenants

  setup do
    # Create a test tenant for campaign tests
    {:ok, tenant} = Tenants.create_tenant("test-tenant-#{System.unique_integer([:positive])}")
    {:ok, tenant: tenant}
  end

  # Feature: campaign-management-api, Property 9: Campaign Name Validation
  # **Validates: Requirements 4.5**
  property "campaign names with fewer than 3 characters are rejected, 3+ characters accepted",
           %{tenant: tenant} do
    check all(
            name_length <- integer(1..10),
            max_runs: 100
          ) do
      name = String.duplicate("a", name_length)

      attrs = %{
        tenant_id: tenant.id,
        name: name
      }

      changeset = Campaign.changeset(%Campaign{}, attrs)

      if name_length < 3 do
        # Names with fewer than 3 characters should be invalid
        assert changeset.valid? == false,
               "campaign with name length #{name_length} should be invalid"

        assert Keyword.has_key?(changeset.errors, :name),
               "changeset should have error on :name field"

        # Verify the error is about minimum length
        {_msg, opts} = changeset.errors[:name]
        assert opts[:count] == 3, "error should specify minimum length of 3"
      else
        # Names with 3 or more characters should be valid (assuming tenant_id is present)
        assert changeset.valid? == true,
               "campaign with name length #{name_length} should be valid"

        assert not Keyword.has_key?(changeset.errors, :name),
               "changeset should not have error on :name field"
      end
    end
  end

  # Feature: campaign-management-api, Property 11: Date Order Validation
  # **Validates: Requirements 4.9**
  property "campaigns with both dates must have start_time before end_time", %{tenant: tenant} do
    check all(
            # Generate two different datetimes
            base_datetime <- datetime_generator(),
            offset_seconds <- integer(1..86_400),
            # Randomly decide which is start and which is end
            swap <- boolean(),
            max_runs: 100
          ) do
      # Create two datetimes with known ordering
      earlier = base_datetime
      later = DateTime.add(base_datetime, offset_seconds, :second)

      # Swap them based on the boolean to test both valid and invalid cases
      {start_time, end_time} =
        if swap do
          {later, earlier}
        else
          {earlier, later}
        end

      attrs = %{
        tenant_id: tenant.id,
        name: "Test Campaign",
        start_time: start_time,
        end_time: end_time
      }

      changeset = Campaign.changeset(%Campaign{}, attrs)

      if swap do
        # When start_time is after end_time, should be invalid
        assert changeset.valid? == false,
               "campaign with start_time after end_time should be invalid"

        assert Keyword.has_key?(changeset.errors, :start_time),
               "changeset should have error on :start_time field"

        # Verify the error message
        {msg, _opts} = changeset.errors[:start_time]
        assert msg == "must be before end_time", "error message should indicate date order issue"
      else
        # When start_time is before end_time, should be valid
        assert changeset.valid? == true,
               "campaign with start_time before end_time should be valid"

        assert not Keyword.has_key?(changeset.errors, :start_time),
               "changeset should not have error on :start_time field"
      end
    end
  end

  # Generator for valid UTC datetimes
  defp datetime_generator do
    gen all(
          year <- integer(2020..2030),
          month <- integer(1..12),
          day <- integer(1..28),
          hour <- integer(0..23),
          minute <- integer(0..59),
          second <- integer(0..59)
        ) do
      {:ok, datetime} = DateTime.new(Date.new!(year, month, day), Time.new!(hour, minute, second))
      datetime
    end
  end
end
