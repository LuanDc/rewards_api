import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/campaigns_api start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :campaigns_api, CampaignsApiWeb.Endpoint, server: true
end

# Development runtime configuration (for Docker)
if config_env() == :dev do
  # Database configuration from environment variables (for Docker)
  if db_hostname = System.get_env("DB_HOSTNAME") do
    config :campaigns_api, CampaignsApi.Repo,
      username: System.get_env("DB_USERNAME") || "postgres",
      password: System.get_env("DB_PASSWORD") || "postgres",
      hostname: db_hostname,
      database: System.get_env("DB_DATABASE") || "campaigns_api_dev",
      stacktrace: true,
      show_sensitive_data_on_connection_error: true,
      pool_size: 10
  end

  # OpenTelemetry configuration from environment variables (for Docker)
  if otel_endpoint = System.get_env("OTEL_EXPORTER_OTLP_ENDPOINT") do
    config :opentelemetry_exporter,
      otlp_protocol: :grpc,
      otlp_endpoint: otel_endpoint,
      otlp_headers: [],
      otlp_compression: :gzip
  end

  # Keycloak JWKS URL from environment variables (for Docker)
  if jwks_url = System.get_env("KEYCLOAK_JWKS_URL") do
    config :campaigns_api,
      keycloak_jwks_url: jwks_url
  end
end

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :campaigns_api, CampaignsApi.Repo,
    # ssl: true,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :campaigns_api, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :campaigns_api, CampaignsApiWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/bandit/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :campaigns_api, CampaignsApiWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :campaigns_api, CampaignsApiWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # Keycloak JWT configuration for production
  # KEYCLOAK_JWKS_URL should point to: http://keycloak:8080/realms/{realm-name}/protocol/openid-connect/certs
  keycloak_jwks_url =
    System.get_env("KEYCLOAK_JWKS_URL") ||
      raise """
      environment variable KEYCLOAK_JWKS_URL is missing.
      For example: http://keycloak:8080/realms/my-realm/protocol/openid-connect/certs
      """

  config :campaigns_api,
    jwt_secret: nil,
    keycloak_jwks_url: keycloak_jwks_url

  # PromEx configuration for production
  config :campaigns_api, CampaignsApi.PromEx,
    disabled: false,
    manual_metrics_start_delay: :no_delay,
    drop_metrics_groups: [],
    grafana: [
      host: System.get_env("GRAFANA_HOST") || "http://grafana:3000",
      auth_token: System.get_env("GRAFANA_TOKEN"),
      upload_dashboards_on_start: false,
      folder_name: "CampaignsAPI",
      annotate_app_lifecycle: true
    ],
    metrics_server: :disabled

  # OpenTelemetry configuration for production
  config :opentelemetry,
    resource: [
      service: [
        name: "campaigns_api",
        namespace: "rewards_api"
      ]
    ],
    span_processor: :batch,
    traces_exporter: :otlp

  # Batch processor configuration - send traces every 60 seconds or when batch is full
  config :opentelemetry, :processors,
    otel_batch_processor: %{
      exporter: {:opentelemetry_exporter, :otlp_exporter},
      # Export every 60 seconds (60000ms)
      scheduled_delay_ms: 60_000,
      # Max batch size before forcing export
      max_queue_size: 2048,
      max_export_batch_size: 512
    }

  config :opentelemetry_exporter,
    otlp_protocol: :grpc,
    otlp_endpoint: System.get_env("OTEL_EXPORTER_OTLP_ENDPOINT") || "http://otel-collector:4317",
    otlp_headers: [],
    otlp_compression: :gzip
end
