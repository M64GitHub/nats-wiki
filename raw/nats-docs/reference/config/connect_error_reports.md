<!-- source: https://docs.nats.io/reference/config/connect_error_reports.md · fetched 2026-08-31 · section: connect_error_reports -->
# connect\_error\_reports

Hot Reloadable

The reload handler only logs, but the new value is read on every connection attempt, so it takes effect immediately.

Number of attempts at which a repeated failed route, gateway or leaf node connection is reported. Connect attempts are made once every second.

## Types

| Type      | Description | Choices |
| --------- | ----------- | ------- |
| `integer` | -           | -       |
