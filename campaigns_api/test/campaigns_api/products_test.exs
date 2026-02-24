defmodule CampaignsApi.ProductsTest do
  use CampaignsApi.DataCase, async: true
  use ExUnitProperties

  alias CampaignsApi.Products

  describe "get_product/1" do
    test "returns product when it exists" do
      product = insert(:product)
      result = Products.get_product(product.id)

      assert result.id == product.id
      assert result.name == product.name
    end

    test "returns nil when product does not exist" do
      result = Products.get_product("non-existent-product")
      assert result == nil
    end
  end

  describe "create_product/2" do
    test "creates product with provided name" do
      {:ok, product} = Products.create_product("product-123", %{name: "Acme Corp"})

      assert product.id == "product-123"
      assert product.name == "Acme Corp"
      assert product.status == :active
      assert product.deleted_at == nil
    end

    test "creates product with product_id as name when name not provided" do
      {:ok, product} = Products.create_product("product-456")

      assert product.id == "product-456"
      assert product.name == "product-456"
      assert product.status == :active
    end

    test "creates product with default status active" do
      {:ok, product} = Products.create_product("product-789", %{name: "Test"})

      assert product.status == :active
    end

    test "returns error for invalid product_id" do
      {:error, changeset} = Products.create_product("", %{name: "Test"})

      assert changeset.valid? == false
      assert "can't be blank" in errors_on(changeset).id
    end

    test "returns error for invalid name" do
      {:error, changeset} = Products.create_product("product-999", %{name: ""})

      assert changeset.valid? == false
      assert "can't be blank" in errors_on(changeset).name
    end
  end

  describe "get_or_create_product/1" do
    test "returns existing product when it exists" do
      existing_product = insert(:product)
      {:ok, product} = Products.get_or_create_product(existing_product.id)

      assert product.id == existing_product.id
      assert product.name == existing_product.name
      assert product.inserted_at == existing_product.inserted_at
    end

    test "creates new product when it does not exist" do
      assert Products.get_product("new-product") == nil
      {:ok, product} = Products.get_or_create_product("new-product")

      assert product.id == "new-product"
      assert product.name == "new-product"
      assert product.status == :active
    end

    test "multiple calls with same product_id do not create duplicates" do
      {:ok, product1} = Products.get_or_create_product("idempotent-product")
      {:ok, product2} = Products.get_or_create_product("idempotent-product")

      assert product1.id == product2.id
      assert product1.inserted_at == product2.inserted_at
    end
  end

  describe "product_active?/1" do
    test "returns true for active product" do
      product = build(:product, status: :active)
      assert Products.product_active?(product) == true
    end

    test "returns false for suspended product" do
      product = build(:suspended_product)
      assert Products.product_active?(product) == false
    end

    test "returns false for deleted product" do
      product = build(:deleted_product)
      assert Products.product_active?(product) == false
    end
  end

  describe "Properties: product Creation and Status Validation (Business Invariants)" do
    @tag :property
    property "product creation with new product_id creates active product" do
      check all(
              product_id <- string(:alphanumeric, min_length: 5, max_length: 30),
              max_runs: 50
            ) do
        product_id = "product-#{product_id}"

        {:ok, product} = Products.get_or_create_product(product_id)

        assert product.id == product_id
        assert product.status == :active
        assert product.name == product_id
        assert product.inserted_at != nil
        assert product.updated_at != nil
      end
    end

    @tag :property
    property "multiple requests with same product_id do not create duplicates" do
      check all(
              product_id <- string(:alphanumeric, min_length: 5, max_length: 30),
              request_count <- integer(2..5),
              max_runs: 50
            ) do
        product_id = "product-#{product_id}"

        results =
          Enum.map(1..request_count, fn _ ->
            Products.get_or_create_product(product_id)
          end)

        assert Enum.all?(results, fn result -> match?({:ok, _}, result) end)

        products = Enum.map(results, fn {:ok, product} -> product end)
        assert Enum.all?(products, fn p -> p.id == product_id end)

        first_inserted_at = hd(products).inserted_at
        assert Enum.all?(products, fn p -> p.inserted_at == first_inserted_at end)
      end
    end

    @tag :property
    property "product status validation - non-active products denied access" do
      check all(
              product_id <- string(:alphanumeric, min_length: 5, max_length: 30),
              non_active_status <- member_of([:deleted, :suspended]),
              max_runs: 50
            ) do
        product_id = "product-#{product_id}"

        {:ok, product} = Products.create_product(product_id, %{status: non_active_status})

        assert Products.product_active?(product) == false

        retrieved_product = Products.get_product(product_id)
        assert retrieved_product != nil
        assert retrieved_product.status == non_active_status
        assert Products.product_active?(retrieved_product) == false
      end
    end
  end
end
