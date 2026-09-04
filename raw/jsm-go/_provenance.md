<!-- source: https://github.com/nats-io/jsm.go at tag v0.4.1, schemas/jetstream/api/v1/{stream,consumer}_configuration.json (fetched 2026-09-03) and schemas/micro/v1/{ping,info,stats}_response.json (fetched 2026-09-04), from raw.githubusercontent.com -->
# raw/jsm-go — the JetStream API and NATS Micro JSON schemas at jsm.go v0.4.1

Five files, verbatim. Apache-2.0.

**JetStream configuration** (fetched 2026-09-03, read for phase E step 2,
`wiki/reference/stream-and-consumer-config.md`): `stream_configuration-v0.4.1.json` (38 properties) and
`consumer_configuration-v0.4.1.json` (34 properties). These are the schemas the docs' generated reference pages
are rendered from; the consumer page never expands the config object (docs issue #4), so the consumer field
descriptions and defaults are readable only here.

**NATS Micro responses** (fetched 2026-09-04, read for phase F step 6, `wiki/concepts/services-framework.md`):
`micro-ping_response-v0.4.1.json`, `micro-info_response-v0.4.1.json`, `micro-stats_response-v0.4.1.json` —
the `io.nats.micro.v1.*_response` schemas. The docs render these three at `reference/services/`, but the
renderer collapsed the `metadata` `oneOf` and the `endpoints` array's item schema, so the per-endpoint fields
(`name`, `subject`, `queue_group`, `metadata` in info; plus `num_requests`, `num_errors`, `last_error`,
`processing_time`, `average_processing_time`, `data` in stats) and the `required` lists inside them are
readable in public only here and in `raw/adr/ADR-32.md`.
