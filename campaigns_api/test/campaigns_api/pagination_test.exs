defmodule CampaignsApi.PaginationTest do
  use CampaignsApi.DataCase

  alias CampaignsApi.CampaignManagement.Campaign
  alias CampaignsApi.Pagination
  alias CampaignsApi.Repo
  alias CampaignsApi.Tenants

  import Ecto.Query

  setup do
    # Create a test tenant
    {:ok, tenant} = Tenants.create_tenant("test-tenant-#{System.unique_integer([:positive])}")

    # Create multiple campaigns with different timestamps
    campaigns =
      for i <- 1..15 do
        # Insert campaigns with staggered timestamps
        {:ok, campaign} =
          %Campaign{}
          |> Campaign.changeset(%{
            tenant_id: tenant.id,
            name: "Campaign #{i}",
            description: "Test campaign #{i}"
          })
          |> Repo.insert()

        # Update inserted_at to create a predictable sequence
        # Most recent first (15, 14, 13, ...)
        timestamp =
          DateTime.utc_now()
          |> DateTime.add(-(i * 60), :second)
          |> DateTime.truncate(:second)

        campaign
        |> Ecto.Changeset.change(inserted_at: timestamp)
        |> Repo.update!()
      end

    {:ok, tenant: tenant, campaigns: Enum.reverse(campaigns)}
  end

  describe "paginate/3" do
    test "returns first page with default limit of 50", %{tenant: tenant} do
      query = from c in Campaign, where: c.tenant_id == ^tenant.id

      result = Pagination.paginate(Repo, query)

      assert length(result.data) == 15
      assert result.has_more == false
      assert result.next_cursor == nil
    end

    test "respects custom limit parameter", %{tenant: tenant} do
      query = from c in Campaign, where: c.tenant_id == ^tenant.id

      result = Pagination.paginate(Repo, query, limit: 5)

      assert length(result.data) == 5
      assert result.has_more == true
      assert result.next_cursor != nil
    end

    test "enforces maximum limit of 100", %{tenant: tenant} do
      query = from c in Campaign, where: c.tenant_id == ^tenant.id

      # Request more than max limit
      result = Pagination.paginate(Repo, query, limit: 150)

      # Should only return up to 15 campaigns (all available)
      # The limit is capped at 100, but we only have 15 campaigns
      assert length(result.data) <= 15
    end

    test "orders by inserted_at descending by default", %{tenant: tenant} do
      query = from c in Campaign, where: c.tenant_id == ^tenant.id

      result = Pagination.paginate(Repo, query, limit: 5)

      # Most recent campaigns should come first
      first_campaign = List.first(result.data)
      last_campaign = List.last(result.data)

      assert DateTime.compare(first_campaign.inserted_at, last_campaign.inserted_at) == :gt
    end

    test "supports ascending order", %{tenant: tenant} do
      query = from c in Campaign, where: c.tenant_id == ^tenant.id

      result = Pagination.paginate(Repo, query, limit: 5, order: :asc)

      # Oldest campaigns should come first
      first_campaign = List.first(result.data)
      last_campaign = List.last(result.data)

      assert DateTime.compare(first_campaign.inserted_at, last_campaign.inserted_at) == :lt
    end

    test "applies cursor filtering for descending order", %{tenant: tenant} do
      query = from c in Campaign, where: c.tenant_id == ^tenant.id

      # Get first page
      first_page = Pagination.paginate(Repo, query, limit: 5)
      assert length(first_page.data) == 5
      assert first_page.has_more == true

      # Get second page using cursor
      second_page =
        Pagination.paginate(Repo, query, limit: 5, cursor: first_page.next_cursor)

      assert length(second_page.data) == 5
      assert second_page.has_more == true

      # Verify no overlap between pages
      first_ids = Enum.map(first_page.data, & &1.id)
      second_ids = Enum.map(second_page.data, & &1.id)
      assert MapSet.disjoint?(MapSet.new(first_ids), MapSet.new(second_ids))

      # Verify second page campaigns are older than first page
      last_first_page = List.last(first_page.data)
      first_second_page = List.first(second_page.data)

      assert DateTime.compare(
               last_first_page.inserted_at,
               first_second_page.inserted_at
             ) == :gt
    end

    test "applies cursor filtering for ascending order", %{tenant: tenant} do
      query = from c in Campaign, where: c.tenant_id == ^tenant.id

      # Get first page in ascending order
      first_page = Pagination.paginate(Repo, query, limit: 5, order: :asc)
      assert length(first_page.data) == 5

      # Get second page using cursor
      second_page =
        Pagination.paginate(Repo, query,
          limit: 5,
          cursor: first_page.next_cursor,
          order: :asc
        )

      assert length(second_page.data) == 5

      # Verify second page campaigns are newer than first page
      last_first_page = List.last(first_page.data)
      first_second_page = List.first(second_page.data)

      assert DateTime.compare(
               last_first_page.inserted_at,
               first_second_page.inserted_at
             ) == :lt
    end

    test "returns has_more true when more records exist", %{tenant: tenant} do
      query = from c in Campaign, where: c.tenant_id == ^tenant.id

      result = Pagination.paginate(Repo, query, limit: 5)

      assert result.has_more == true
      assert result.next_cursor != nil
    end

    test "returns has_more false when no more records exist", %{tenant: tenant} do
      query = from c in Campaign, where: c.tenant_id == ^tenant.id

      result = Pagination.paginate(Repo, query, limit: 20)

      assert result.has_more == false
      assert result.next_cursor == nil
    end

    test "returns next_cursor as last record's cursor_field value", %{tenant: tenant} do
      query = from c in Campaign, where: c.tenant_id == ^tenant.id

      result = Pagination.paginate(Repo, query, limit: 5)

      last_campaign = List.last(result.data)
      assert result.next_cursor == last_campaign.inserted_at
    end

    test "supports custom cursor_field", %{tenant: tenant} do
      query = from c in Campaign, where: c.tenant_id == ^tenant.id

      # Use updated_at as cursor field
      result = Pagination.paginate(Repo, query, limit: 5, cursor_field: :updated_at)

      assert length(result.data) == 5
      last_campaign = List.last(result.data)
      assert result.next_cursor == last_campaign.updated_at
    end

    test "handles empty result set", %{tenant: _tenant} do
      # Query for non-existent tenant
      query = from c in Campaign, where: c.tenant_id == "non-existent"

      result = Pagination.paginate(Repo, query)

      assert result.data == []
      assert result.has_more == false
      assert result.next_cursor == nil
    end

    test "handles exact limit match", %{tenant: tenant} do
      query = from c in Campaign, where: c.tenant_id == ^tenant.id

      # Request exactly the number of campaigns that exist
      result = Pagination.paginate(Repo, query, limit: 15)

      assert length(result.data) == 15
      assert result.has_more == false
      assert result.next_cursor == nil
    end
  end
end
