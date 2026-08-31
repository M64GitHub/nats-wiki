<!-- source: https://docs.nats.io/reference/config/max_control_line.md · fetched 2026-08-31 · section: max_control_line -->
# max\_control\_line

Hot Reloadable

Applied to client connections only. Route, gateway and leafnode connections keep the value they were created with.

Maximum length of a protocol line (including combined length of subject and queue group). Increasing this value may require client changes to be used. Applies to all traffic.

## Types

| Type     | Description | Choices |
| -------- | ----------- | ------- |
| `string` | -           | -       |
