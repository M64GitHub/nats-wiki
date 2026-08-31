<!-- source: https://docs.nats.io/reference/config/ping_interval.md · fetched 2026-08-31 · section: ping_interval -->
# ping\_interval

Hot Reloadable

Duration at which pings are sent to clients, leaf nodes and routes. In the presence of client traffic, such as messages or client side pings, the server will not send pings. Therefore it is recommended to keep this value bigger than what clients use.

## Types

| Type     | Description | Choices |
| -------- | ----------- | ------- |
| `string` | -           | -       |
