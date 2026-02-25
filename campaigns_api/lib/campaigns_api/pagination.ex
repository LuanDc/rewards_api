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

  @type pagination_result(data_type) :: %{
          data: [data_type],
          next_cursor: DateTime.t() | nil,
          has_more: boolean()
        }

  @default_limit 50
  @max_limit 100

  @doc """
  Applies cursor-based pagination to any Ecto query.
  """
  @spec paginate(Ecto.Repo.t(), Ecto.Query.t(), pagination_opts()) :: pagination_result(struct())
  def paginate(repo, query, opts \\ []) do
    limit = opts |> Keyword.get(:limit, @default_limit) |> min(@max_limit)
    cursor = Keyword.get(opts, :cursor)
    cursor_field = Keyword.get(opts, :cursor_field, :inserted_at)
    order = Keyword.get(opts, :order, :desc)

    query =
      from q in query,
        order_by: [{^order, field(q, ^cursor_field)}],
        limit: ^(limit + 1)

    query =
      if cursor do
        case order do
          :desc -> from q in query, where: field(q, ^cursor_field) < ^cursor
          :asc -> from q in query, where: field(q, ^cursor_field) > ^cursor
        end
      else
        query
      end

    records = repo.all(query)

    {results, has_more} =
      if length(records) > limit do
        {Enum.take(records, limit), true}
      else
        {records, false}
      end

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
