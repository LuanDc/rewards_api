import Config

config :campaigns_api,
  ecto_repos: [CampaignsApi.Repo],
  generators: [timestamp_type: :utc_datetime]

config :campaigns_api, CampaignsApiWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: CampaignsApiWeb.ErrorHTML, json: CampaignsApiWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: CampaignsApi.PubSub,
  live_view: [signing_salt: "7lAE+lmH"]

config :campaigns_api, CampaignsApi.Mailer, adapter: Swoosh.Adapters.Local

config :esbuild,
  version: "0.17.11",
  campaigns_api: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :tailwind,
  version: "3.4.3",
  campaigns_api: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

config :campaigns_api, :phoenix_swagger,
  swagger_files: %{
    "priv/static/swagger.json" => [
      router: CampaignsApiWeb.Router,
      endpoint: CampaignsApiWeb.Endpoint,
      swagger_info: &CampaignsApiWeb.SwaggerInfo.swagger_info/0
    ]
  }

config :phoenix_swagger, json_library: Jason

import_config "#{config_env()}.exs"
