<!-- source: https://docs.nats.io/reference/config/accounts/limits/max_leafnodes.md · fetched 2026-08-31 · section: max_leafnodes -->
# max\_leafnodes

Aliases:

<!-- -->

`max_leafs`

Hot Reloadable

Only checked when a leafnode registers with the account. reloadAuthorization walks s.clients, and leafnode connections live in s.leafs, so existing leafnodes are never re-checked - the new limit only applies to leafnodes that connect after the reload.

The maximum number of concurrent leafnode connections allowed.

## Types

| Type      | Description | Choices |
| --------- | ----------- | ------- |
| `integer` | -           | -       |
