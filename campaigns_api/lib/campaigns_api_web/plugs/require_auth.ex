defmodule CampaignsApiWeb.Plugs.RequireAuth do
  @moduledoc """
  Plug for JWT authentication.

  Extracts and validates JWT tokens from the Authorization header,
  decodes the token without signature verification (mock implementation),
  and assigns the tenant_id to the connection.

  Returns 401 Unauthorized if authentication fails.
  """

  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  @spec init(keyword()) :: keyword()
  def init(opts), do: opts

  @spec call(Plug.Conn.t(), keyword()) :: Plug.Conn.t()
  def call(conn, _opts) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] ->
        case decode_jwt(token) do
          {:ok, %{"tenant_id" => tenant_id}} ->
            assign(conn, :tenant_id, tenant_id)
          _ ->
            unauthorized(conn)
        end
      _ ->
        unauthorized(conn)
    end
  end

  @spec decode_jwt(binary()) :: {:ok, %{binary() => term()}} | {:error, :invalid_token}
  defp decode_jwt(token) do
    # Mock implementation - decode without verification
    # Uses Joken to parse JWT structure
    case Joken.peek_claims(token) do
      {:ok, claims} -> {:ok, claims}
      {:error, _} -> {:error, :invalid_token}
    end
  rescue
    _ -> {:error, :invalid_token}
  end

  @spec unauthorized(Plug.Conn.t()) :: Plug.Conn.t()
  defp unauthorized(conn) do
    conn
    |> put_status(:unauthorized)
    |> json(%{error: "Unauthorized"})
    |> halt()
  end
end
