<!-- source: https://docs.nats.io/reference/config/jetstream/limits/batch.md · fetched 2026-08-31 · section: batch -->
# batch

Available since NATS Server `2.12`

Requires Restart

Ceilings on atomic batch publishing.

## Properties

| Name                                                                                             | Description                                                  | Type       | Default | Reloadable |
| ------------------------------------------------------------------------------------------------ | ------------------------------------------------------------ | ---------- | ------- | ---------- |
| [`max_msgs`](/reference/config/jetstream/limits/batch/max_msgs.md)                               | Messages allowed in a single batch.                          | `integer`  | `1000`  | No         |
| [`max_inflight_total`](/reference/config/jetstream/limits/batch/max_inflight_total.md)           | Batches allowed in flight across the server.                 | `integer`  | `1000`  | No         |
| [`max_inflight_per_stream`](/reference/config/jetstream/limits/batch/max_inflight_per_stream.md) | Batches allowed in flight for one stream.                    | `integer`  | `50`    | No         |
| [`timeout`](/reference/config/jetstream/limits/batch/timeout.md)                                 | How long an incomplete batch is held before it is discarded. | `duration` | `10s`   | No         |
