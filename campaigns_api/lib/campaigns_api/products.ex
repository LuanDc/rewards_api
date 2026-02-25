defmodule CampaignsApi.Products do
  @moduledoc """
  The products context manages product lifecycle, status checks, and JIT provisioning.
  """

  alias CampaignsApi.Products.Product
  alias CampaignsApi.Repo

  @type product_id :: String.t()
  @type attrs :: map()

  @doc """
  Gets a product by ID.
  """
  @spec get_product(product_id()) :: Product.t() | nil
  def get_product(product_id) do
    Repo.get(Product, product_id)
  end

  @doc """
  Creates a new product with JIT provisioning.
  """
  @spec create_product(product_id(), attrs()) :: {:ok, Product.t()} | {:error, Ecto.Changeset.t()}
  def create_product(product_id, attrs \\ %{}) do
    default_attrs = %{id: product_id, name: product_id}
    merged_attrs = Map.merge(default_attrs, attrs)

    %Product{}
    |> Product.changeset(merged_attrs)
    |> Repo.insert()
  end

  @doc """
  Gets an existing product or creates a new one (JIT provisioning).
  """
  @spec get_or_create_product(product_id()) :: {:ok, Product.t()}
  def get_or_create_product(product_id) do
    case get_product(product_id) do
      nil -> create_product(product_id)
      product -> {:ok, product}
    end
  end

  @doc """
  Checks if a product can access the API.
  """
  @spec product_active?(Product.t()) :: boolean()
  def product_active?(%Product{status: :active}), do: true
  def product_active?(_), do: false
end
