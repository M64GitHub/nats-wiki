<!-- source: https://docs.nats.io/reference/config/leafnodes/remotes/tls/handshake_first.md · fetched 2026-08-31 · section: tls -->
# handshake\_first

Aliases:

<!-- -->

`first`, `immediate`

Hot Reloadable

On 2.11/2.12 the server logs that the value was reloaded while continuing to use the old one.

Force the leafnode connection to use a TLS-first handshake prior to the remote sending the `INFO` protocol message.

Note, this option must be set to true on both the remote server accepting the leafnode connections as well as the leafnode itself.

## Types

| Type      | Description | Choices         |
| --------- | ----------- | --------------- |
| `boolean` | -           | `true`, `false` |
