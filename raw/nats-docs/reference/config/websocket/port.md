<!-- source: https://docs.nats.io/reference/config/websocket/port.md · fetched 2026-08-31 · section: port -->
# port

Requires Restart

Port to accept WebSocket client connections on. There is no default: the listener is only started once a port is set, here or via `listen`.

TLS is required unless `no_tls` is `true`.

## Types

| Type      | Description | Choices |
| --------- | ----------- | ------- |
| `integer` | -           | -       |
