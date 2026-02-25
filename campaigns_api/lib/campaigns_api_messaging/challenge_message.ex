defmodule CampaignsApiMessaging.ChallengeMessage do
  @moduledoc """
  Challenge message contract and decoding helpers.
  """

  @required_fields ~w(schema_version external_id name)

  @type payload :: %{
          schema_version: integer(),
          external_id: String.t(),
          name: String.t(),
          description: String.t() | nil,
          metadata: map()
        }

  @spec decode(binary()) :: {:ok, payload()} | {:error, term()}
  def decode(raw_payload) when is_binary(raw_payload) do
    with {:ok, payload} <- Jason.decode(raw_payload),
         :ok <- validate_required_fields(payload),
         :ok <- validate_schema_version(payload["schema_version"]),
         :ok <- validate_types(payload) do
      {:ok,
       %{
         schema_version: payload["schema_version"],
         external_id: payload["external_id"],
         name: payload["name"],
         description: payload["description"],
         metadata: payload["metadata"] || %{}
       }}
    else
      {:error, reason} -> {:error, {:invalid_payload, reason}}
    end
  end

  @spec encode(payload()) :: {:ok, binary()} | {:error, Jason.EncodeError.t()}
  def encode(payload) when is_map(payload) do
    Jason.encode(payload)
  end

  @spec validate_required_fields(map()) :: :ok | {:error, {:missing_fields, [String.t()]}}
  defp validate_required_fields(payload) do
    missing_fields = Enum.filter(@required_fields, &(is_nil(payload[&1]) or payload[&1] == ""))

    if missing_fields == [] do
      :ok
    else
      {:error, {:missing_fields, missing_fields}}
    end
  end

  @spec validate_schema_version(term()) :: :ok | {:error, :invalid_schema_version}
  defp validate_schema_version(1), do: :ok
  defp validate_schema_version(_), do: {:error, :invalid_schema_version}

  @spec validate_types(map()) ::
          :ok
          | {:error, :invalid_description | :invalid_external_id | :invalid_metadata | :invalid_name}
  defp validate_types(payload) do
    cond do
      not is_binary(payload["external_id"]) ->
        {:error, :invalid_external_id}

      not is_binary(payload["name"]) ->
        {:error, :invalid_name}

      not is_nil(payload["description"]) and not is_binary(payload["description"]) ->
        {:error, :invalid_description}

      not is_nil(payload["metadata"]) and not is_map(payload["metadata"]) ->
        {:error, :invalid_metadata}

      true ->
        :ok
    end
  end
end
