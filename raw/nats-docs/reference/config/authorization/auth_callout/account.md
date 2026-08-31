<!-- source: https://docs.nats.io/reference/config/authorization/auth_callout/account.md · fetched 2026-08-31 · section: account -->
# account

Aliases:

<!-- -->

`acc`

Requires Restart

diffOptions has no case for the AuthCallout field, so any change to this block - including adding or removing it - hits the default branch and aborts the entire reload with "config reload not supported for AuthCallout". Every other change in the same config file is discarded with it.

The name or public NKey of an account of the users which will be used by the authorization service to connect to the server.

## Types

| Type     | Description | Choices |
| -------- | ----------- | ------- |
| `string` | -           | -       |
