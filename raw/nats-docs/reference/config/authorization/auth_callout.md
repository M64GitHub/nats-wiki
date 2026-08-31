<!-- source: https://docs.nats.io/reference/config/authorization/auth_callout.md · fetched 2026-08-31 · section: auth_callout -->
# auth\_callout

Requires Restart

diffOptions has no case for the AuthCallout field, so any change to this block - including adding or removing it - hits the default branch and aborts the entire reload with "config reload not supported for AuthCallout". Every other change in the same config file is discarded with it.

Enables the auth callout functionality. All client connections requiring authentication will have their credentials pass-through to a dedicated auth service.

## Properties

| Name                                                                 | Description                                                                                                                                  | Type     | Default | Reloadable |
| -------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- | -------- | ------- | ---------- |
| [`issuer`](/reference/config/authorization/auth_callout/issuer.md)   | An account public NKey.                                                                                                                      | `string` | -       | No\*       |
| [`account`](/reference/config/authorization/auth_callout/account.md) | The name or public NKey of an account of the users which will be used by the authorization service to connect to the server.                 | `string` | `$G`    | No\*       |
| [`users`](/reference/config/authorization/auth_callout/users.md)     | The names or public NKeys of users within the defined account that will be used by the the auth service itself and thus bypass auth callout. | `string` | -       | No\*       |
| [`key`](/reference/config/authorization/auth_callout/key.md)         | A public XKey that will encrypt server requests to the auth service.                                                                         | `string` | -       | No\*       |

\* See the property page for reload caveats.
