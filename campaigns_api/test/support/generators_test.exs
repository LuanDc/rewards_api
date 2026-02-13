defmodule CampaignsApi.GeneratorsTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import CampaignsApi.Generators

  describe "tenant_id_generator/0" do
    property "generates non-empty strings" do
      check all tenant_id <- tenant_id_generator() do
        assert is_binary(tenant_id)
        assert String.length(tenant_id) > 0
        assert String.starts_with?(tenant_id, "tenant-")
      end
    end
  end

  describe "campaign_name_generator/0" do
    property "generates strings with minimum 3 characters" do
      check all name <- campaign_name_generator() do
        assert is_binary(name)
        assert String.length(name) >= 3
      end
    end
  end

  describe "datetime_generator/0" do
    property "generates valid UTC datetimes" do
      check all dt <- datetime_generator() do
        assert %DateTime{} = dt
        assert dt.time_zone == "Etc/UTC"
        # Should be between 2020 and 2030
        assert dt.year >= 2020
        assert dt.year <= 2030
      end
    end
  end

  describe "campaign_status_generator/0" do
    property "generates valid campaign status values" do
      check all status <- campaign_status_generator() do
        assert status in [:active, :paused]
      end
    end
  end

  describe "tenant_status_generator/0" do
    property "generates valid tenant status values" do
      check all status <- tenant_status_generator() do
        assert status in [:active, :suspended, :deleted]
      end
    end
  end

  describe "jwt_generator/1" do
    property "generates valid JWT tokens with claims" do
      check all tenant_id <- tenant_id_generator() do
        claims = %{"tenant_id" => tenant_id}
        token = jwt_generator(claims) |> Enum.take(1) |> List.first()

        assert is_binary(token)
        assert String.contains?(token, ".")

        # Verify we can decode it
        {:ok, decoded_claims} = Joken.peek_claims(token)
        assert decoded_claims["tenant_id"] == tenant_id
      end
    end
  end

  describe "optional_field_generator/1" do
    property "generates nil or the wrapped value" do
      check all value <- optional_field_generator(string(:alphanumeric)) do
        assert is_nil(value) or is_binary(value)
      end
    end

    property "generates nil at least once in 100 iterations" do
      values = optional_field_generator(string(:alphanumeric))
        |> Enum.take(100)

      assert Enum.any?(values, &is_nil/1)
    end

    property "generates non-nil values at least once in 100 iterations" do
      values = optional_field_generator(string(:alphanumeric))
        |> Enum.take(100)

      assert Enum.any?(values, &(not is_nil(&1)))
    end
  end

  describe "ordered_datetime_pair_generator/0" do
    property "generates datetime pairs where first is before second" do
      check all {start_time, end_time} <- ordered_datetime_pair_generator() do
        assert %DateTime{} = start_time
        assert %DateTime{} = end_time
        assert DateTime.compare(start_time, end_time) == :lt
      end
    end
  end

  describe "campaign_attrs_generator/0" do
    property "generates valid campaign attributes" do
      check all attrs <- campaign_attrs_generator() do
        assert is_map(attrs)
        assert Map.has_key?(attrs, :name)
        assert Map.has_key?(attrs, :description)
        assert Map.has_key?(attrs, :start_time)
        assert Map.has_key?(attrs, :end_time)
        assert Map.has_key?(attrs, :status)

        # Validate types
        assert is_binary(attrs.name)
        assert String.length(attrs.name) >= 3
        assert is_nil(attrs.description) or is_binary(attrs.description)
        assert is_nil(attrs.start_time) or match?(%DateTime{}, attrs.start_time)
        assert is_nil(attrs.end_time) or match?(%DateTime{}, attrs.end_time)
        assert attrs.status in [:active, :paused]
      end
    end
  end

  describe "campaign_attrs_with_ordered_dates_generator/0" do
    property "generates campaign attributes with ordered dates" do
      check all attrs <- campaign_attrs_with_ordered_dates_generator() do
        assert is_map(attrs)
        assert %DateTime{} = attrs.start_time
        assert %DateTime{} = attrs.end_time
        assert DateTime.compare(attrs.start_time, attrs.end_time) == :lt
      end
    end
  end
end
