defmodule CampaignsApiWeb.Plugs.RequestLogger do
  @moduledoc """
  Custom request logger that replaces Phoenix default logging.

  Logs only after OpenTelemetry span is created, ensuring trace_id and span_id
  are always included for distributed tracing correlation.
  """
  require Logger

  @behaviour Plug

  def init(opts), do: opts

  def call(conn, _opts) do
    start_time = System.monotonic_time()

    # Register callback to log AFTER OpenTelemetry span is created
    # This ensures trace_id and span_id are always present
    Plug.Conn.register_before_send(conn, fn conn ->
      duration = System.monotonic_time() - start_time
      duration_ms = System.convert_time_unit(duration, :native, :millisecond)

      # Get OpenTelemetry metadata (always available at this point)
      trace_id = Logger.metadata()[:trace_id]
      span_id = Logger.metadata()[:span_id]
      request_id = Logger.metadata()[:request_id]

      # Log with full trace correlation metadata
      Logger.info(
        "#{conn.method} #{conn.request_path} - Sent #{conn.status} in #{duration_ms}ms",
        request_id: request_id,
        trace_id: trace_id,
        span_id: span_id
      )

      conn
    end)

    conn
  end
end
