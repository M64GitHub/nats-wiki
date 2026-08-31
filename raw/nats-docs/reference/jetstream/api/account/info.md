<!-- source: https://docs.nats.io/reference/jetstream/api/account/info.md · fetched 2026-08-31 · section: info -->
# Account Info

Retrieves JetStream account information.

<!-- -->

## Subject

`$JS.API.INFO`

## Response

A response from the JetStream $JS.API.INFO API

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

memoryintegerrequired

Memory Storage being used for Stream Message storage

Minimum:`0`

storageintegerrequired

File Storage being used for Stream Message storage

Minimum:`0`

streamsintegerrequired

Number of active Streams

Minimum:`0`

consumersintegerrequired

Number of active Consumers

Minimum:`0`

domainstring

The JetStream domain this account is in

▶limitsobjectrequired

tiersobject

▶apiobjectrequired

Option

<!-- -->

2

<!-- -->

(

<!-- -->

object

<!-- -->

)

▶errorobjectrequired

typeconst: "io.nats.jetstream.api.v1.account\_info\_response"required
