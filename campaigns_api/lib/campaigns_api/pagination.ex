defmodule CampaignsApi.Pagination do
  @moduledoc """
  Reusable cursor-based pagination module for Ecto queries.

  Provides consistent pagination across all resources with configurable
  cursor field, limit, and sort order.
  """

  import Ecto.Query

  @type pagination_opts :: [
          limit: pos_integer(),
          cursor: DateTime.t() | nil,
          cursor_field: atom(),
          order: :asc | :desc
        ]

  @type pagination_result :: %{
          data: [struct()],
          next_cursor: DateTime.t() | nil,
          has_more: boolean()
        }

  @default_limit 50
  @max_limit 100

  @doc """
  Applies cursor-based pagination to any Ecto query.

  ## Options
  - `:limit` - Number of records to return (default: 50, max: 100)
  - `:cursor` - Cursor value (datetime) to paginate from
  - `:cursor_field` - Field to use for cursor (default: :inserted_at)
  - `:order` - Sort order, :desc or :asc (default: :desc)

  ## Returns
  %{
    data: [records],
    next_cursor: datetime | nil,
    has_more: boolean
  }

  ## Examples

      iex> query = from c in Campaign, where: c.tenant_id == "tenant-1"
      iex> Pagination.paginate(Repo, query, limit: 10)
      %{data: [...], next_cursor: ~U[2024-01-01 12:00:00Z], has_more: true}

      iex> Pagination.paginate(Repo, query, cursor: ~U[2024-01-01 12:00:00Z], limit: 10)
      %{data: [...], next_cursor: nil, has_more: false}
  """
  @spec paginate(Ecto.Repo.t(), Ecto.Query.t(), pagination_opts()) :: pagination_result()
  def paginate(repo, query, opts \\ []) do
    limit = opts |> Keyword.get(:limit, @default_limit) |> min(@max_limit)
    cursor = Keyword.get(opts, :cursor)
    cursor_field = Keyword.get(opts, :cursor_field, :inserted_at)
    order = Keyword.get(opts, :order, :desc)

    # Apply ordering
    query =
      from q in query,
        order_by: [{^order, field(q, ^cursor_field)}],
        limit: ^(limit + 1)

    # Apply cursor filter
    query =
      if cursor do
        case order do
          :desc -> from q in query, where: field(q, ^cursor_field) < ^cursor
          :asc -> from q in query, where: field(q, ^cursor_field) > ^cursor
        end
      else
        query
      end

    # Execute query
    records = repo.all(query)

    # Check if there are more records
    {results, has_more} =
      if length(records) > limit do
        {Enum.take(records, limit), true}
      else
        {records, false}
      end

    # Get next cursor
    next_cursor =
      if has_more do
        results |> List.last() |> Map.get(cursor_field)
      else
        nil
      end

    %{
      data: results,
      next_cursor: next_cursor,
      has_more: has_more
    }
  end
end
