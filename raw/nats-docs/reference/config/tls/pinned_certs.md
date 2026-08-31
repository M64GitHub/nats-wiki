<!-- source: https://docs.nats.io/reference/config/tls/pinned_certs.md · fetched 2026-08-31 · section: pinned_certs -->
# pinned\_certs

Hot Reloadable

Reload also disconnects already-connected clients whose certificate is no longer pinned.

List of hex-encoded SHA256 of DER-encoded public key fingerprints. When present, during the TLS handshake, the provided certificate's fingerprint is required to be present in the list, otherwise the connection will be closed.

## Types

| Type     | Description | Choices |
| -------- | ----------- | ------- |
| `string` | -           | -       |
