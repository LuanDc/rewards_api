defmodule CampaignsApiWeb.Plugs.PutTenant do
  @moduledoc """
  Plug to extract tenant from JWT token and add it to conn assigns.

  This plug expects an authorization token in the format:
  Authorization: Bearer <JWT_TOKEN>

  The JWT token is validated using Keycloak's public keys (JWKS) or a configured secret.
  The tenant is extracted from the token claims and made available in conn.assigns.tenant
  """

  import Plug.Conn
  import Phoenix.Controller

  alias CampaignsApi.Auth.Token

  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] when byte_size(token) > 0 ->
        validate_token_and_extract_tenant(conn, token)

      _ ->
        send_unauthorized(conn, "Missing or invalid authorization header")
    end
  end

  defp validate_token_and_extract_tenant(conn, token) do
    with {:ok, claims} <- Token.verify_token(token),
         {:ok, tenant} <- Token.extract_tenant(claims) do
      conn
      |> assign(:tenant, tenant)
      |> assign(:token_claims, claims)
    else
      {:error, :tenant_not_found} ->
        Logger.warning("Token validation failed: tenant not found in claims")
        send_unauthorized(conn, "Tenant information not found in token")

      {:error, :invalid_tenant_format} ->
        Logger.warning("Token validation failed: invalid tenant format")
        send_unauthorized(conn, "Invalid tenant format in token")

      {:error, reason} ->
        Logger.warning("Token validation failed: #{inspect(reason)}")
        send_unauthorized(conn, "Invalid or expired token")
    end
  end

  defp send_unauthorized(conn, message) do
    conn
    |> put_status(:unauthorized)
    |> put_view(json: CampaignsApiWeb.ErrorJSON)
    |> render(:"401", %{message: message})
    |> halt()
  end
end
