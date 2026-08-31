---
title: "nats-server v2.14.6 — object-store subjects cross a leafnode where KV subjects do not"
type: summary
area: [objectstore, topology, security, jetstream]
source-url: https://github.com/nats-io/nats-server/blob/v2.14.6/server/jetstream_api.go#L323
source-path: raw/nats-server-src/object-store-across-leafnode-observed-v2.14.6.md
author: nats-io/nats-server contributors (the binary); this wiki (the experiments)
article: "Four experiments on a hub/leaf pair with differing JetStream domains, v2.14.6"
date: 2026-08-31
version: "2.14.6"
tags: [objectstore, leafnode, jetstream-domain, denyAllClientJs, "$OBJ", "$O.", "$KV", deny]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# nats-server v2.14.6 — object-store subjects cross a leafnode where KV subjects do not

Found by reading the leafnode JetStream deny lists while landing the object-store chapter, and
settled by running it. The deny list names a subject prefix **the object store does not use**.

## Key claims

**The deny lists, at `server/jetstream_api.go:323–324`, v2.14.6:**

```go
var denyAllClientJs = []string{jsAllAPI, "$KV.>", "$OBJ.>"}
var denyAllJs = []string{jscAllSubj, raftAllSubj, jsAllAPI, "$KV.>", "$OBJ.>"}
```

with `"$OBJ.>": "$OBJ.>"` in the domain mapping table at `:347`.

**`$OBJ` is not the object store's subject space.** ADR-20, `learn/object-store/under-the-hood.md`
and the running server all use `$O.<bucket>.C.>` and `$O.<bucket>.M.>`
([[s-nats-server-object-store-observed]], [[s-docs-object-store-under-the-hood]]). `$OBJ` appears
**nowhere in the 861-page docs tree**. `$OBJ.>` is a literal first token; it does not match `$O.…`.

**Measured on a hub/leaf pair with domains `hub` and `leaf`, non-system account** — the branch that
logs `JetStream using domains: local "leaf", remote "hub"` and merges `denyAllClientJs` both ways:

| published on the leaf | reached the hub? |
|---|---|
| `plain.subject` | **yes** (ordinary account traffic) |
| `$KV.TEST.key1` | no — matches `$KV.>` |
| `$OBJ.TEST.thing` | no — matches `$OBJ.>` |
| **`$O.TEST.C.abc`** | **yes** |
| **`$O.TEST.M.abc`** | **yes** |

**The consequence is a silently mirrored bucket.** With an `OBJ_SHARED` bucket on *each* server in
the same account, one 600 KiB `nats object put` **on the leaf only** left both streams identical —
leaf `6 msgs / 615,040 bytes`, **hub `6 msgs / 615,040 bytes`** — and `nats object ls SHARED` on the
hub listed an object nobody put there, with both the chunk and the metadata subjects present. It is
a complete, gettable object on a server that was never asked to store it.

**The KV control, same servers, same account**: a `kv put` on the leaf left the hub's `KV_CONF` at
**0 msgs** and `nats kv get CONF k1` on the hub returned `nats: error: nats: key not found`.

**The connectivity control**: `nats pub demo.x` on the leaf reached a `demo.>` subscriber on the hub,
so the KV result is the deny list acting rather than a broken link.

## Practical takeaways

- **Two object-store buckets with the same name, in the same account, on either side of a leafnode
  with differing JetStream domains, converge.** KV buckets in the same position do not. Anyone who
  reasoned "KV and Object Store behave the same across a domain boundary" has it wrong for one of
  them.
- The mitigation available today is an explicit `deny` on the leafnode remote covering `$O.>`
  ([[leafnode]], [[subject-permissions]]) — or not reusing bucket names across a domain boundary.
- This is invisible from the leaf: the put succeeds normally and nothing is logged on either side.

## Notable quotes

From the source comment at `jetstream_api.go:330–337`, explaining the design but not the prefix:

> "For optics $KV and $OBJ where made to be independent subject spaces."

## Relevance to the wiki

[[object-store]] and [[jetstream-domain]] both describe domain isolation; neither could have said this,
because no public source states it. It is a leak with a data-integrity consequence, so it belongs on
the concept page, the leafnode page and the gotcha about streams across a leafnode.

**Whether it is a defect or an intended asymmetry is not established** — no public issue, discussion
or ADR read so far mentions `$OBJ` against `$O`, and the docs never state what happens to either store
across a domain boundary. Recorded as docs issue **#35** for the documentation gap, which is the part
that is unambiguous.

## Questions it answers

None in the bank yet; it adds one (Q105).

## Pages touched

[[object-store]] · [[leafnode]] · [[jetstream-domain]] · [[streams-not-visible-across-a-leafnode]]

## Sources

`raw/nats-server-src/object-store-across-leafnode-observed-v2.14.6.md` ·
`raw/nats-server-src/leafnode-js-domains-v2.14.6.md` ([[s-nats-server-leafnode-js-domains]])
