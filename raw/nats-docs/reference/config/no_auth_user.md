<!-- source: https://docs.nats.io/reference/config/no_auth_user.md · fetched 2026-08-31 · section: no_auth_user -->
# no\_auth\_user

Hot Reloadable

Removing `no_auth_user` reloads, provided no user in the new configuration still has that username. Setting or changing it fails the reload.

Name of the user that non-authenticated clients will inherit the authorization controls of. This must be a user defined in either the `authorization` or `accounts` block.

## Types

| Type     | Description | Choices |
| -------- | ----------- | ------- |
| `string` | -           | -       |
