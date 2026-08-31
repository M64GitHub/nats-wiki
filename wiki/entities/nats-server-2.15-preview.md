---
title: nats-server 2.15 (preview)
type: entity
kind: release
area: [deploy, jetstream, security]
since: [2.15]
verified-against: nats-server 2.14.6
verified-on: 2026-08-31
tags: [release, 2.15, preview, js_ack_fc_v2, acl-migration]
aliases: ["2.15", v2.15, "v2.15.0-preview.1"]
sources: [s-docs-upgrade-to-2.14, s-relnotes-2.14.0]
created: 2026-08-31
updated: 2026-08-31
---

# nats-server 2.15 (preview)

Not released. It exists as a single preview tag, and it matters **now** because of one breaking
default it will bring.

## Facts

| | |
|---|---|
| status | **preview only** — no stable release |
| only tag | **`v2.15.0-preview.1`**, 2026-08-24, flagged prerelease by GitHub |
| license | Apache-2.0 |

From `raw/release-notes/_tags-and-dates.md` (GitHub releases API, fetched 2026-08-31): one 2.15 tag
across 291 release tags.

## The one thing to act on before it ships

**In 2.15 the default ack and flow-control subject format becomes v2.**

```
v1: $JS.ACK.<stream>.<consumer>.<num delivered>.<stream seq>.<consumer seq>.<timestamp>.<num pending>
v2: $JS.ACK.<domain>.<account hash>.<stream>.<consumer>.<num delivered>.<stream seq>.<consumer seq>.<timestamp>.<num pending>
```

The v2 format inserts a **domain and account hash**, so the same stream and consumer names can be
used in different domains and accounts without conflicting.

> Users that have defined account imports/exports or subject permissions containing the
> `$JS.ACK.<stream>.>` or `$JS.FC.<stream>.>` (or more granular) subjects **will be required to
> update their ACLs and/or account imports/exports before the 2.15 release**
> (source: [[s-docs-upgrade-to-2.14]]).

**Who needs to do nothing:** deployments with no such imports, exports or permissions — for example
JetStream used within a single account — and anyone who wrote the catch-all wildcards `$JS.ACK.>`
or `$JS.FC.>`.

**How to test it today**, on 2.14, which supports both formats:

```
feature_flags {
  js_ack_fc_v2: true
}
```

Omitting the flag means "server default", which on 2.14 is v1. `true` selects v2 while still
supporting v1; `false` selects v1 while still supporting v2. Remember that **`feature_flags` must be
removed from the config before downgrading below 2.14** — older servers do not recognise the field.

See [[nats-server-2.14]] and [[account]].

## To verify

- **Nothing else about 2.15 is known from an ingested source.** The preview's release body has not
  been fetched, and the docs mirror has no 2.15 guide. Treat the ack-subject default as the only
  established fact.
- No release date is announced in anything read.

## Related

[[nats-server-2.14]] · [[account]] · [[ack-and-redelivery]] · [[upgrade-a-cluster]] ·
[[nats-server]]

## Sources

[[s-docs-upgrade-to-2.14]] · [[s-relnotes-2.14.0]]
