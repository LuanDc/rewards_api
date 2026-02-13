ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(CampaignsApi.Repo, :manual)

# Import ExMachina for test factories
{:ok, _} = Application.ensure_all_started(:ex_machina)
