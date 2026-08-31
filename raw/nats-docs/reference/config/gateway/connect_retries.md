<!-- source: https://docs.nats.io/reference/config/gateway/connect_retries.md · fetched 2026-08-31 · section: connect_retries -->
# connect\_retries

Requires Restart

After how many failed connect attempts to give up establishing a connection to a discovered gateway. Default is 0, do not retry. When enabled, attempts will be made once a second. This, does not apply to explicitly configured gateways.

## Types

| Type      | Description | Choices |
| --------- | ----------- | ------- |
| `integer` | -           | -       |
