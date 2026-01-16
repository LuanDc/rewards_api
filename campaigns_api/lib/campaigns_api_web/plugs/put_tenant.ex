defmodule CampaignsApiWeb.Plugs.PutTenant do
  @moduledoc """
  Plug to extract tenant from authorization token and add it to conn assigns.

  This plug expects an authorization token in the format:
  Authorization: Bearer <tenant_id>

  The tenant is then available in conn.assigns.tenant
  """

  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> tenant] when byte_size(tenant) > 0 ->
        assign(conn, :tenant, tenant)

      _ ->
        conn
        |> put_status(:unauthorized)
        |> put_view(json: CampaignsApiWeb.ErrorJSON)
        |> render(:"401")
        |> halt()
    end
  end
end
