<!-- source: https://docs.nats.io/reference/config/leafnodes/tls/handshake_first.md · fetched 2026-08-31 · section: handshake_first -->
# handshake\_first

Aliases:

<!-- -->

`first`, `immediate`

Hot Reloadable

Accept side only; applies to newly accepted connections.

Force the leafnode connection to use a TLS-first handshake prior to the remote sending the `INFO` protocol message.

Note, this option must be set to true on both the remote server accepting the leafnode connections as well as the leafnode itself.

## Types

| Type      | Description | Choices         |
| --------- | ----------- | --------------- |
| `boolean` | -           | `true`, `false` |
