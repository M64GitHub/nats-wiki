---
title: "Reading a mirror is slow on file storage"
type: gotcha
area: [jetstream, kv]
since: [2.10]
verified-against: nats-server 2.14.6
verified-on: 2026-09-02
tags: [mirror, filestore, filter_subject, interior-deletes, sparse-stream, kv, catch-up, lag, last_per_subject, measured]
aliases: ["KV mirror slow on file storage", "file store slower than memory store", "consumer slow on a mirror", "mirror sync slow while consumers read", "mirror catch-up slow", "sparse stream slow reads", "consumer-slow-on-a-sparse-stream"]
sources: [s-gh-8417-kv-mirror-file-vs-memory, s-gh-8444-mirror-catchup-under-a-reader, s-nats-server-mirror, s-nats-server-mirrors-observed, s-relnotes-2.14.4, s-nats-go-kv-object-mirror, s-nats-server-filestore-recovery]
created: 2026-09-02
updated: 2026-09-03
---

# Reading a mirror is slow on file storage

A consumer that reads a **mirror** — most often a mirrored KV bucket — crawls at a few thousand
messages a second on file storage while the same consumer on a memory mirror, or on the origin,
reads hundreds of thousands. Disk is idle, the page cache is warm, one core is busy. A close relative:
the mirror's own catch-up (`Lag` falling to 0) takes several times longer while consumers are
reading it.

## Symptom

From the public report, nats-server 2.14.2 (source: [[s-gh-8417-kv-mirror-file-vs-memory]]): one
pull consumer, `deliver last-per-subject`, `ack none`, `filter_subject: "$KV.DNS.>"`, on two mirrors
of the same bucket that differ only in `storage`:

```
memory mirror:  Initial snapshot complete: 2,019,878 msgs in 7.57 s — 266,840 msg/s
file mirror:    [  2.0s] total=11489  cur=5744 msg/s … [ 18.0s] total=75967  cur=4844 msg/s
```

`nats stream info` on the stream being read shows the shape that triggers it — far more sequences
than messages:

```
Messages:          2,019,878
Last Sequence:     11,920,111
Deleted Messages:  9,900,233
Subjects:          2,019,878
```

`iostat` at `%util 0.00–0.30`, ~100–120 % of one core across two or three server threads, the box
98 % idle. Pre-warming the page cache changes nothing.

## Quick triage

```
nats stream info <mirror> --json | jq '{subjects: .config.subjects, storage: .config.storage, mirror: .config.mirror.name,
                                         msgs: .state.messages, span: (.state.last_seq - .state.first_seq + 1), deleted: .state.num_deleted}'
nats consumer info <mirror> <consumer> --json | jq '.config | {filter_subject, filter_subjects, deliver_policy}'
nats stream info <mirror> --json | jq '.mirror | {lag, active}'
```

If `subjects` is `null` (it is, on any mirror), `filter_subject` matches the whole stream, and
`deleted` is a multiple of `msgs`, it is cause 1. If `lag` is still above 0 while the reads run,
cause 2 is stacked on top.

## Causes, ranked

### 1 · A consumer filter that matches everything, on a mirror

**The trap.** A KV client, `nats kv ls`, a KV watch, or a hand-written consumer passes
`filter_subject: $KV.<bucket>.>` because that is "the bucket". On the bucket's **own** stream that
filter is harmless: the stream's single subject *is* the filter, and the file store's
`firstMatching` takes the linear scan (`doLinearScan := isAll || (wc && len(subjs) == 1 &&
subjs[0] == filter)`, `filestore.go:3095` at 2.14.6). On a **mirror** the stream has no subjects, so
that test fails and the fallback compares four times the block's subject count with its **sequence
range, holes included** (`mb.fss.Size()*4 > int(lseq-fseq)`, line 3101). A stream whose sequence
space is mostly interior deletes fails that too, and every message lookup becomes a walk of the
block's per-subject state — "an expensive read through `mb.fss` … with doesn't allow to skip ahead
since the filter matches everything, so it's wasted additional work for every message" (sources:
[[s-gh-8417-kv-mirror-file-vs-memory]], [[s-nats-server-mirror]]). The memory store has no such
heuristic, which is why it is only the file mirror that suffers.

