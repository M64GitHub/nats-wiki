<!-- source: https://docs.nats.io/reference/config/accounts.md · fetched 2026-08-31 · section: accounts -->
# accounts

Hot Reloadable

Static config-defined accounts.

## Properties

| Name                                                                        | Description                                                                                                                                                   | Type         | Default | Reloadable |
| --------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------ | ------- | ---------- |
| [`users`](/reference/config/accounts/users/.md)                             | A list of users under this account.                                                                                                                           | `object`     | -       | Yes        |
| [`exports`](/reference/config/accounts/exports/.md)                         | A list of exports for this account.                                                                                                                           | `object`     | -       | Yes\*      |
| [`imports`](/reference/config/accounts/imports/.md)                         | A list of imports for this account.                                                                                                                           | `object`     | -       | Yes\*      |
| [`nkey`](/reference/config/accounts/nkey.md)                                | Public NKey that identifies this account (an `A`-prefixed public account key). The server rejects the config if the value is not a valid public account NKey. | `string`     | -       | Yes\*      |
| [`jetstream`](/reference/config/accounts/jetstream/.md)                     |                                                                                                                                                               | `(multiple)` | -       | Yes\*      |
| [`default_permissions`](/reference/config/accounts/default_permissions/.md) | The default permissions applied to users within this account, if permissions are not explicitly defined for them.                                             | `object`     | -       | Yes\*      |
| [`msg_trace`](/reference/config/accounts/msg_trace/.md)                     | Where this account's message traces are delivered, and how often they are sampled.                                                                            | `object`     | -       | Yes        |
| [`mappings`](/reference/config/accounts/mappings/.md)                       |                                                                                                                                                               | `(multiple)` | -       | Yes\*      |
| [`limits`](/reference/config/accounts/limits/.md)                           |                                                                                                                                                               | `object`     | -       | Yes\*      |

\* See the property page for reload caveats.
