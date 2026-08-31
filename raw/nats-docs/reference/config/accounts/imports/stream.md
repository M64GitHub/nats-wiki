<!-- source: https://docs.nats.io/reference/config/accounts/imports/stream.md · fetched 2026-08-31 · section: stream -->
# stream

Hot Reloadable

Stream import source configuration. Exclusive of `service`.

## Properties

| Name                                                              | Description                                                                                | Type     | Default | Reloadable |
| ----------------------------------------------------------------- | ------------------------------------------------------------------------------------------ | -------- | ------- | ---------- |
| [`account`](/reference/config/accounts/imports/stream/account.md) | Account name owning the export.                                                            | `string` | -       | Yes        |
| [`subject`](/reference/config/accounts/imports/stream/subject.md) | The subject under which the stream or service is made accessible to the importing account. | `string` | -       | Yes        |
