<!-- source: https://docs.nats.io/reference/config/authorization.md · fetched 2026-08-31 · section: authorization -->
# authorization

Hot Reloadable

Static single or multi-user declaration.

## Properties

| Name                                                                             | Description                                                                                                                                                   | Type      | Default | Reloadable |
| -------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------- | ------- | ---------- |
| [`username`](/reference/config/authorization/username.md)                        | Specifies a global user name that clients can use to authenticate the server (requires `password`, exclusive of `token`).                                     | `string`  | -       | Yes\*      |
| [`password`](/reference/config/authorization/password.md)                        | Specifies a global password that clients can use to authenticate the server (requires `user`, exclusive of `token`).                                          | `string`  | -       | Yes\*      |
| [`token`](/reference/config/authorization/token.md)                              | Specifies a global token that clients can use to authenticate with the server (exclusive of `user` and `password`).                                           | `string`  | -       | Yes\*      |
| [`users`](/reference/config/authorization/users/.md)                             | A list of multiple users with different credentials.                                                                                                          | `object`  | -       | Yes        |
| [`default_permissions`](/reference/config/authorization/default_permissions/.md) | The default permissions applied to users, if permissions are not explicitly defined for them.                                                                 | `object`  | -       | Yes\*      |
| [`proxy_required`](/reference/config/authorization/proxy_required.md)            | Reject client connections that did not arrive through a PROXY protocol header.                                                                                | `boolean` | `false` | No         |
| [`timeout`](/reference/config/authorization/timeout.md)                          | Maximum number of seconds to wait for a client to authenticate.                                                                                               | `float`   | `1`     | Yes\*      |
| [`auth_callout`](/reference/config/authorization/auth_callout/.md)               | Enables the auth callout functionality. All client connections requiring authentication will have their credentials pass-through to a dedicated auth service. | `object`  | -       | No\*       |

\* See the property page for reload caveats.
