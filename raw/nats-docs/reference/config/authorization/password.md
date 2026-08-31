<!-- source: https://docs.nats.io/reference/config/authorization/password.md · fetched 2026-08-31 · section: password -->
# password

Aliases:

<!-- -->

`pass`

Hot Reloadable

passwordOption embeds authOption, so the reload re-authenticates every live connection against the new simple-auth password; clients still presenting the old one are disconnected.

Specifies a global password that clients can use to authenticate the server (requires `user`, exclusive of `token`).

## Types

| Type     | Description | Choices |
| -------- | ----------- | ------- |
| `string` | -           | -       |