**How to confirm.** Create the same consumer with **no filter** and read it. Measured on 2.14.6, the
Go client reading 400,000 messages from a mirror with 83 % holes (source:
[[s-nats-server-mirrors-observed]]):

| consumer | store | filter | msg/s |
|---|---|---|---:|
| on the file mirror | file | `$KV.DNS.>` | **267,866** |
| on the file mirror | file | none | **1,740,462** |
| on the memory mirror | memory | `$KV.DNS.>` | 1,541,157 |
| on the memory mirror | memory | none | 1,463,983 |
| on the origin bucket | file | `$KV.DNS.>` | 1,563,531 |

6.5× at 400,000 subjects over 2.4 M sequences; **9.4×** at 1,000,000 over 4 M; the report saw
**65×** at 2 M over 12 M on 2.14.2 with a leafnode in between. The ratio grows with the hole ratio
and with the subject count, and it is 1× on the memory mirror and on the origin. The maintainer's
own test was the same: without the filter the reporter's file mirror went from ~4,000 to
150,000+ msg/s.

**The fix.**

- **Leave the filter empty** when you mean "everything". A mirror holds nothing but the mirrored
  subjects.
- **Read the origin bucket's name, not the mirror's.** With `mirror_direct` on (every KV mirror has
  it) a direct get for the origin's subjects is served by the nearest mirror anyway
  ([[direct-get]]); a same-domain KV mirror is not even readable by its own name without a
  hand-added transform ([[key-value]], source: [[s-nats-go-kv-object-mirror]]).
- **Put the hot-read mirror on memory storage** and keep the authoritative bucket on file — the
  pattern the reporter already ran. A memory mirror is lost on restart and re-synced from the
  origin, which is acceptable for a read replica and not for a copy you keep.
- What does not help: `sync_interval`, compression, block size, cache expiry. None of them touches
  the heuristic (source: [[s-gh-8417-kv-mirror-file-vs-memory]]).

Note the collateral: **`nats kv ls` on a file mirror** uses a `last_per_subject`, `headers_only`
push consumer filtered on `$KV.<bucket>.>` — this exact path. Measured 1.533 s against 0.427 s on the
origin for 400,000 keys (source: [[s-nats-server-mirrors-observed]]).

### 2 · Readers scanning the mirror while it is still catching up

**The trap.** The mirror is created (or re-created after a failure) and consumers start reading it
at once, from the head. Each read holds the store's read lock for a whole `LoadNextMsg` walk; on a
sparse upstream the mirror's own writes take the exclusive lock **twice per live message** — once in
`SkipMsgs` to record the gap the upstream's deletes left, once in `StoreMsg` — and Go's `RWMutex`
is writer-preferring (sources: [[s-gh-8444-mirror-catchup-under-a-reader]],
[[s-nats-server-mirror]]). That is the one public analysis; **no maintainer has answered the thread**
as of 2026-09-02.

**How to confirm.** `nats stream info <mirror>` while the readers run: `Lag` above 0 and falling
slowly. Stop the readers and watch it fall faster. The public report measured **14.2 s alone,
41.0 s with one cold-scanning consumer (2.89×)** on 2.14.2. On 2.14.6 with three Go readers
(source: [[s-nats-server-mirrors-observed]]):

| store | alone | with three readers |
|---|---:|---:|
| file mirror, 1 M live over 4 M sequences | 2.5–2.6 s | **8.9–10.1 s (3.4–3.9×)** |
| memory mirror, same data | 1.1 s | **3.3–3.7 s (3.1–3.4×)** |

The memory mirror pays a similar ratio, so on that host it is not only the file store's lock.

**The fix.** Gate the readers on `mirror.lag == 0` (poll `$JS.API.STREAM.INFO.<mirror>`; the
`Lag` field of `nats stream info`), and reuse one consumer rather than creating an ephemeral one
per scan round — each creation is its own I/O and locking. No `jetstream {}`, stream or consumer
setting narrows the lock.

