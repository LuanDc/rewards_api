# CampaignsApi

## RabbitMQ for challenge ingestion

Start RabbitMQ locally with Docker CLI:

```bash
docker run -d \
  --name campaigns-rabbitmq \
  -p 5672:5672 \
  -p 15672:15672 \
  rabbitmq:3.13-management
```

Management UI: http://localhost:15672 (guest / guest)

Optional env vars:

```bash
export RABBITMQ_URL=amqp://guest:guest@localhost:5672
export RABBITMQ_ENABLED=true
```

The seed script publishes challenge messages to RabbitMQ and waits for Broadway consumer persistence:

```bash
mix run priv/repo/seeds.exs
```

## Test coverage

Generate coverage report:

```bash
mix coveralls
```

Generate HTML coverage report:

```bash
mix coveralls.html
```

To start your Phoenix server:

  * Run `mix setup` to install and setup dependencies
  * Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

  * Official website: https://www.phoenixframework.org/
  * Guides: https://hexdocs.pm/phoenix/overview.html
  * Docs: https://hexdocs.pm/phoenix
  * Forum: https://elixirforum.com/c/phoenix-forum
  * Source: https://github.com/phoenixframework/phoenix
