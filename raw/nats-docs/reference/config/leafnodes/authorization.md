<!-- source: https://docs.nats.io/reference/config/leafnodes/authorization.md · fetched 2026-08-31 · section: authorization -->
# authorization

Requires Restart

Authorization scoped to accepting leaf node connections.

## Properties

| Name                                                                            | Description                                                                       | Type      | Default | Reloadable |
| ------------------------------------------------------------------------------- | --------------------------------------------------------------------------------- | --------- | ------- | ---------- |
| [`username`](/reference/config/leafnodes/authorization/username.md)             | User name the connecting server authenticates with (requires `password`).         | `string`  | -       | No         |
| [`password`](/reference/config/leafnodes/authorization/password.md)             | Password the connecting server authenticates with (requires `username`).          | `string`  | -       | No         |
| [`users`](/reference/config/leafnodes/authorization/users/.md)                  | A list of multiple users with different credentials.                              | `object`  | -       | No\*       |
| [`timeout`](/reference/config/leafnodes/authorization/timeout.md)               | Maximum number of seconds to wait for a client to authenticate.                   | `float`   | `1`     | No         |
| [`account`](/reference/config/leafnodes/authorization/account.md)               | Account that leaf nodes authenticating with these credentials are bound to.       | `string`  | -       | No         |
| [`nkey`](/reference/config/leafnodes/authorization/nkey.md)                     | Public user nkey a connecting leaf node must sign for.                            | `string`  | -       | No         |
| [`proxy_required`](/reference/config/leafnodes/authorization/proxy_required.md) | Reject leaf node connections that did not arrive through a PROXY protocol header. | `boolean` | `false` | No         |

\* See the property page for reload caveats.
