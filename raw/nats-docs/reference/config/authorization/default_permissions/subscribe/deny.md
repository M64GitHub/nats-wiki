<!-- source: https://docs.nats.io/reference/config/authorization/default_permissions/subscribe/deny.md · fetched 2026-08-31 · section: subscribe -->
# deny

Hot Reloadable

Folded into each user's permissions while the config is parsed, so it only affects users with no explicit `permissions`; from there it follows the users path and is re-applied to live client connections. Not re-applied to existing leafnode connections.

List of subjects that are denied to the client.

## Types

| Type         | Description | Choices |
| ------------ | ----------- | ------- |
| `[ string ]` | -           | -       |
