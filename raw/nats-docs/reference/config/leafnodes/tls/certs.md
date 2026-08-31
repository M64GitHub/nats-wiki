<!-- source: https://docs.nats.io/reference/config/leafnodes/tls/certs.md · fetched 2026-08-31 · section: certs -->
# certs

Hot Reloadable

Multiple certificate/key pairs to serve, so one listener can present different certificates to different clients. Use this instead of `cert_file` and `key_file`.

## Properties

| Name                                                              | Description                     | Type     | Default | Reloadable |
| ----------------------------------------------------------------- | ------------------------------- | -------- | ------- | ---------- |
| [`cert_file`](/reference/config/leafnodes/tls/certs/cert_file.md) | Certificate file for this pair. | `string` | -       | Yes        |
| [`key_file`](/reference/config/leafnodes/tls/certs/key_file.md)   | Key file for this pair.         | `string` | -       | Yes        |
