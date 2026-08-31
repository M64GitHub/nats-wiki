<!-- source: https://docs.nats.io/reference/config/cluster/write_timeout.md · fetched 2026-08-31 · section: write_timeout -->
# write\_timeout

Available since NATS Server `2.12`

Hot Reloadable

What to do when a route misses its `write_deadline`.

## Types

| Type     | Description | Choices                     |
| -------- | ----------- | --------------------------- |
| `string` | -           | `default`, `close`, `retry` |
