---
title: nats-server 2.15 (preview)
type: entity
kind: release
area: [deploy, jetstream, security]
since: [2.15]
verified-against: nats-server 2.14.6
verified-on: 2026-08-31
tags: [release, 2.15, preview, js_ack_fc_v2, acl-migration, sources.db, js_snapshot_sources, recovery]
aliases: ["2.15", v2.15, "v2.15.0-preview.1"]
sources: [s-docs-upgrade-to-2.14, s-relnotes-2.14.0, s-nats-server-filestore-recovery, s-gh-8001-jetstream-startup-slow-50m, s-nats-server-stream-scale-observed]
created: 2026-08-31
updated: 2026-09-03
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

## The source index: `sources.db`

The preview's one storage change that an operator will notice. On 2.10–2.14 a stream with `sources`
scans itself backwards at every start and every leader change to find the last sequence it received
from each source, reading the whole stream whenever a source is idle or empty; the public report
of a 6 min 38 s restore after a clean shutdown is that scan ([[jetstream-recovery-is-slow]]; source:
[[s-gh-8001-jetstream-startup-slow-50m]]). PR #8282 (merged 2026-08-20) indexes the sourced
sequences as messages arrive and writes them to **`sources.db` at the stream's root** — next to
`meta.inf`, not under `msgs/`, "since it should not be removed if the stream is purged"; PR #8516
(2026-08-28) drops the stream-level scan altogether so that empty sources are indexed too. The
release note for `v2.15.0-preview.1`: *"Stream source indexing (#8282) — Restarts and leader changes
previously required expensive backward scans through the stream to find the last sourced indices.
These are now persisted in an index for instant lookup."* Replicated streams need
`feature_flags { js_snapshot_sources: true }` for the index to travel in stream snapshots; the PR
says that can become the default in 2.16 (source: [[s-nats-server-filestore-recovery]]). Measured on
2.14.6 for the before picture: 2.57 s to restore a 1.6 GB sourcing stream with one empty source, 23 ms
without it (source: [[s-nats-server-stream-scale-observed]]). Also in the preview: publishing a
message that carries the `Nats-Stream-Source` header directly is rejected.


## To verify

- **Beyond the ack-subject default and the source index, nothing about 2.15 is known from an ingested
  source.** The preview's release body has been read for its recovery lines only (the metalayer
  rescue endpoint `$JS.API.META.RESCUE` is mentioned there and not yet on any page); the docs mirror
  has no 2.15 guide.
- No release date is announced in anything read.

## Related

[[nats-server-2.14]] · [[account]] · [[ack-and-redelivery]] · [[upgrade-a-cluster]] ·
[[nats-server]]

## Sources

[[s-docs-upgrade-to-2.14]] · [[s-relnotes-2.14.0]] · [[s-nats-server-filestore-recovery]] · [[s-gh-8001-jetstream-startup-slow-50m]] · [[s-nats-server-stream-scale-observed]]
