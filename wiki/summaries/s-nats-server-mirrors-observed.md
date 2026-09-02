---
title: "Observed on nats-server v2.14.6 — mirrors on file and memory, catch-up under readers, an object bucket across two domains"
type: summary
area: [jetstream, kv, objectstore, topology]
source-path: raw/nats-server-src/mirrors-observed-v2.14.6.md
author: "this wiki, run locally (nats-server v2.14.6, nats CLI 0.4.0, nats.go v1.53.1 through the CLI)"
article: "three runs, 2026-09-02, through tools/lab/cluster.sh and the hub/leaf pair of object-store-across-leafnode-observed-v2.14.6.md"
date: 2026-09-02
version: "2.14.6"
tags: [mirror, kv, objectstore, filestore, memstore, filter_subject, catch-up, lag, leafnode, jetstream-domain, subject-transform, measured, JS_MIRROR, ingest-rate]
aliases: []
sources: []
created: 2026-09-02
updated: 2026-09-02
---

# Observed on v2.14.6 — the three mirror runs

Made for question-bank rows 76, 91 and 105 after reading the threads and the source
([[s-gh-8417-kv-mirror-file-vs-memory]], [[s-gh-8444-mirror-catchup-under-a-reader]],
[[s-issue-5106-object-store-mirror-list]], [[s-nats-server-mirror]]). One laptop, loopback; ratios
and mechanisms, never limits. The python client that fills, reads and polls is
`raw/nats-server-src/mirrorlab.py`.

## Run A — a KV bucket mirrored on file and on memory (`up 1`)

**The source**: `nats kv add DNS --history 1 --storage file`, 400,000 keys once and 2,000,000
overwrites on a hot 100,000 → **400,000 live messages over 2,400,000 sequences, 2,000,000 interior
deletes (83 %)**, gh#8417's ratio. The first fill published without waiting for acks and the server
dropped most of it — `[WRN] Dropping messages due to excessive stream ingest rate on '$G' > 'KV_DNS':
IPQ len limit reached`, 337,733 messages stored of 2,400,000 sent; the queue cap is 100,000 messages
/ 128 MB (`stream.go:441–442`). The second fill kept 4,000 publishes in flight and lost nothing
(~200,000 msg/s).

**Initial sync**: `nats kv add DNS_FILE --mirror DNS --storage file` reached `lag` 0 in **1.24 s**;
`--storage memory` in **0.74 s**. The consumer created on the source, from
`/jsz?…&direct-consumers=true&config=true`: `JS_MIRROR_<id>`, `filter: null`, `deliver_policy: all`,
`ack_policy: none`, `ack_wait` 79200000000000 (22 h), `max_deliver: 1`, `idle_heartbeat` 1 s,
`flow_control: true`, `direct: true`, `sourcing: true`, `inactive_threshold` 10 s, metadata
`_nats.mirror.stream` / `_nats.mirror.acc` / `_nats.req.level`. `nats consumer ls KV_DNS` → `No
Consumers defined`. It delivered **400,000** messages (`consumer_seq`) against `stream_seq`
3,140,054 — the mirror fills the holes itself. On disk the source held 51 files / 128,220 KB for the
data the mirror held in 29 files / 58,536 KB.

**Reads**, Go client (`nats bench js consume`, batch 500, ack none, deliver all, 400,000 msgs):

| consumer | store | filter | msg/s |
|---|---|---|---:|
| on the **file** mirror | file | `$KV.DNS.>` | **267,866** |
| on the file mirror | file | none | **1,740,462** |
| on the memory mirror | memory | `$KV.DNS.>` | 1,541,157 |
| on the memory mirror | memory | none | 1,463,983 |
| on the **source** | file | `$KV.DNS.>` | 1,563,531 |

**6.5× on the file mirror only.** The thread's `deliver last-per-subject` variant, python client:
file 234,632 msg/s, memory 769,470 msg/s.

