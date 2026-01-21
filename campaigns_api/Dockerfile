# Dockerfile for development with hot reload
FROM elixir:1.18-slim

# Install build dependencies
RUN apt-get update -y && \
    apt-get install -y build-essential git inotify-tools && \
    apt-get clean && rm -f /var/lib/apt/lists/*_*

WORKDIR /app

# Install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Set environment
ENV MIX_ENV=dev

# Copy mix files first for better caching
COPY mix.exs mix.lock ./
RUN mix deps.get

# Copy config files
COPY config config

# Compile dependencies
RUN mix deps.compile

# Copy source code
COPY lib lib
COPY priv priv

# Compile application
RUN mix compile

# Expose port
EXPOSE 4000

# Set entrypoint
CMD ["mix", "phx.server"]
