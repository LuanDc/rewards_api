defmodule CampaignsApi.CampaignManagement.Campaign do
  @moduledoc """
  Campaign schema representing a reward campaign belonging to a product.

  Campaigns support flexible date management with optional start_time and end_time.
  Status can be either `:active` or `:paused`.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          product_id: String.t(),
          name: String.t(),
          description: String.t() | nil,
          start_time: DateTime.t() | nil,
          end_time: DateTime.t() | nil,
          status: :active | :paused,
          product: CampaignsApi.Products.Product.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :string
  @derive {Jason.Encoder,
           only: [
             :id,
             :product_id,
             :name,
             :description,
             :start_time,
             :end_time,
             :status,
             :inserted_at,
             :updated_at
           ]}

  schema "campaigns" do
    field(:name, :string)
    field(:description, :string)
    field(:start_time, :utc_datetime)
    field(:end_time, :utc_datetime)
    field(:status, Ecto.Enum, values: [:active, :paused], default: :active)

    belongs_to(:product, CampaignsApi.Products.Product, type: :string)

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t() | Ecto.Changeset.t() | %__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(campaign, attrs) do
    campaign
    |> cast(attrs, [:product_id, :name, :description, :start_time, :end_time, :status])
    |> validate_required([:product_id, :name])
    |> validate_length(:name, min: 3)
    |> validate_date_order()
    |> foreign_key_constraint(:product_id)
  end

  defp validate_date_order(changeset) do
    start_time = get_field(changeset, :start_time)
    end_time = get_field(changeset, :end_time)

    if start_time && end_time && DateTime.compare(start_time, end_time) != :lt do
      add_error(changeset, :start_time, "must be before end_time")
    else
      changeset
    end
  end
end
