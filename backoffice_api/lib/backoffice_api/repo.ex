defmodule BackofficeApi.Repo do
  use Ecto.Repo,
    otp_app: :backoffice_api,
    adapter: Ecto.Adapters.Postgres
end
