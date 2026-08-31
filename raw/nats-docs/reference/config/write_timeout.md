<!-- source: https://docs.nats.io/reference/config/write_timeout.md · fetched 2026-08-31 · section: write_timeout -->
# write\_timeout

Available since NATS Server `2.12`

Requires Restart

What the server does when a connection misses its `write_deadline`: `close` drops it, `retry` keeps trying, `default` uses the built-in behaviour.

## Types

| Type     | Description | Choices                     |
| -------- | ----------- | --------------------------- |
| `string` | -           | `default`, `close`, `retry` |
