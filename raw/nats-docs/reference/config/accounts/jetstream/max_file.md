<!-- source: https://docs.nats.io/reference/config/accounts/jetstream/max_file.md · fetched 2026-08-31 · section: max_file -->
# max\_file

Aliases:

<!-- -->

`max_store`, `max_disk`, `store`, `disk`

Hot Reloadable

Applied by replacing the account's whole limits map, so it is all-or-nothing: on a standalone server the update is rejected if it would put max\_memory/max\_file below already-reserved stream bytes, and the reload still reports success (the error is only logged). Worse, the account walk returns on the first such error, so accounts later in iteration order get no limit update at all. This is the value whose reduction triggers that rejection.

The maximum storage allowed across all file-based assets.

## Types

| Type      | Description | Choices |
| --------- | ----------- | ------- |
| `integer` | -           | -       |
