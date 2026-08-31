<!-- source: https://docs.nats.io/reference/config/authorization/auth_callout/users.md · fetched 2026-08-31 · section: users -->
# users

Aliases:

<!-- -->

`auth_users`

Requires Restart

diffOptions has no case for the AuthCallout field, so any change to this block - including adding or removing it - hits the default branch and aborts the entire reload with "config reload not supported for AuthCallout". Every other change in the same config file is discarded with it.

The names or public NKeys of users within the defined account that will be used by the the auth service itself and thus bypass auth callout.

## Types

| Type         | Description | Choices |
| ------------ | ----------- | ------- |
| `[ string ]` | -           | -       |
