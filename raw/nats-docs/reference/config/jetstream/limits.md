<!-- source: https://docs.nats.io/reference/config/jetstream/limits.md · fetched 2026-08-31 · section: limits -->
# limits

Requires Restart

Default cross-account JetStream limits.

## Properties

| Name                                                                           | Description                                                                                           | Type       | Default | Reloadable |
| ------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------- | ---------- | ------- | ---------- |
| [`batch`](/reference/config/jetstream/limits/batch/.md)                        | Ceilings on atomic batch publishing.                                                                  | `object`   | -       | No         |
| [`max_ack_pending`](/reference/config/jetstream/limits/max_ack_pending.md)     | Defines the maximum number of in-flight messages allowed to be configured on consumers.               | `integer`  | -       | No         |
| [`max_ha_assets`](/reference/config/jetstream/limits/max_ha_assets.md)         | The maximum number of JetStream assets that can exist at any given time having more than one replica. | `integer`  | -       | No         |
| [`max_request_batch`](/reference/config/jetstream/limits/max_request_batch.md) | The maximum request batch size allowed to be configured on pull consumers.                            | `integer`  | -       | No         |
| [`duplicate_window`](/reference/config/jetstream/limits/duplicate_window.md)   | The maximum duplication window period allowed to be configured on a stream.                           | `duration` | -       | No         |
