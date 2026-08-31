<!-- source: https://docs.nats.io/reference/config/resolver/hard_delete.md · fetched 2026-08-31 · section: hard_delete -->
# hard\_delete

Hot Reloadable

Handled only as part of the whole `resolver` block; replacement resolver is never Start()ed.

If true, and the resolver is in `full` mode, deleted account JWTs will be removed from disk rather than having the `.delete` suffix appended.

## Types

| Type      | Description | Choices         |
| --------- | ----------- | --------------- |
| `boolean` | -           | `true`, `false` |
