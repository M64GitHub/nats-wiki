<!-- source: https://docs.nats.io/reference/jetstream/api/account/purge.md · fetched 2026-08-31 · section: purge -->
# Account Purge

Purges all data for an account.

<!-- -->

## Subject

`$JS.API.ACCOUNT.PURGE`

## Response

A response from the JetStream $JS.API.ACCOUNT.PURGE API

Expand All

One of the following:

Option

<!-- -->

1

<!-- -->

(

<!-- -->

object

<!-- -->

)

▶errorobjectrequired

Option

<!-- -->

2

<!-- -->

(

<!-- -->

object

<!-- -->

)

initiatedboolean

If the purge operation was successfully started

Default:`false`

typeconst: "io.nats.jetstream.api.v1.account\_purge\_response"
