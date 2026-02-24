FROM elixir:1.18-otp-27

# Install hex and rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Install system dependencies needed for Elixir/Phoenix dev
RUN apt-get update && apt-get install -y \
    git \
    curl \
    inotify-tools \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace
