<!-- source: https://docs.nats.io/reference/config/cluster/tls/timeout.md · fetched 2026-08-31 · section: timeout -->
# timeout

Hot Reloadable

Read at handshake time, so it applies to every route connection established after the reload. Contrast with gateway.tls.timeout, which hard-fails the reload.

TLS handshake timeout.

## Types

| Type       | Description                                                    | Choices |
| ---------- | -------------------------------------------------------------- | ------- |
| `duration` | Duration as a string with units such as 100ms, 10s, 5m, or 2h. | -       |
