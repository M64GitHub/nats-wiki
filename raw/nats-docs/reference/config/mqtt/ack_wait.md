<!-- source: https://docs.nats.io/reference/config/mqtt/ack_wait.md · fetched 2026-08-31 · section: ack_wait -->
# ack\_wait

Aliases:

<!-- -->

`ackwait`

Hot Reloadable

The reload handler only logs; the value takes effect because the options are swapped. Existing subscriptions keep the old value.

This is the amount of time after which a QoS 1 message sent to a client is redelivered as a `DUPLICATE` if the server has not received the `PUBACK` packet on the original Packet Identifier. will cause the server to use the default value (30 seconds).

Note that changes to this option is applied only to new MQTT subscriptions.

## Types

| Type       | Description                                                    | Choices |
| ---------- | -------------------------------------------------------------- | ------- |
| `duration` | Duration as a string with units such as 100ms, 10s, 5m, or 2h. | -       |
