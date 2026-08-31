<!-- source: https://docs.nats.io/reference/config/accounts/default_permissions/allow_responses/max.md · fetched 2026-08-31 · section: allow_responses -->
# max

Hot Reloadable

Folded into each user's permissions at parse time (only users with no explicit `permissions`). Re-applied live, but setPermissions resets the client's reply-tracking map on EVERY reload, so a service still owing a response for a request received before the reload loses permission to publish it.

The maximum number of response messages that can be published.

## Types

| Type      | Description | Choices |
| --------- | ----------- | ------- |
| `integer` | -           | -       |
