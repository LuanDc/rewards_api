defmodule CampaignsApi.Auth.JwksStrategy do
  @moduledoc """
  Strategy for fetching JWT signing keys from Keycloak's JWKS endpoint.

  This module implements the JokenJwks.DefaultStrategyTemplate to automatically
  fetch and cache public keys from Keycloak for JWT verification.
  """

  use JokenJwks.DefaultStrategyTemplate

  def init_opts(opts) do
    jwks_url = Application.get_env(:campaigns_api, :keycloak_jwks_url)

    if jwks_url do
      Keyword.merge(opts, jwks_url: jwks_url)
    else
      opts
    end
  end
end
