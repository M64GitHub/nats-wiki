<!-- source: https://docs.nats.io/reference/config/resolver/allow_delete.md · fetched 2026-08-31 · section: allow_delete -->
# allow\_delete

Hot Reloadable

Handled only as part of the whole `resolver` block; replacement resolver is never Start()ed.

If true, allows JWTs to be deleted. Note, in `full` mode, this will result in the JWT file being renamed to with a `.delete` suffix, unless `hard_delete` is true.

## Types

| Type      | Description | Choices         |
| --------- | ----------- | --------------- |
| `boolean` | -           | `true`, `false` |
