<!-- source: https://docs.nats.io/reference/config/accounts/msg_trace.md · fetched 2026-08-31 · section: msg_trace -->
# msg\_trace

Hot Reloadable

Where this account's message traces are delivered, and how often they are sampled.

## Properties

| Name                                                           | Description                                        | Type      | Default | Reloadable |
| -------------------------------------------------------------- | -------------------------------------------------- | --------- | ------- | ---------- |
| [`dest`](/reference/config/accounts/msg_trace/dest.md)         | Subject the trace events are published to.         | `string`  | -       | Yes        |
| [`sampling`](/reference/config/accounts/msg_trace/sampling.md) | Percentage of traced messages to report, 1 to 100. | `integer` | `100`   | Yes        |
