<!-- source: https://docs.nats.io/reference/system/monitor/statsz.md · fetched 2026-08-31 · section: statsz -->
# Statsz

<!-- -->

## Request Schema

Request options for statsz monitoring endpoint

clusterstring

filter by cluster name

domainstring

filter by JS domain

exact\_matchboolean

if the above filters should use exact matching or only "contains"

hoststring

filter by host name

server\_namestring

filter by server name

tagsstring\[]

filter by tags (must match all tags)

## Response Schema

Response from statsz monitoring endpoint

Expand All

active\_accountsintegerrequired

active\_serversinteger

connectionsintegerrequired

coresintegerrequired

cpunumberrequired

▶gatewaysobject\[]

gomaxprocsinteger

gomemlimitinteger

▶jetstreamobject

memintegerrequired

▶receivedobjectrequired

▶routesobject\[]

▶sentobjectrequired

▶slow\_consumer\_statsobject

slow\_consumersintegerrequired

▶stale\_connection\_statsobject

stale\_connectionsinteger

stalled\_clientsinteger

startstring\<date-time>required

subscriptionsintegerrequired

total\_connectionsintegerrequired
