<!-- source: https://docs.nats.io/reference/config/authorization/auth_callout/key.md · fetched 2026-08-31 · section: key -->
# key

Aliases:

<!-- -->

`xkey`

Requires Restart

diffOptions has no case for the AuthCallout field, so any change to this block - including adding or removing it - hits the default branch and aborts the entire reload with "config reload not supported for AuthCallout". Every other change in the same config file is discarded with it.

A public XKey that will encrypt server requests to the auth service.

## Types

| Type     | Description | Choices |
| -------- | ----------- | ------- |
| `string` | -           | -       |
