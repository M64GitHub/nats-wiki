<!-- source: https://docs.nats.io/reference/config/leafnodes/authorization/users.md · fetched 2026-08-31 · section: users -->
# users

Requires Restart

Reordering the users array is accepted because the comparison is keyed by username.

A list of multiple users with different credentials.

## Properties

| Name                                                                                  | Description                                                                                                                                                                                                                                                                                                                                          | Type      | Default | Reloadable |
| ------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------- | ------- | ---------- |
| [`username`](/reference/config/leafnodes/authorization/users/username.md)             | Name of the user.                                                                                                                                                                                                                                                                                                                                    | `string`  | -       | No         |
| [`password`](/reference/config/leafnodes/authorization/users/password.md)             | Password of the user. This can be a free-text value (not recommended) or a bcrypted value using the `nats server passwd` CLI command.                                                                                                                                                                                                                | `string`  | -       | No         |
| [`account`](/reference/config/leafnodes/authorization/users/account.md)               | Account that leaf nodes authenticating as this user are bound to. Each user in the list can name a different account. The account must be declared in the `accounts` block or the server refuses to start. Leave it unset to bind to the global account; the `account` on the surrounding `authorization` block does not apply to users listed here. | `string`  | -       | No         |
| [`proxy_required`](/reference/config/leafnodes/authorization/users/proxy_required.md) | Reject this user's leaf node connections if they did not arrive through a PROXY protocol header. Setting `proxy_required` on the surrounding `authorization` block applies the requirement to every user regardless of what they set here.                                                                                                           | `boolean` | `false` | Yes\*      |

\* See the property page for reload caveats.
