<!-- source: https://docs.nats.io/reference/config/mqtt/tls/handshake_first.md · fetched 2026-08-31 · section: handshake_first -->
# handshake\_first

Aliases:

<!-- -->

`first`, `immediate`

Hot Reloadable

Send the TLS handshake before the `INFO` protocol message rather than after. A duration string instead of `true` waits that long for a client that may not support it before falling back.

## Types

| Type      | Description | Choices         |
| --------- | ----------- | --------------- |
| `boolean` |             | `true`, `false` |
| `string`  |             | -               |
