# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :campaigns_api,
  ecto_repos: [CampaignsApi.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :campaigns_api, CampaignsApiWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: CampaignsApiWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: CampaignsApi.PubSub,
  live_view: [signing_salt: "KdWabocz"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :trace_id, :span_id]

# Disable Phoenix default request logging - using custom logger instead
config :phoenix, :logger, false

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Keycloak JWT configuration
# These values will be overridden in environment-specific config files
config :campaigns_api,
  jwt_secret: nil,
  keycloak_jwks_url: nil

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
