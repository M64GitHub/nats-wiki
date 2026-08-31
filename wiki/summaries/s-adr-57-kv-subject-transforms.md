---
title: "ADR-57 — KV subject transforms, sources and mirrors"
type: summary
area: [kv, jetstream]
source-url: https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-57.md
source-path: raw/adr/ADR-57.md
author: "@piotrpio"
article: ADR-57 KV Subject Transforms
date: 2025-12-09
version: ""
tags: [kv, mirror, sources, subject_transforms, mirror_direct, proposed]
aliases: [ADR-57]
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# ADR-57 — how a KV mirror or source is actually built

Status **Proposed** (2025-12-09), a refinement of ADR-8. It is a **client** specification — it says
what a client must put in the stream config when a user asks for a KV mirror or source — but every
rule in it shows up in `nats stream info KV_<bucket>`, which is why it is here.

## Key claims

### A KV mirror always gets `mirror_direct`

When `Mirror` is set on a `KeyValueConfig` the client must prefix the mirror's stream name with
`KV_` if it is not already, and **"always enable `MirrorDirect` on the underlying stream
configuration"**. So a KV mirror is expected to serve reads for the upstream bucket, joining its
Direct Get queue group once caught up — "automatically participate in RTT-based replica selection".
The `mirror_direct` alignment rules on [[mirrors-and-sources]] apply to it unchanged.

### A KV source gets a subject transform generated for it

Sources without explicit transforms are assumed to be KV buckets: the name is `KV_`-prefixed and a
transform `$KV.<source>.>` → `$KV.<bucket>.>` is generated, so keys land under the destination
bucket's own subject space. Sourcing `ORDERS` into `NEW_ORDERS` with a key filter `NEW.>` produces:

```json
{"sources": [{"name": "KV_ORDERS",
              "subject_transforms": [{"src": "$KV.ORDERS.NEW.>", "dest": "$KV.NEW_ORDERS.>"}]}]}
```

### Explicit transforms turn the automation off — and open two use cases

"When `SubjectTransforms` are explicitly provided … clients should preserve them exactly as
specified and skip automatic KV subject transform generation" — including **not** adding the `KV_`
prefix to the source name. That allows:

- **an ordinary stream as a KV source**: `EVENTS` with `events.processed.>` → `$KV.EVENT_CACHE.>`,
  making a KV bucket a materialised view of a stream;
- **custom key mapping between buckets**: `$KV.INVENTORY.warehouse.*.product.>` →
  `$KV.PRODUCTS.>`, so `warehouse.nyc.product.item123` becomes the key `item123`.

## Practical takeaways

- **A KV bucket whose stream shows `sources` with a `$KV.…` transform is a KV-to-KV source**; one
  whose transform starts anywhere else is being fed by a plain stream, deliberately.
- **A KV mirror with `mirror_direct: false` was not built by a conforming client** — or the upstream
  had `allow_direct: false` at create time and forced it, which is the alignment rule on
  [[mirrors-and-sources]].
- Because this is Proposed, **check the client** before assuming any of it: the wiki's rule is that
  a client's own repository is the authority for what it implements ([[nats-go]] and friends).

## Relevance to the wiki

Closes the ADR-57 item on [[key-value]]'s `## To verify` and explains the KV side of
[[mirrors-and-sources]].

## Questions it answers

None in `inbox/question-bank.md` directly; it is the spec behind "why does my KV mirror have
`mirror_direct` set".

## Pages touched

[[key-value]] · [[mirrors-and-sources]]
