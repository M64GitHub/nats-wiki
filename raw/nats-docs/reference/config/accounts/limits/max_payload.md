<!-- source: https://docs.nats.io/reference/config/accounts/limits/max_payload.md · fetched 2026-08-31 · section: max_payload -->
# max\_payload

Aliases:

<!-- -->

`max_pay`

Hot Reloadable

Re-applied to already-connected clients. The per-client value is reset to unlimited first, so raising the limit works as well as lowering it; the effective value is min(account limit, server max\_payload).

The maximum payload size allowed for messages.

## Types

| Type      | Description | Choices |
| --------- | ----------- | ------- |
| `integer` | -           | -       |
