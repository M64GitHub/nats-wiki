<!-- source: https://docs.nats.io/reference/config/resolver/type.md · fetched 2026-08-31 · section: type -->
# type

Hot Reloadable

Handled as part of the whole `resolver` block. The replacement resolver is never started, so its refresh machinery does not run until the server restarts.

Defines whether the resolver type. A `full` resolver stores all account JWTs unless they are explicitly deleted.

A `cache` resolver stores only a subset based on a least-recently-used (LRU) TTL.

## Types

| Type     | Description | Choices         |
| -------- | ----------- | --------------- |
| `string` | -           | `full`, `cache` |
