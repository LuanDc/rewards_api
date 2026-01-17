defmodule CampaignsApi.Auth.Token do
  @moduledoc """
  Module for handling JWT token validation and decoding from Keycloak.

  This module uses Joken to verify and decode JWT tokens issued by Keycloak,
  extracting tenant information from the token claims.
  """

  use Joken.Config

  @impl true
  def token_config do
    default_claims(skip: [:aud, :iss])
    |> add_claim("exp", nil, &(&1 > get_current_time()))
    |> add_claim("iat", nil, &(&1 <= get_current_time()))
  end

  @doc """
  Verifies and decodes a JWT token.

  ## Parameters

    - token: The JWT token string to verify

  ## Returns

    - {:ok, claims} if the token is valid
    - {:error, reason} if the token is invalid
  """
  def verify_token(token) do
    with {:ok, signer} <- get_signer(),
         {:ok, claims} <- verify_and_validate(token, signer) do
      {:ok, claims}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Extracts the tenant from the token claims.

  The tenant can be located in different claim fields depending on Keycloak configuration:
  - tenant (custom claim)
  - client_id (for service accounts)
  - azp (authorized party)

  ## Parameters

    - claims: The decoded JWT claims map

  ## Returns

    - {:ok, tenant} if tenant is found
    - {:error, :tenant_not_found} if tenant is not present in claims
  """
  def extract_tenant(claims) do
    tenant =
      claims["tenant"] ||
        claims["client_id"] ||
        claims["azp"] ||
        get_in(claims, ["resource_access", "tenant"]) ||
        get_in(claims, ["realm_access", "tenant"])

    case tenant do
      nil -> {:error, :tenant_not_found}
      tenant when is_binary(tenant) -> {:ok, tenant}
      _ -> {:error, :invalid_tenant_format}
    end
  end

  defp get_signer do
    # For testing and development, use a simple HS256 secret
    # For production with JWKS, you would typically:
    # 1. Set up a GenServer to periodically fetch and cache JWKS keys
    # 2. Use JokenJwks with proper configuration
    # For now, we'll keep it simple and only use the secret approach
    secret = Application.get_env(:campaigns_api, :jwt_secret, "default-secret-key")
    {:ok, Joken.Signer.create("HS256", secret)}
  end

  defp get_current_time, do: System.system_time(:second)
end
