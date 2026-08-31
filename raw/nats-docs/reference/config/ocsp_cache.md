<!-- source: https://docs.nats.io/reference/config/ocsp_cache.md · fetched 2026-08-31 · section: ocsp_cache -->
# ocsp\_cache

Hot Reloadable

Cache OCSP responses the server staples, so it does not query the responder on every handshake.

## Types

| Type      | Description                                                  | Choices         |
| --------- | ------------------------------------------------------------ | --------------- |
| `boolean` |                                                              | `true`, `false` |
| `object`  | An object with a set of explicit properties that can be set. | -               |

## Properties

| Name                                                                   | Description                                                                                 | Type      | Default | Reloadable |
| ---------------------------------------------------------------------- | ------------------------------------------------------------------------------------------- | --------- | ------- | ---------- |
| [`type`](/reference/config/ocsp_cache/type.md)                         | Where stapled responses are cached. `local` writes them under the server's store directory. | `string`  | `none`  | Yes        |
| [`local_store`](/reference/config/ocsp_cache/local_store.md)           | Directory for the local cache.                                                              | `string`  | -       | Yes        |
| [`preserve_revoked`](/reference/config/ocsp_cache/preserve_revoked.md) | Keep revoked responses in the cache rather than evicting them.                              | `boolean` | `false` | Yes        |
