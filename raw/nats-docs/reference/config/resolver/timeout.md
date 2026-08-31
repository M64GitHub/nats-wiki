<!-- source: https://docs.nats.io/reference/config/resolver/timeout.md · fetched 2026-08-31 · section: timeout -->
# timeout

Hot Reloadable

Handled only as part of the whole `resolver` block; replacement resolver is never Start()ed.

Defines the request timeout for resolvers interacting with with other resolvers.

## Types

| Type       | Description                                                    | Choices |
| ---------- | -------------------------------------------------------------- | ------- |
| `duration` | Duration as a string with units such as 100ms, 10s, 5m, or 2h. | -       |
