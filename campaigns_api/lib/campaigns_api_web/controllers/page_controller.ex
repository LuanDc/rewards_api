defmodule CampaignsApiWeb.PageController do
  use CampaignsApiWeb, :controller

  def home(conn, _params) do
    render(conn, :home, layout: false)
  end
end
