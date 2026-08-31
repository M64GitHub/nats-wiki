<!-- source: https://docs.nats.io/reference/config/max_subscriptions.md · fetched 2026-08-31 · section: max_subscriptions -->
# max\_subscriptions

Aliases:

<!-- -->

`max_subs`

Requires Restart

This is the per-client limit. The per-account `max_subscriptions` under `accounts` is a different key and does reload.

Maximum numbers of subscriptions per client and leafnode accounts connection. A value of `0` means unlimited.

## Types

| Type     | Description | Choices |
| -------- | ----------- | ------- |
| `string` | -           | -       |
