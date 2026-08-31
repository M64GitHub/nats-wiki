<!-- source: https://docs.nats.io/reference/config/accounts/limits/max_subscriptions.md · fetched 2026-08-31 · section: max_subscriptions -->
# max\_subscriptions

Aliases:

<!-- -->

`max_subs`

Hot Reloadable

Re-applied to already-connected clients, and a client already holding more subscriptions than the new limit is disconnected with MaxSubscriptionsExceeded. Effective value is min(account limit, server max\_subscriptions).

The maximum number of concurrent subscriptions for this account.

## Types

| Type      | Description | Choices |
| --------- | ----------- | ------- |
| `integer` | -           | -       |
