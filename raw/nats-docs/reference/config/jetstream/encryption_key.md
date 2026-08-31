<!-- source: https://docs.nats.io/reference/config/jetstream/encryption_key.md · fetched 2026-08-31 · section: encryption_key -->
# encryption\_key

Aliases:

<!-- -->

`key`, `ek`

Requires Restart

If defined, enables JetStream filestore encryption using the value as the encryption key. A key length of at least 32 bytes is recommended. Note, this key is HMAC-256 hashed on startup which reduces the byte length to 64.

## Types

| Type     | Description | Choices |
| -------- | ----------- | ------- |
| `string` | -           | -       |
