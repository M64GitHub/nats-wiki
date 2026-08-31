<!-- source: https://docs.nats.io/reference/config/accounts/mappings/cluster.md · fetched 2026-08-31 · section: cluster -->
# cluster

Hot Reloadable

If specified, the destination is cluster-scoped. Messages received by servers within the named cluster will only consider mappings with the same cluster name. Otherwise, it will fallback to non-cluster scoped mappings.

## Types

| Type     | Description | Choices |
| -------- | ----------- | ------- |
| `string` | -           | -       |
