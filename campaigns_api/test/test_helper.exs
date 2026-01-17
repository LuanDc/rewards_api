ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(CampaignsApi.Repo, :manual)

# Setup Hammox for mocking
Hammox.protect(CampaignsApi.Factory)