**The CLI on a same-domain mirror by its own name finds nothing**: `nats kv ls DNS_FILE` → `No keys
found in bucket`; `nats kv get DNS_FILE k0000001` → `nats: error: nats: key not found`; the trace
shows `$JS.API.DIRECT.GET.KV_DNS_FILE.$KV.DNS_FILE.k0000001` — the mirror holds `$KV.DNS.>`
([[s-nats-go-kv-object-mirror]]). A mirror hand-built with `$KV.DNS.>` → `$KV.DNS_TR.>` is readable
(`kv get DNS_TR` works, `kv ls DNS_TR` = 400,000 keys) and its listing takes **1.533 s against
0.427 s** on the source — the listing consumer is a push `last_per_subject`, `headers_only`
consumer filtered on `$KV.<bucket>.>`, the slow path on a file mirror.

## Run B — catch-up alone and under readers

Forms B1 and B2 (a python scanner that turned out to read nothing) give baselines only. **B3**, the
gh#8444 shape on a fresh server — **1,000,000 keys, 300,000 hot, 3,000,000 overwrites: 1 M live over
4 M sequences, 75 % holes** — with three parallel loops of `nats bench js ordered --stream
KV_DNS_<x> --msgs 1000000` as readers:

| store | alone | with three readers | ratio |
|---|---:|---:|---:|
| file mirror | 2.54–2.64 s | **8.87–10.11 s** | **3.4–3.9×** |
| memory mirror | 1.07–1.09 s | **3.31–3.72 s** | **3.1–3.4×** |

The readers ran at ~100,000 msg/s each while trailing the file mirror's catch-up and ~530,000 on
the cold scan after it. gh#8444 saw 2.89× with one reader; here the memory store pays a similar
ratio, so the effect is not specific to the file store's lock on this host. At this scale the
row-76 read ratio grew to **9.4×** (174,117 against 1,639,966 msg/s). After five delete/recreate
cycles per mirror the source carried exactly the two live `JS_MIRROR_` consumers — no leftovers.

## Run C — an object bucket on the leaf, mirrored into the hub (domains `leaf` / `hub`)

1. **No mirror**: the hub sees nothing of the leaf's bucket (`No Object Store buckets found`,
   `nats: error: nats: bucket not found`).
2. **Mirror without a transform** (`{"mirror":{"name":"OBJ_dms","external":{"api":"$JS.leaf.API"}}}`):
   syncs (24 msgs); `nats object ls` lists `dms_mirror` at 2.4 MiB; `nats object ls dms_mirror` →
   **`No entries found`**; `object get` → `nats: error: nats: object not found`. The trace shows the
   client binding by name (`$JS.API.STREAM.INFO.OBJ_dms_mirror`) and then reading
   `$O.dms_mirror.M.>`, which the mirror does not hold. `STREAM.NAMES` by subject returns
   `streams: null` for both prefixes.
3. **With `$O.dms.> → $O.dms_mirror.>`**: list, info, a byte-identical `get`, and a fourth object
   put on the leaf visible on the hub within 2 s.
4. **A put against the mirror bucket**: `nats: error: nats: no response from stream`; nothing stored.
5. `nats object add` has no `--mirror`; `nats kv add CFG_M --mirror CFG --mirror-domain leaf` builds
   a KV mirror across the same boundary that is readable by its own name at once (the client
   rewrites the read prefix to the origin's for an `external` mirror:
   `$JS.API.DIRECT.GET.KV_CFG_M.$KV.CFG.k1`).

## Practical takeaways

- Leave the filter off a consumer that reads a whole mirror; the origin does not care, a file
  mirror does.
- Start readers on a mirror after `lag` reaches 0.
- A mirrored object bucket needs the transform; a same-domain KV mirror needs it too if you mean to
  address it by name; a cross-domain KV mirror does not.
- Never flood a stream without acks; the drop is one `[WRN]` line.

## Questions it answers

- **Q76**, **Q91**, **Q105** — the measured halves of each.

## Pages touched

[[mirrors-and-sources]] · [[key-value]] · [[object-store]] · [[filestore-layout]] ·
[[consumer-slow-on-a-sparse-stream]] · [[cross-domain-sourcing]] · [[object-store-list-is-slow]] ·
[[publishing]] · [[nats-cli]] · [[nats-go]]
