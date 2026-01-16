ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(CampaignsApi.Repo, :manual)

# Import factory functions
import CampaignsApi.Factory

# Setup Hammox for mocking
Hammox.protect(CampaignsApi.Factory)
