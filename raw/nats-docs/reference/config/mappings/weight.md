<!-- source: https://docs.nats.io/reference/config/mappings/weight.md · fetched 2026-08-31 · section: weight -->
# weight

Hot Reloadable

A number between 0 and 100 (inclusive). The string form allows for a trailing `%` sign. Note, if the `cluster` field is used, weights across the destinations must add up to 100% on a per-cluster basis unless artifical message loss is desired for testing.

## Types

| Type      | Description | Choices |
| --------- | ----------- | ------- |
| `string`  |             | -       |
| `integer` |             | -       |
