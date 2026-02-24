defmodule CampaignsApi.PaginationTest do
  use CampaignsApi.DataCase, async: true
  use ExUnitProperties

  alias CampaignsApi.CampaignManagement.Campaign
  alias CampaignsApi.Pagination
  alias CampaignsApi.Repo

  import Ecto.Query

  setup do
    product = insert(:product)

    campaigns =
      for i <- 1..15 do
        {:ok, campaign} =
          %Campaign{}
          |> Campaign.changeset(%{
            product_id: product.id,
            name: "Campaign #{i}",
            description: "Test campaign #{i}"
          })
          |> Repo.insert()

        timestamp =
          DateTime.utc_now()
          |> DateTime.add(-(i * 60), :second)
          |> DateTime.truncate(:second)

        campaign
        |> Ecto.Changeset.change(inserted_at: timestamp)
        |> Repo.update!()
      end

    {:ok, product: product, campaigns: Enum.reverse(campaigns)}
  end

  describe "paginate/3" do
    test "returns first page with default limit of 50", %{product: product} do
      query = from c in Campaign, where: c.product_id == ^product.id

      result = Pagination.paginate(Repo, query)

      assert length(result.data) == 15
      assert result.has_more == false
      assert result.next_cursor == nil
    end

    test "respects custom limit parameter", %{product: product} do
      query = from c in Campaign, where: c.product_id == ^product.id

      result = Pagination.paginate(Repo, query, limit: 5)

      assert length(result.data) == 5
      assert result.has_more == true
      assert result.next_cursor != nil
    end

    test "enforces maximum limit of 100", %{product: product} do
      query = from c in Campaign, where: c.product_id == ^product.id

      result = Pagination.paginate(Repo, query, limit: 150)

      assert length(result.data) <= 15
    end

    test "orders by inserted_at descending by default", %{product: product} do
      query = from c in Campaign, where: c.product_id == ^product.id

      result = Pagination.paginate(Repo, query, limit: 5)

      first_campaign = List.first(result.data)
      last_campaign = List.last(result.data)

      assert DateTime.compare(first_campaign.inserted_at, last_campaign.inserted_at) == :gt
    end

    test "supports ascending order", %{product: product} do
      query = from c in Campaign, where: c.product_id == ^product.id

      result = Pagination.paginate(Repo, query, limit: 5, order: :asc)

      first_campaign = List.first(result.data)
      last_campaign = List.last(result.data)

      assert DateTime.compare(first_campaign.inserted_at, last_campaign.inserted_at) == :lt
    end

    test "applies cursor filtering for descending order", %{product: product} do
      query = from c in Campaign, where: c.product_id == ^product.id

      first_page = Pagination.paginate(Repo, query, limit: 5)
      assert length(first_page.data) == 5
      assert first_page.has_more == true

      second_page =
        Pagination.paginate(Repo, query, limit: 5, cursor: first_page.next_cursor)

      assert length(second_page.data) == 5
      assert second_page.has_more == true

      first_ids = Enum.map(first_page.data, & &1.id)
      second_ids = Enum.map(second_page.data, & &1.id)
      assert MapSet.disjoint?(MapSet.new(first_ids), MapSet.new(second_ids))

      last_first_page = List.last(first_page.data)
      first_second_page = List.first(second_page.data)

      assert DateTime.compare(
               last_first_page.inserted_at,
               first_second_page.inserted_at
             ) == :gt
    end

    test "applies cursor filtering for ascending order", %{product: product} do
      query = from c in Campaign, where: c.product_id == ^product.id

      first_page = Pagination.paginate(Repo, query, limit: 5, order: :asc)
      assert length(first_page.data) == 5

      second_page =
        Pagination.paginate(Repo, query,
          limit: 5,
          cursor: first_page.next_cursor,
          order: :asc
        )

      assert length(second_page.data) == 5

      last_first_page = List.last(first_page.data)
      first_second_page = List.first(second_page.data)

      assert DateTime.compare(
               last_first_page.inserted_at,
               first_second_page.inserted_at
             ) == :lt
    end

    test "returns has_more true when more records exist", %{product: product} do
      query = from c in Campaign, where: c.product_id == ^product.id

      result = Pagination.paginate(Repo, query, limit: 5)

      assert result.has_more == true
      assert result.next_cursor != nil
    end

    test "returns has_more false when no more records exist", %{product: product} do
      query = from c in Campaign, where: c.product_id == ^product.id

      result = Pagination.paginate(Repo, query, limit: 20)

      assert result.has_more == false
      assert result.next_cursor == nil
    end

    test "returns next_cursor as last record's cursor_field value", %{product: product} do
      query = from c in Campaign, where: c.product_id == ^product.id

      result = Pagination.paginate(Repo, query, limit: 5)

      last_campaign = List.last(result.data)
      assert result.next_cursor == last_campaign.inserted_at
    end

    test "supports custom cursor_field", %{product: product} do
      query = from c in Campaign, where: c.product_id == ^product.id

      result = Pagination.paginate(Repo, query, limit: 5, cursor_field: :updated_at)

      assert length(result.data) == 5
      last_campaign = List.last(result.data)
      assert result.next_cursor == last_campaign.updated_at
    end

    test "handles empty result set", %{product: _product} do
      query = from c in Campaign, where: c.product_id == "non-existent"

      result = Pagination.paginate(Repo, query)

      assert result.data == []
      assert result.has_more == false
      assert result.next_cursor == nil
    end

    test "handles exact limit match", %{product: product} do
      query = from c in Campaign, where: c.product_id == ^product.id

      result = Pagination.paginate(Repo, query, limit: 15)

      assert length(result.data) == 15
      assert result.has_more == false
      assert result.next_cursor == nil
    end
  end

  describe "Property: Cursor Ordering Consistency (Business Invariant)" do
    @tag :property
    property "pagination with cursor maintains ordering and no duplicates/gaps" do
      check all(
              campaign_count <- integer(10..30),
              limit <- integer(3..10),
              max_runs: 50
            ) do
        product = insert(:product)

        # Create campaigns with distinct timestamps
        campaigns =
          for i <- 1..campaign_count do
            {:ok, campaign} =
              %Campaign{}
              |> Campaign.changeset(%{
                product_id: product.id,
                name: "Campaign #{i} #{System.unique_integer([:positive])}",
                description: "Test campaign #{i}"
              })
              |> Repo.insert()

            timestamp =
              DateTime.utc_now()
              |> DateTime.add(-(i * 60), :second)
              |> DateTime.truncate(:second)

            campaign
            |> Ecto.Changeset.change(inserted_at: timestamp)
            |> Repo.update!()
          end

        query = from c in Campaign, where: c.product_id == ^product.id

        # Paginate through all records
        all_pages = collect_all_pages(query, limit)
        all_ids = Enum.flat_map(all_pages, fn page -> Enum.map(page.data, & &1.id) end)

        # Assert: No duplicates across pages
        assert length(all_ids) == length(Enum.uniq(all_ids)),
               "Found duplicate campaigns across pages"

        # Assert: No gaps - all campaigns should be returned
        assert length(all_ids) == campaign_count,
               "Expected #{campaign_count} campaigns, got #{length(all_ids)}"

        # Assert: Ordering is maintained (descending by inserted_at)
        all_campaigns = Enum.flat_map(all_pages, & &1.data)
        timestamps = Enum.map(all_campaigns, & &1.inserted_at)

        timestamps
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.each(fn [first, second] ->
          assert DateTime.compare(first, second) in [:gt, :eq],
                 "Ordering not maintained: #{first} should be >= #{second}"
        end)

        # Cleanup
        campaign_ids = Enum.map(campaigns, & &1.id)
        from(c in Campaign, where: c.id in ^campaign_ids) |> Repo.delete_all()
      end
    end

    defp collect_all_pages(query, limit, cursor \\ nil, acc \\ []) do
      opts = [limit: limit]
      opts = if cursor, do: Keyword.put(opts, :cursor, cursor), else: opts

      result = Pagination.paginate(Repo, query, opts)
      acc = [result | acc]

      if result.has_more do
        collect_all_pages(query, limit, result.next_cursor, acc)
      else
        Enum.reverse(acc)
      end
    end
  end

  describe "Unit tests for properties converted from property tests" do
    test "pagination returns consistent structure", %{product: product} do
      query = from c in Campaign, where: c.product_id == ^product.id

      result = Pagination.paginate(Repo, query)

      assert is_map(result)
      assert Map.has_key?(result, :data)
      assert Map.has_key?(result, :next_cursor)
      assert Map.has_key?(result, :has_more)
      assert is_list(result.data)
      assert is_boolean(result.has_more)
    end

    test "limit enforcement with maximum of 100", %{product: product} do
      query = from c in Campaign, where: c.product_id == ^product.id

      result = Pagination.paginate(Repo, query, limit: 200)

      assert length(result.data) <= 100
    end

    test "next_cursor presence when more records exist", %{product: product} do
      query = from c in Campaign, where: c.product_id == ^product.id

      result = Pagination.paginate(Repo, query, limit: 5)

      assert result.has_more == true
      assert result.next_cursor != nil

      last_record = List.last(result.data)
      assert result.next_cursor == last_record.inserted_at
    end
  end
end
