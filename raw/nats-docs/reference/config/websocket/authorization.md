<!-- source: https://docs.nats.io/reference/config/websocket/authorization.md · fetched 2026-08-31 · section: authorization -->
# authorization

Aliases:

<!-- -->

`authentication`

Requires Restart

## Properties

| Name                                                                | Description                                                                                                               | Type     | Default | Reloadable |
| ------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- | -------- | ------- | ---------- |
| [`username`](/reference/config/websocket/authorization/username.md) | Specifies a global user name that clients can use to authenticate the server (requires `password`, exclusive of `token`). | `string` | -       | No         |
| [`password`](/reference/config/websocket/authorization/password.md) | Specifies a global password that clients can use to authenticate the server (requires `user`, exclusive of `token`).      | `string` | -       | No         |
| [`token`](/reference/config/websocket/authorization/token.md)       | Specifies a global token that clients can use to authenticate with the server (exclusive of `user` and `password`).       | `string` | -       | No         |
| [`timeout`](/reference/config/websocket/authorization/timeout.md)   | Maximum number of seconds to wait for a client to authenticate.                                                           | `float`  | `1`     | No         |
