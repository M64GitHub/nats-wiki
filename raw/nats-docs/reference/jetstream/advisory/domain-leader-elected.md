<!-- source: https://docs.nats.io/reference/jetstream/advisory/domain-leader-elected.md · fetched 2026-08-31 · section: domain-leader-elected -->
# Domain Leader Elected

New domain leader elected.

<!-- -->

## Subscription Subject

`$JS.EVENT.ADVISORY.DOMAIN.LEADER_ELECTED.{domain}`

## Event Schema

An Advisory sent when a meta leader is elected

Expand All

typeconst: "io.nats.jetstream.advisory.v1.domain\_leader\_elected"required

idstringrequired

Unique correlation ID for this event

timestampstringrequired

The time this event was created in RFC3339 format

leaderstringrequired

The server name of the elected leader

▶replicasobjectrequired

clusterstringrequired

The cluster holding the leader

domainstring

The domain the leader is in
