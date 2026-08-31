<!-- source: https://docs.nats.io/reference/config/leafnodes/write_timeout.md · fetched 2026-08-31 · section: write_timeout -->
# write\_timeout

Available since NATS Server `2.12`

Requires Restart

What to do when a leaf node connection misses its `write_deadline`.

## Types

| Type     | Description | Choices                     |
| -------- | ----------- | --------------------------- |
| `string` | -           | `default`, `close`, `retry` |
