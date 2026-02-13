defmodule CampaignsApi.Generators do
  @moduledoc """
  StreamData generators for property-based testing.
  """

  import StreamData

  @doc """
  Generates valid tenant IDs (non-empty strings).
  """
  def tenant_id_generator do
    string(:alphanumeric, min_length: 1, max_length: 50)
    |> map(fn str -> "tenant-#{str}" end)
  end

  @doc """
  Generates valid campaign names (minimum 3 characters).
  """
  def campaign_name_generator do
    string(:alphanumeric, min_length: 3, max_length: 100)
  end

  @doc """
  Generates UTC datetime values.
  """
  def datetime_generator do
    # Generate timestamps between 2020-01-01 and 2030-12-31
    integer(1_577_836_800..1_893_456_000)
    |> map(fn timestamp ->
      DateTime.from_unix!(timestamp)
    end)
  end

  @doc """
  Generates campaign status values (:active or :paused).
  """
  def campaign_status_generator do
    member_of([:active, :paused])
  end

  @doc """
  Generates tenant status values (:active, :suspended, or :deleted).
  """
  def tenant_status_generator do
    member_of([:active, :suspended, :deleted])
  end

  @doc """
  Generates JWT tokens with the given claims.

  ## Examples

      iex> jwt_generator(%{"tenant_id" => "test-tenant"})
  """
  def jwt_generator(claims) do
    constant(create_jwt(claims))
  end

  @doc """
  Wraps a generator to make it optional (returns nil or the generated value).
  """
  def optional_field_generator(generator) do
    one_of([constant(nil), generator])
  end

  @doc """
  Generates a pair of datetimes where the first is before the second.
  """
  def ordered_datetime_pair_generator do
    bind(datetime_generator(), fn start_time ->
      # Generate end_time that's after start_time
      integer(1..365 * 24 * 3600) # 1 second to 1 year later
      |> map(fn seconds_later ->
        end_time = DateTime.add(start_time, seconds_later, :second)
        {start_time, end_time}
      end)
    end)
  end

  @doc """
  Generates valid campaign attributes with all required fields.
  """
  def campaign_attrs_generator do
    fixed_map(%{
      name: campaign_name_generator(),
      description: optional_field_generator(string(:alphanumeric, max_length: 500)),
      start_time: optional_field_generator(datetime_generator()),
      end_time: optional_field_generator(datetime_generator()),
      status: campaign_status_generator()
    })
  end

  @doc """
  Generates valid campaign attributes with ordered dates (start_time < end_time).
  """
  def campaign_attrs_with_ordered_dates_generator do
    bind(ordered_datetime_pair_generator(), fn {start_time, end_time} ->
      fixed_map(%{
        name: campaign_name_generator(),
        description: optional_field_generator(string(:alphanumeric, max_length: 500)),
        start_time: constant(start_time),
        end_time: constant(end_time),
        status: campaign_status_generator()
      })
    end)
  end

  # Private helper to create JWT tokens
  defp create_jwt(claims) do
    header = %{"alg" => "none", "typ" => "JWT"}

    header_json = Jason.encode!(header)
    claims_json = Jason.encode!(claims)

    header_b64 = Base.url_encode64(header_json, padding: false)
    claims_b64 = Base.url_encode64(claims_json, padding: false)

    "#{header_b64}.#{claims_b64}."
  end
end