### 3 · Interior deletes on a server older than 2.14.4

**The trap.** Every KV overwrite leaves a hole; a block never starts with one, but keeps every
interior hole in its delete map until the block is compacted (source:
[[s-gh-8417-kv-mirror-file-vs-memory]]). Before 2.14.4 the lookups in that map were slower and held
locks longer.

**How to confirm.** `nats-server --version` below 2.14.4, and `num_deleted` a multiple of `messages`.

**The fix.** Upgrade. v2.14.4 (2026-07-30): "Calculating and looking up sequences in delete maps for
file-backed streams with large numbers of interior deletes is now faster and holds locks for less
time (#8403)", plus faster AVL sequence sets (#8406) and snapshot encoding (#8405); v2.14.2 fixed the
per-subject state for `max_msgs_per_subject: 1` (#8254) (source: [[s-relnotes-2.14.4]]). This does
**not** change cause 1: the heuristic is the same at 2.14.6, and the 6.5× above was measured there.

### 4 · More than a million subjects: the block skip is switched off

**The trap.** A filtered read normally intersects the per-subject index to jump past blocks that
cannot contain a match (`checkSkipFirstBlock` / `checkSkipFirstBlockMulti`). Above
`highCardinalityThreshold` — 1,000,000 subjects — the server does not attempt it and walks forward
block by block (`filestore.go:3519–3521`, `3544–3546` at 2.14.6), because intersecting a
million-entry index on every read cost more than the skip saved: the maintainers' benchmark had the
check at 173 µs with 1,000 subjects and 184 ms with 2,000,000. Since **v2.14.2 / v2.12.10** (#8227);
before those releases the same stream could pin a core in the check itself (source:
[[s-nats-server-filestore-recovery]]).

**How to confirm.** `nats stream info` → `Number of Subjects` above a million on the stream being
read; the reader is slow on a *sparse* filter (few matching blocks far apart) rather than on the
everything-matching one of cause 1.

**The fix.** Narrow filters do not help here; fewer subjects per stream do ([[jetstream-sizing]]),
or a mirror that holds only the subset being read.

### 5 · What it is not

The report ruled these out with numbers, and they are the first things people suspect: **disk**
(idle), **page cache** (warm), **block fragmentation** (the mirror re-packs to 98 % live bytes and
is just as slow), **`DeliverLastPerSubject`** (with `max_msgs_per_subject: 1` the server takes a
sequential fast path). And the **initial sync** being slow on file storage — the second half of the
public report — was never explained upstream and did not reproduce here: 400,000 live messages over
2.4 M sequences synced in 1.24 s on file and 0.74 s on memory (sources:
[[s-gh-8417-kv-mirror-file-vs-memory]], [[s-nats-server-mirrors-observed]]).

## Prevention

- Design consumers on a mirror without a filter unless they really select a subset.
- Address reads to the origin bucket and let `mirror_direct` pick the replica.
- Bring readers up after `Lag` reaches 0, and make that part of the mirror's runbook.
- Keep sparse file streams on 2.14.4 or later.
- Keep the hot key space of a KV bucket in mind when sizing: the sequence span, not the message
  count, is what the read path scans ([[filestore-layout]]).

## Explained by

[[filestore-layout]] — interior deletes, the delete map, and the linear-scan heuristic.
[[mirrors-and-sources]] — how a mirror catches up: the consumer, the gap → `skipMsgs`, `Lag`.

## Related

[[key-value]] · [[mirrors-and-sources]] · [[filestore-layout]] · [[direct-get]] · [[consumer]] ·
[[jetstream-slows-as-consumers-grow]] · [[nats-server-2.14]] · [[object-store]] · [[jetstream-recovery-is-slow]]

## Sources

[[s-gh-8417-kv-mirror-file-vs-memory]] · [[s-gh-8444-mirror-catchup-under-a-reader]] ·
[[s-nats-server-mirror]] · [[s-nats-server-mirrors-observed]] · [[s-relnotes-2.14.4]] ·
[[s-nats-go-kv-object-mirror]] · [[s-nats-server-filestore-recovery]]
