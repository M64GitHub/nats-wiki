<!-- source: https://docs.nats.io/reference/system/monitor/leafz.md · fetched 2026-08-31 · section: leafz -->
# Leafz

<!-- -->

## Request Schema

Request options for leafz monitoring endpoint

accountstring

subscriptionsboolean

Subscriptions indicates that Leafz will return a leafnode's subscriptions

## Response Schema

Response from leafz monitoring endpoint

Expand All

leafnodesintegerrequired

▶leafsobject\[]required

nowstring\<date-time>required

server\_idstringrequired
