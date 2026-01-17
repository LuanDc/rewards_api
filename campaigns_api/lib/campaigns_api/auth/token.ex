defmodule CampaignsApi.Auth.Token do
  @moduledoc """
  Module for handling JWT token validation and decoding from Keycloak.

  This module uses Joken to verify and decode JWT tokens issued by Keycloak,
  automatically fetching public keys from the Keycloak JWKS endpoint.
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

  This function automatically fetches the public key from Keycloak's JWKS endpoint
  based on the key ID (kid) in the token header when JWKS URL is configured.
  Otherwise, it falls back to using the configured JWT secret.

  ## Parameters

    - token: The JWT token string to verify

  ## Returns

    - {:ok, claims} if the token is valid
    - {:error, reason} if the token is invalid
  """
  def verify_token(token) do
    jwks_url = Application.get_env(:campaigns_api, :keycloak_jwks_url)

    if jwks_url do
      # Use JWKS to verify with automatic key fetching
      # Pass nil as signer because JokenJwks hook will provide it
      case verify_and_validate(token, nil, %{}) do
        {:ok, claims} -> {:ok, claims}
        {:error, reason} -> {:error, reason}
      end
    else
      # Fallback to secret-based verification for tests
      verify_token_with_secret(token)
    end
  end

  defp verify_token_with_secret(token) do
    secret = Application.get_env(:campaigns_api, :jwt_secret, "default-secret-key")
    signer = Joken.Signer.create("HS256", secret)

    case verify_and_validate(token, signer) do
      {:ok, claims} -> {:ok, claims}
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

  defp get_current_time, do: System.system_time(:second)
end
