<!-- source: https://docs.nats.io/reference/config/websocket/handshake_timeout.md · fetched 2026-08-31 · section: handshake_timeout -->
# handshake\_timeout

Requires Restart

This is the total time allowed for the server to read the client request and write the response back to the client. This includes the time needed for the TLS handshake.

## Types

| Type       | Description                                                    | Choices |
| ---------- | -------------------------------------------------------------- | ------- |
| `duration` | Duration as a string with units such as 100ms, 10s, 5m, or 2h. | -       |
