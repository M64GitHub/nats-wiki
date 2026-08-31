<!-- source: https://docs.nats.io/reference/system/advisory/account-connections.md · fetched 2026-08-31 · section: account-connections -->
# Account Connections

Account connection limit events.

<!-- -->

## Subscription Subject

`$SYS.ACCOUNT.{account}.CONNECTIONS`

Where `{account}` is the account name.

## Event Schema

Regular advisory published with account states

Expand All

typeconst: "io.nats.server.advisory.v1.account\_connections"required

idstringrequired

Unique correlation ID for this event

timestampstringrequired

The time this event was created in RFC3339 format

▶serverobjectrequired

Details about the server the client connected to

accstringrequired

The account the update is for

connsintegerrequired

The number of active client connections to the server

Minimum:`0`

leafnodesintegerrequired

The number of active leafnode connections to the server

Minimum:`0`

total\_connsintegerrequired

The combined client and leafnode account connections

Minimum:`0`

▶sentobject

Data sent by this account

▶receivedobject

Data received by this account

slow\_consumersinteger

The number of slow consumer errors this account encountered

Minimum:`0`
