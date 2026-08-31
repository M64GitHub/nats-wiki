<!-- source: https://docs.nats.io/reference/config/authorization/auth_callout/issuer.md · fetched 2026-08-31 · section: issuer -->
# issuer

Requires Restart

diffOptions has no case for the AuthCallout field, so any change to this block - including adding or removing it - hits the default branch and aborts the entire reload with "config reload not supported for AuthCallout". Every other change in the same config file is discarded with it.

An account public NKey.

## Types

| Type     | Description | Choices |
| -------- | ----------- | ------- |
| `string` | -           | -       |
