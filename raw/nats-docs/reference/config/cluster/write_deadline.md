<!-- source: https://docs.nats.io/reference/config/cluster/write_deadline.md · fetched 2026-08-31 · section: write_deadline -->
# write\_deadline

Available since NATS Server `2.12`

Hot Reloadable

How long a route write may block before the connection is treated as stalled.

## Types

| Type       | Description                                                    | Choices |
| ---------- | -------------------------------------------------------------- | ------- |
| `duration` | Duration as a string with units such as 100ms, 10s, 5m, or 2h. | -       |
