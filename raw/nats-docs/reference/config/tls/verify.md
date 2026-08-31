<!-- source: https://docs.nats.io/reference/config/tls/verify.md · fetched 2026-08-31 · section: verify -->
# verify

Hot Reloadable

Set through the TLS block rather than the `-tlsverify` flag, so it reloads with the rest of the TLS material.

If true, require and verify client certificates. Does not apply to monitoring.

## Types

| Type      | Description | Choices         |
| --------- | ----------- | --------------- |
| `boolean` | -           | `true`, `false` |
