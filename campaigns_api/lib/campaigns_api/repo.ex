defmodule CampaignsApi.Repo do
  use Ecto.Repo,
    otp_app: :campaigns_api,
    adapter: Ecto.Adapters.Postgres
end
