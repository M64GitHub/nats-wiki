<!-- source: https://docs.nats.io/reference/config/mqtt/tls/insecure.md · fetched 2026-08-31 · section: insecure -->
# insecure

Hot Reloadable

Meaningless for the inbound MQTT listener; reloads without error but changes nothing observable.

Skip certificate verification. This only applies to outgoing connections, NOT incoming client connections. **not recommended.**

## Types

| Type      | Description | Choices         |
| --------- | ----------- | --------------- |
| `boolean` | -           | `true`, `false` |
