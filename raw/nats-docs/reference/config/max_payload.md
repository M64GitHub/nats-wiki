<!-- source: https://docs.nats.io/reference/config/max_payload.md · fetched 2026-08-31 · section: max_payload -->
# max\_payload

Hot Reloadable

Maximum number of bytes in a message payload. Reducing this size may force you to implement chunking in your clients. Applies to client and leafnode payloads. It is not recommended to use values over 8MB but `max_payload` can be set up to 64MB. The max payload must be equal or smaller to the `max_pending` value.

## Types

| Type     | Description | Choices |
| -------- | ----------- | ------- |
| `string` | -           | -       |
