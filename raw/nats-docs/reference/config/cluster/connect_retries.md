<!-- source: https://docs.nats.io/reference/config/cluster/connect_retries.md · fetched 2026-08-31 · section: connect_retries -->
# connect\_retries

Hot Reloadable

Applies to route connection attempts started after the reload; an in-progress retry loop keeps the old value.

After how many failed connect attempts to give up establishing a connection to a *discovered* route. Default is 0, do not retry. When enabled, attempts will be made once a second. This, does not apply to explicitly configured routes.

## Types

| Type      | Description | Choices |
| --------- | ----------- | ------- |
| `integer` | -           | -       |
