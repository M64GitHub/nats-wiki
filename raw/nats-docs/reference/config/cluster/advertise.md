<!-- source: https://docs.nats.io/reference/config/cluster/advertise.md · fetched 2026-08-31 · section: advertise -->
# advertise

Aliases:

<!-- -->

`cluster_advertise`

Hot Reloadable

Advertised cluster `<host>:<port>`. Useful for cluster setups since behind NAT. When using TLS this is important to set to control the hostname that clients will use when discovering the route so TLS hostname verification does not fail.

## Types

| Type     | Description | Choices |
| -------- | ----------- | ------- |
| `string` | -           | -       |
