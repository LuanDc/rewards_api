defmodule CampaignsApiWeb.Plugs.AssignProductTest do
  use CampaignsApiWeb.ConnCase, async: true

  alias CampaignsApi.Products
  alias CampaignsApi.Products.Product
  alias CampaignsApiWeb.Plugs.AssignProduct

  describe "AssignProduct plug" do
    test "creates new product on first access (JIT provisioning)", %{conn: conn} do
      product_id = "new-product-#{System.unique_integer([:positive])}"

      assert Products.get_product(product_id) == nil

      conn =
        conn
        |> assign(:product_id, product_id)
        |> AssignProduct.call(%{})

      assert %Product{} = conn.assigns.product
      assert conn.assigns.product.id == product_id
      assert conn.assigns.product.name == product_id
      assert conn.assigns.product.status == :active
      refute conn.halted

      assert %Product{} = Products.get_product(product_id)
    end

    test "loads existing product on subsequent access", %{conn: conn} do
      existing_product = insert(:product, name: "Existing Corp")

      conn =
        conn
        |> assign(:product_id, existing_product.id)
        |> AssignProduct.call(%{})

      assert conn.assigns.product.id == existing_product.id
      assert conn.assigns.product.name == "Existing Corp"
      assert conn.assigns.product.status == :active
      refute conn.halted
    end

    test "returns 403 when product status is deleted", %{conn: conn} do
      deleted_product = insert(:deleted_product)

      conn =
        conn
        |> assign(:product_id, deleted_product.id)
        |> AssignProduct.call(%{})

      assert conn.status == 403
      assert conn.halted
      assert json_response(conn, 403) == %{"error" => "product access denied"}
    end

    test "returns 403 when product status is suspended", %{conn: conn} do
      suspended_product = insert(:suspended_product)

      conn =
        conn
        |> assign(:product_id, suspended_product.id)
        |> AssignProduct.call(%{})

      assert conn.status == 403
      assert conn.halted
      assert json_response(conn, 403) == %{"error" => "product access denied"}
    end

    test "assigns active product to conn", %{conn: conn} do
      product = insert(:product, status: :active)

      conn =
        conn
        |> assign(:product_id, product.id)
        |> AssignProduct.call(%{})

      assert conn.assigns.product.id == product.id
      assert conn.assigns.product.status == :active
      refute conn.halted
    end
  end
end
