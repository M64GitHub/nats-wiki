<!-- source: https://docs.nats.io/reference/config/gateway/gateways/tls/insecure.md · fetched 2026-08-31 · section: tls -->
# insecure

Hot Reloadable

Applies to outbound gateway connections established after the reload.

Skip certificate verification. This only applies to outgoing connections, NOT incoming client connections. **not recommended.**

## Types

| Type      | Description | Choices         |
| --------- | ----------- | --------------- |
| `boolean` | -           | `true`, `false` |
