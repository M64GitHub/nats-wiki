<!-- source: https://docs.nats.io/reference/system/monitor/routez.md · fetched 2026-08-31 · section: routez -->
# Routez

<!-- -->

## Request Schema

Request options for routez monitoring endpoint

subscriptionsboolean

Subscriptions indicates that Routez will return a route's subscriptions

subscriptions\_detailboolean

SubscriptionsDetail indicates if subscription details should be included in the results

## Response Schema

Response from routez monitoring endpoint

Expand All

▶exportobject

▶importobject

nowstring\<date-time>required

num\_routesintegerrequired

▶routesobject\[]required

server\_idstringrequired

server\_namestringrequired
