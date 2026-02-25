defmodule CampaignsApiWeb.Plugs.AssignProduct do
  @moduledoc """
  Plug for Just-in-Time product provisioning and access control.

  This plug:
  - Gets or creates a product based on the product_id from conn.assigns
  - Checks if the product is active
  - Assigns the product to conn.assigns if active
  - Returns 403 Forbidden if product is not active (suspended or deleted)

  Requires RequireAuth plug to run first to set conn.assigns.product_id.
  """

  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]
  alias CampaignsApi.Products

  @spec init(keyword()) :: keyword()
  def init(opts), do: opts

  @spec call(Plug.Conn.t(), keyword()) :: Plug.Conn.t()
  def call(conn, _opts) do
    product_id = conn.assigns.product_id

    {:ok, product} = Products.get_or_create_product(product_id)

    if Products.product_active?(product) do
      assign(conn, :product, product)
    else
      forbidden(conn)
    end
  end

  defp forbidden(conn) do
    conn
    |> put_status(:forbidden)
    |> json(%{error: "product access denied"})
    |> halt()
  end
end
