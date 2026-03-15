defmodule BackofficeApi.ChallengeManagement.Challenge do
  @moduledoc """
  Challenge entity managed by backoffice.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @derive {Jason.Encoder,
           only: [:id, :external_id, :name, :description, :metadata, :inserted_at, :updated_at]}

  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          external_id: String.t(),
          name: String.t(),
          description: String.t() | nil,
          metadata: map() | nil,
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "challenges" do
    field(:external_id, :string)
    field(:name, :string)
    field(:description, :string)
    field(:metadata, :map)

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t() | %__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(challenge, attrs) do
    challenge
    |> cast(attrs, [:external_id, :name, :description, :metadata])
    |> validate_required([:external_id, :name])
    |> validate_length(:name, min: 3)
    |> validate_length(:external_id, min: 3)
    |> unique_constraint(:external_id)
  end
end
