<!-- source: https://docs.nats.io/reference/config/proxy_protocol.md · fetched 2026-08-31 · section: proxy_protocol -->
# proxy\_protocol

Available since NATS Server `2.12`

Requires Restart

Accept the PROXY protocol header on client connections, so the server sees the original client address behind a load balancer.

## Types

| Type      | Description | Choices         |
| --------- | ----------- | --------------- |
| `boolean` | -           | `true`, `false` |
