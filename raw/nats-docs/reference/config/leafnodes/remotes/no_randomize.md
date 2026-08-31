<!-- source: https://docs.nats.io/reference/config/leafnodes/remotes/no_randomize.md · fetched 2026-08-31 · section: no_randomize -->
# no\_randomize

Aliases:

<!-- -->

`dont_randomize`

Requires Restart

If true and more than one URL is specified, the first one in the list will be used. If the client disconnects from the server, then the next URL will be used in order.

## Types

| Type      | Description | Choices         |
| --------- | ----------- | --------------- |
| `boolean` | -           | `true`, `false` |
