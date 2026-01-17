defmodule CampaignsApi.AuthHelper do
  @moduledoc """
  Helper functions for generating valid JWT tokens in tests.
  """

  @doc """
  Generates a valid JWT token for testing with the given tenant.

  ## Parameters
    - tenant: The tenant identifier to include in the token (default: "tenant-abc123")
    - extra_claims: Additional claims to include in the token (default: %{})

  ## Returns
    A valid JWT token string signed with the test secret
  """
  def generate_test_token(tenant \\ "tenant-abc123", extra_claims \\ %{}) do
    secret = Application.get_env(:campaigns_api, :jwt_secret, "test-secret-key")
    signer = Joken.Signer.create("HS256", secret)

    current_time = System.system_time(:second)

    claims =
      %{
        "tenant" => tenant,
        "iat" => current_time,
        "exp" => current_time + 3600,
        "sub" => "test-user",
        "iss" => "test-issuer"
      }
      |> Map.merge(extra_claims)

    {:ok, token, _claims} = Joken.encode_and_sign(claims, signer)
    token
  end

  @doc """
  Puts a valid authorization header with a JWT token in the connection.

  ## Parameters
    - conn: The connection struct
    - tenant: The tenant identifier to include in the token (default: "tenant-abc123")

  ## Returns
    The updated connection with the Authorization header
  """
  def put_auth_header(conn, tenant \\ "tenant-abc123") do
    token = generate_test_token(tenant)
    Plug.Conn.put_req_header(conn, "authorization", "Bearer #{token}")
  end
end
