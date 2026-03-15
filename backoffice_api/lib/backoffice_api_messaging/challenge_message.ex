defmodule BackofficeApiMessaging.ChallengeMessage do
  @moduledoc """
  Outgoing challenge message contract.
  """

  @type payload :: %{
          schema_version: integer(),
          external_id: String.t(),
          name: String.t(),
          description: String.t() | nil,
          metadata: map()
        }

  @spec encode(payload()) :: {:ok, binary()} | {:error, Jason.EncodeError.t()}
  def encode(payload) when is_map(payload) do
    Jason.encode(payload)
  end
end
