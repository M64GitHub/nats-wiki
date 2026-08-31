<!-- source: https://docs.nats.io/reference/config/authorization/username.md · fetched 2026-08-31 · section: username -->
# username

Aliases:

<!-- -->

`user`

Hot Reloadable

usernameOption embeds authOption, so the reload re-authenticates every live connection against the new simple-auth username; clients still presenting the old one are disconnected.

Specifies a global user name that clients can use to authenticate the server (requires `password`, exclusive of `token`).

## Types

| Type     | Description | Choices |
| -------- | ----------- | ------- |
| `string` | -           | -       |
