<!-- source: https://docs.nats.io/reference/config/port.md · fetched 2026-08-31 · section: port -->
# port

Requires Restart

Leaving `port: -1` across reloads is fine — the running port is restored. Any other change fails.

Port for client connections. Use `-1` for a random available port.

## Types

| Type      | Description | Choices |
| --------- | ----------- | ------- |
| `integer` | -           | -       |
