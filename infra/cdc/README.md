# CDC Outbox -> RabbitMQ

This folder configures Debezium Server to read `campaigns_api.public.outbox_events`
and publish the payload to RabbitMQ.

## Routing strategy

- Exchange: `campaigns_api.domain_events`
- Routing key: `event_type` (for example `campaign.created`)
- Event payload: `payload` column from outbox row

The scheduler consumer is already configured to bind these routing keys.

## Bring up CDC (after Docker daemon is running)

1. Start base stack:
   - `docker compose -f docker-compose.dev.yml up -d`
2. Start CDC service:
   - `docker compose -f docker-compose.dev.yml -f infra/cdc/docker-compose.cdc.yml up -d debezium`

## Notes

- Debezium reads only `public.outbox_events`.
- If the replication slot already exists with stale state, drop/recreate slot or reset Debezium offsets volume.
