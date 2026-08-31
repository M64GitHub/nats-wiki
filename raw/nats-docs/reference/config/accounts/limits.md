<!-- source: https://docs.nats.io/reference/config/accounts/limits.md · fetched 2026-08-31 · section: limits -->
# limits

Hot Reloadable

max\_connections, max\_subscriptions and max\_payload are re-applied to already-connected clients. max\_leafnodes is the exception - see that page.

## Properties

| Name                                                                          | Description                                                      | Type      | Default | Reloadable |
| ----------------------------------------------------------------------------- | ---------------------------------------------------------------- | --------- | ------- | ---------- |
| [`max_connections`](/reference/config/accounts/limits/max_connections.md)     | The maximum number of concurrent connections for this account.   | `integer` | -       | Yes\*      |
| [`max_subscriptions`](/reference/config/accounts/limits/max_subscriptions.md) | The maximum number of concurrent subscriptions for this account. | `integer` | -       | Yes\*      |
| [`max_payload`](/reference/config/accounts/limits/max_payload.md)             | The maximum payload size allowed for messages.                   | `integer` | -       | Yes\*      |
| [`max_leafnodes`](/reference/config/accounts/limits/max_leafnodes.md)         | The maximum number of concurrent leafnode connections allowed.   | `integer` | -       | Yes\*      |

\* See the property page for reload caveats.
