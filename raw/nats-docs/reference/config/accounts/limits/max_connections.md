<!-- source: https://docs.nats.io/reference/config/accounts/limits/max_connections.md · fetched 2026-08-31 · section: max_connections -->
# max\_connections

Aliases:

<!-- -->

`max_conns`

Hot Reloadable

Enforced against already-connected clients: re-registration during the reload fails once the account is at the new limit and those connections are closed with MaxAccountConnectionsExceeded. Which connections get dropped follows map iteration order.

The maximum number of concurrent connections for this account.

## Types

| Type      | Description | Choices |
| --------- | ----------- | ------- |
| `integer` | -           | -       |
