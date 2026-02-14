defmodule CampaignsApi.PaginationPropertyTest do
  use CampaignsApi.DataCase
  use ExUnitProperties

  alias CampaignsApi.CampaignManagement.Campaign
  alias CampaignsApi.Pagination
  alias CampaignsApi.Repo
  alias CampaignsApi.Tenants

  import Ecto.Query

  setup do
    {:ok, tenant} = Tenants.create_tenant("test-tenant-#{System.unique_integer([:positive])}")
    {:ok, tenant: tenant}
  end

  property "pagination module works with any Ecto query and returns consistent structure",
           %{tenant: tenant} do
    check all(
            campaign_count <- integer(0..50),
            limit <- integer(1..100),
            use_cursor <- boolean(),
            order <- member_of([:asc, :desc]),
            cursor_field <- member_of([:inserted_at, :updated_at]),
            max_runs: 100
          ) do
      campaigns = create_campaigns(tenant.id, campaign_count)

      query = from c in Campaign, where: c.tenant_id == ^tenant.id

      opts = [limit: limit, order: order, cursor_field: cursor_field]

      opts =
        if use_cursor and campaign_count > 0 do
          middle_campaign = Enum.at(campaigns, div(campaign_count, 2))

          if middle_campaign do
            cursor_value = Map.get(middle_campaign, cursor_field)
            Keyword.put(opts, :cursor, cursor_value)
          else
            opts
          end
        else
          opts
        end

      result = Pagination.paginate(Repo, query, opts)

      assert is_map(result), "result should be a map"
      assert Map.has_key?(result, :data), "result should have :data key"
      assert Map.has_key?(result, :next_cursor), "result should have :next_cursor key"
      assert Map.has_key?(result, :has_more), "result should have :has_more key"

      assert is_list(result.data), "data should be a list"

      assert is_boolean(result.has_more), "has_more should be a boolean"

      assert result.next_cursor == nil or match?(%DateTime{}, result.next_cursor),
             "next_cursor should be nil or DateTime"

      cleanup_campaigns(campaigns)
    end
  end

  property "campaigns after cursor have timestamps in correct order relative to cursor",
           %{tenant: tenant} do
    check all(
            campaign_count <- integer(10..30),
            order <- member_of([:asc, :desc]),
            max_runs: 100
          ) do
      campaigns = create_campaigns_with_timestamps(tenant.id, campaign_count)

      middle_index = div(campaign_count, 2)
      middle_campaign = Enum.at(campaigns, middle_index)
      cursor = middle_campaign.inserted_at

      query = from c in Campaign, where: c.tenant_id == ^tenant.id

      result = Pagination.paginate(Repo, query, cursor: cursor, order: order, limit: 100)

      Enum.each(result.data, fn campaign ->
        comparison = DateTime.compare(campaign.inserted_at, cursor)

        case order do
          :desc ->
            assert comparison == :lt,
                   "campaign #{campaign.id} inserted_at should be before cursor in desc order"

          :asc ->
            assert comparison == :gt,
                   "campaign #{campaign.id} inserted_at should be after cursor in asc order"
        end
      end)

      cleanup_campaigns(campaigns)
    end
  end

  property "returned campaigns never exceed specified limit with maximum of 100", %{
    tenant: tenant
  } do
    check all(
            campaign_count <- integer(50..150),
            requested_limit <- integer(1..200),
            max_runs: 100
          ) do
      campaigns = create_campaigns(tenant.id, campaign_count)

      query = from c in Campaign, where: c.tenant_id == ^tenant.id

      result = Pagination.paginate(Repo, query, limit: requested_limit)

      expected_max_limit = min(requested_limit, 100)

      assert length(result.data) <= expected_max_limit,
             "returned #{length(result.data)} campaigns but limit was #{requested_limit} (max 100)"

      assert length(result.data) <= campaign_count,
             "returned more campaigns than exist"

      cleanup_campaigns(campaigns)
    end
  end

  property "next_cursor is present when more records exist and points to last record's cursor field",
           %{tenant: tenant} do
    check all(
            campaign_count <- integer(10..50),
            limit <- integer(1..20),
            cursor_field <- member_of([:inserted_at, :updated_at]),
            max_runs: 100
          ) do
      campaigns = create_campaigns_with_timestamps(tenant.id, campaign_count)

      query = from c in Campaign, where: c.tenant_id == ^tenant.id

      result = Pagination.paginate(Repo, query, limit: limit, cursor_field: cursor_field)

      if campaign_count > limit do
        assert result.has_more == true, "has_more should be true when more records exist"
        assert result.next_cursor != nil, "next_cursor should be present when more records exist"

        last_record = List.last(result.data)
        expected_cursor = Map.get(last_record, cursor_field)

        assert result.next_cursor == expected_cursor,
               "next_cursor should match last record's #{cursor_field}"
      else
        assert result.has_more == false, "has_more should be false when no more records exist"
        assert result.next_cursor == nil, "next_cursor should be nil when no more records exist"
      end

      cleanup_campaigns(campaigns)
    end
  end

  defp create_campaigns(_tenant_id, 0), do: []

  defp create_campaigns(tenant_id, count) when count > 0 do
    for i <- 1..count do
      {:ok, campaign} =
        %Campaign{}
        |> Campaign.changeset(%{
          tenant_id: tenant_id,
          name: "Campaign #{i} #{System.unique_integer([:positive])}",
          description: "Test campaign #{i}"
        })
        |> Repo.insert()

      campaign
    end
  end

  defp create_campaigns_with_timestamps(_tenant_id, 0), do: []

  defp create_campaigns_with_timestamps(tenant_id, count) when count > 0 do
    base_time = DateTime.utc_now() |> DateTime.truncate(:second)

    for i <- 1..count do
      {:ok, campaign} =
        %Campaign{}
        |> Campaign.changeset(%{
          tenant_id: tenant_id,
          name: "Campaign #{i} #{System.unique_integer([:positive])}",
          description: "Test campaign #{i}"
        })
        |> Repo.insert()

      timestamp = DateTime.add(base_time, -(i * 60), :second)

      campaign
      |> Ecto.Changeset.change(inserted_at: timestamp, updated_at: timestamp)
      |> Repo.update!()
    end
  end

  defp cleanup_campaigns(campaigns) do
    campaign_ids = Enum.map(campaigns, & &1.id)
    from(c in Campaign, where: c.id in ^campaign_ids) |> Repo.delete_all()
  end
end
