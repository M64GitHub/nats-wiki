<!-- source: https://docs.nats.io/reference/config/mqtt/tls/pinned_certs.md · fetched 2026-08-31 · section: pinned_certs -->
# pinned\_certs

Requires Restart

List of hex-encoded SHA256 of DER-encoded public key fingerprints. When present, during the TLS handshake, the provided certificate's fingerprint is required to be present in the list, otherwise the connection will be closed.

## Types

| Type     | Description | Choices |
| -------- | ----------- | ------- |
| `string` | -           | -       |
