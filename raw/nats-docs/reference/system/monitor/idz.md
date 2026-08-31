<!-- source: https://docs.nats.io/reference/system/monitor/idz.md · fetched 2026-08-31 · section: idz -->
# Idz

<!-- -->

## Response Schema

Response from idz monitoring endpoint

clusterstring

domainstring

feature\_flags{ \[key: string]: boolean }

flagsintegerrequired

Generic capability flags

hoststringrequired

idstringrequired

jetstreambooleanrequired

Whether JetStream is enabled (deprecated in favor of the \`ServerCapability\`).

metadata{ \[key: string]: string }

namestringrequired

seqintegerrequired

Sequence and Time from the remote server for this message.

tagsstring\[]

timestring\<date-time>required

verstringrequired
