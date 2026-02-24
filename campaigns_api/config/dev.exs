import Config

config :campaigns_api, CampaignsApi.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "postgres_db",
  database: "campaigns_api_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :campaigns_api, CampaignsApiWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "KTHOP10OcG488ilVOuG6LmCCuSpPSNnp2DgHX7uWKjagA5SZTdmJV5XMcNeLrS19",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:campaigns_api, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:campaigns_api, ~w(--watch)]}
  ]

config :campaigns_api, CampaignsApiWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/(?!uploads/).*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/campaigns_api_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

config :campaigns_api, dev_routes: true

config :logger, :console, format: "[$level] $message\n"

config :phoenix, :stacktrace_depth, 20

config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  debug_heex_annotations: true,
  enable_expensive_runtime_checks: true

config :swoosh, :api_client, false
