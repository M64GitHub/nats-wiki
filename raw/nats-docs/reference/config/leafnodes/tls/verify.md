<!-- source: https://docs.nats.io/reference/config/leafnodes/tls/verify.md · fetched 2026-08-31 · section: verify -->
# verify

Hot Reloadable

New connections only. Note verify\_and\_map, which also implies verify, is NOT reloadable because it sets the separate TLSMap field.

If true, require and verify client certificates. Does not apply to monitoring.

## Types

| Type      | Description | Choices         |
| --------- | ----------- | --------------- |
| `boolean` | -           | `true`, `false` |
