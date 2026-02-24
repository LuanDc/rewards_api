import Config

config :campaigns_api, CampaignsApi.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "postgres_db",
  database: "campaigns_api_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

config :campaigns_api, CampaignsApiWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "ptfvgi1HtzoyuVe/7/vocd7tvizOaUnYD5CeY1w3Dfb9uZdBvEkDOsRplDnUMwBt",
  server: false

config :campaigns_api, CampaignsApi.Mailer, adapter: Swoosh.Adapters.Test

config :campaigns_api, CampaignsApiMessaging,
  enabled: false,
  rabbitmq_url: "amqp://guest:guest@localhost:5672"

config :swoosh, :api_client, false

config :logger, level: :warning

config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  enable_expensive_runtime_checks: true
