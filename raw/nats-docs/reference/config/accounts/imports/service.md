<!-- source: https://docs.nats.io/reference/config/accounts/imports/service.md · fetched 2026-08-31 · section: service -->
# service

Hot Reloadable

Stream import source configuration. Exclusive of `stream`.

## Properties

| Name                                                               | Description                                                                                | Type     | Default | Reloadable |
| ------------------------------------------------------------------ | ------------------------------------------------------------------------------------------ | -------- | ------- | ---------- |
| [`account`](/reference/config/accounts/imports/service/account.md) | Account name owning the export.                                                            | `string` | -       | Yes        |
| [`subject`](/reference/config/accounts/imports/service/subject.md) | The subject under which the stream or service is made accessible to the importing account. | `string` | -       | Yes        |
