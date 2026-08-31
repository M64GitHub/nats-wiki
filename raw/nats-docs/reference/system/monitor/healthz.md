<!-- source: https://docs.nats.io/reference/system/monitor/healthz.md · fetched 2026-08-31 · section: healthz -->
# Healthz

<!-- -->

## Request Schema

Request options for healthz monitoring endpoint

accountstring

consumerstring

detailsboolean

js-enabledboolean

Deprecated: Use JSEnabledOnly instead

js-enabled-onlyboolean

js-meta-onlyboolean

js-server-onlyboolean

streamstring

## Response Schema

Response from healthz monitoring endpoint

Expand All

errorstring

▶errorsobject\[]

statusstringrequired

status\_codeinteger
