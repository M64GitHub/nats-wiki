<!-- source: https://docs.nats.io/reference/config/gateway/reject_unknown_cluster.md · fetched 2026-08-31 · section: reject_unknown_cluster -->
# reject\_unknown\_cluster

Requires Restart

If true, gateway will reject connections from cluster that are not configured in gateways. It does so by checking if the cluster name, provided by the incomming connection, exists as named gateway. This effectively disables gossiping of new cluster. It does not restrict a configured gateway, thus cluster, from dynamically growing.

## Types

| Type      | Description | Choices         |
| --------- | ----------- | --------------- |
| `boolean` | -           | `true`, `false` |
