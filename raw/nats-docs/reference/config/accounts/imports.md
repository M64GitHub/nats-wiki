<!-- source: https://docs.nats.io/reference/config/accounts/imports.md · fetched 2026-08-31 · section: imports -->
# imports

Hot Reloadable

Fully re-resolved, but every reload tears down and re-creates ALL of the account's service-import subscriptions, so there is a short window where imported service subjects have no subscriber and requests arriving in it are dropped.

A list of imports for this account.

## Properties

| Name                                                        | Description                                                                     | Type     | Default | Reloadable |
| ----------------------------------------------------------- | ------------------------------------------------------------------------------- | -------- | ------- | ---------- |
| [`stream`](/reference/config/accounts/imports/stream/.md)   | Stream import source configuration. Exclusive of `service`.                     | `object` | -       | Yes        |
| [`service`](/reference/config/accounts/imports/service/.md) | Stream import source configuration. Exclusive of `stream`.                      | `object` | -       | Yes        |
| [`prefix`](/reference/config/accounts/imports/prefix.md)    | A local subject prefix mapping for the imported stream. Applicable to `stream`. | `string` | -       | Yes        |
| [`to`](/reference/config/accounts/imports/to.md)            | A local subject mapping for the imported service. Applicable to `service`.      | `string` | -       | Yes        |
