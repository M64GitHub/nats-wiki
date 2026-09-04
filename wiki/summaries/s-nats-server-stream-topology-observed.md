---
title: "observed: stream topology on nats-server 2.14.6 — what a stream costs, what a thousand cost, what a filter costs, and the three ways to copy a stream"
type: summary
area: [jetstream, core, security, topology]
source-url: ""
source-path: raw/nats-server-src/stream-topology-observed-v2.14.6.md
author: maintainer
date: 2026-09-04
version: "nats-server 2.14.6; nats CLI 0.4.0"
article: "runs A, A2, R3, C, D, E, F (with F2–F5) — twelve scripts plus stream-topology-topolab.py, -snap.py and -limits.conf"
tags: [observed, stream-count, ha_assets, filtered-consumer, filter_subjects, max_streams, max_consumers, "10027", "10026", "10002", "10034", "10031", cardinality, "index.db", JSMaxSubjectDetails, mirror, source, "Nats-Stream-Source", registerNotification, SI-9]
aliases: []
sources: []
created: 2026-09-04
updated: 2026-09-04
---

# observed: stream topology on nats-server 2.14.6

Step 3 of `inbox/plan-stream-and-subject-design-2026-09-04.md`, for question-bank rows **108**, **109**,
**111** and **114**. The public answers to those rows give a *shape* — "it's rarely a good idea to have
stream per subject", "the server doesn't do like a table scan" — and no number anywhere; these runs put
numbers next to the shapes. One standalone server (`tools/lab/cluster.sh up 1`) for A, A2, C, E, F; the
three-node lab (`up 3`) for the R3 pass; a purpose-built two-account server for D.

**Every number here is one laptop** — Apple silicon, internal SSD, macOS, everything on one machine. They
are evidence of a *mechanism* and of a *ratio*, never of a limit or of a figure to size a cluster by. The
three-node numbers are worse than a real cluster's in one way (three servers sharing one CPU and one
disk) and better in another (no network), so treat them as an ordering only.

## Key claims

### A / B · what a stream costs, and what a thousand of them cost

- **One empty file stream is 3 directories and 3 files** — `meta.inf` 516 B, `meta.sum` 16 B,
  `msgs/1.blk` 0 B — **8 KiB** of allocated blocks, and **~53–58 KiB of RSS**. Both are linear: 1,000
  streams are 8,000 KiB and 75.1 MiB, 10,000 are 80,000 KiB and 534.2 MiB.
- **Creating streams at `R1` is cheap**: 1,592/s for the first thousand (P50 **0.6 ms**), 675/s for ten
  thousand (P50 1.2 ms, P90 2.8 ms, max 23.1 ms).
- **Many streams do not slow the publish path into one of them.** 20,000 × 128 B into the same stream
  with 1, 10, 100 and 1,000 streams on the server: **194,031 / 204,803 / 209,442 / 192,309 msg/s**.
- **The first message into a fresh stream costs ~4.4 ms.** 10,000 messages into 10,000 empty streams,
  one each, took **43.97 s** (227 msg/s); the same 10,000 messages into the same streams again took
  **0.36 s** (27,493 msg/s).
- **Spreading a volume over streams costs disk.** The same 100,000 × 128 B: **21,004 KiB** over 1,000
  streams against **16,708 KiB** in one stream with a tenant token — **1.26×**, 215 B against 171 B per
  message, and the difference is per-stream block slack.
- **Restart is where stream count is felt.** Clean stop: 1,001 streams / 280,000 msgs **125.19 ms** to
  start JetStream (`/healthz` 200 in 0.265 s); 10,000 empty streams **5.405 s**; 10,000 with one message
  each **5.762 s**. After SIGKILL, 10,000 streams printed **10,000** `Filestore [E…] Stream state
  outdated, last block has additional entries, will rebuild` warnings — one per stream — and still came
  back in 5.655 s.
- A clean shutdown writes an `index.db` **per stream**: 10,000 empty streams went from 30,000 files /
  80,000 KiB to **40,000 files / 120,000 KiB** across the stop.
- Deleting 10,000 streams took **3.02 s** and the store went to 0 KiB at once; **RSS did not fall**
  (665.8 MiB after) — the Go heap is returned on its own schedule.

### R3 · the same counts with replicas

- **A replicated stream creates two orders of magnitude slower**: P50 **107–112 ms** each against R1's
  0.6 ms — 100 in 10.18 s, 300 in 23.01 s, 1,000 in 80.85 s. It is the Raft group, not the stream.
- **`ha_assets` = streams + 1** (the meta group): 11, 101, 301, 1001 at 10, 100, 300, 1,000 streams. At
  `R1` it is **0** even with 10,000 streams — it counts replicated assets only.
- The meta layer's own store `$SYS/_js_/_meta_`: **36 KiB** at 10 streams, 156 KiB at 100, 476 KiB at
  300, **628 KiB** at 1,000.
- **A node holding 1,000 `R3` streams needs 17.985 s to come back** (`Took 329.47ms to start JetStream`
  plus 1,000 `Restored` lines — the rest is the Raft groups), and its SIGTERM shutdown **did not finish
  within 10 s**.

### C · filtered consumers on one stream

- **A filtered consumer over a sparse subject does not scan** — gh#3405 re-measured. One message on
  `big.needle.one` in the middle of 1,000,001: `CONSUMER.CREATE` **0.9 ms** with `num_pending` **1**,
  first message **2.3 ms** cold and 0.1 ms warm. `big.>` over the whole stream: 0.1 ms.
- A filter that matches nothing gives `num_pending` **0** and no error; the pull waits out its expiry and
  answers `NATS/1.0 408 Request Timeout`.
- **1 → 1,000 filtered consumers on one stream cost nothing at publish time**: 197,506 / 216,850 /
  218,176 / 211,130 / 199,888 msg/s at 1 / 10 / 100 / 300 / 1,000. `CONSUMER.INFO` on one of the
  thousand: 0.2 ms. A restart with 1,005 consumers on one stream: **300.80 ms**.
- `CONSUMER.LIST` is **4.7–4.9 ms and 145,202 bytes at both 305 and 1,005 consumers** — the response is
  paged (`limit` 256), so the list never grows past one page.
- **The public "~300" is about disjoint filters on *one* consumer, and it is a create-time cost.**
  `CONSUMER.CREATE` at 1 / 10 / 100 / 300 / 1,000 / 2,000 / 5,000 filters: 1.0 / 1.2 / 1.4 / **4.6** /
  **33.7** / 128.6 / **784.0 ms**. The **first fetch stays 0.2–0.4 ms at every count**, and the single
  wildcard covering all 1,000 costs **0.8 ms** to create.
- **The same 300-way fan-out, built both ways**, 300,000 × 128 B: *300 streams with one consumer each* —
  RSS 203.5 MiB, disk 64,800 KiB, ingest 127,068 msg/s. *One stream with 300 filtered consumers* — RSS
  **73.9 MiB**, disk **53,708 KiB**, ingest **194,513 msg/s**. So **2.75× the RSS and 1.5× less ingest**
  for the many-streams shape. Empty, before any message: 55.4 MiB / 6,000 KiB against 37.1 MiB /
  3,608 KiB.

### D · a tenant at its account limits

| limit | what the tenant sees |
|---|---|
| account `max_streams` | `10027 maximum number of streams reached` on `$JS.API.STREAM.CREATE` |
| account `max_consumers` | `10026 maximum consumers limit reached` |
| per-**stream** `max_consumers` | **the same `10026`** — the two are indistinguishable from the error |
| account `max_file` | `10002 resource limits exceeded for account`, returned as the **`PubAck`** of the publish that would cross it |

- **An account's `max_consumers` is enforced per *stream*, not per account.** With the account limit at
  2, `S1` took two consumers and `S2` took two more — four in the account. `nats account info` says so
  (*"Consumers: Maximum 2 per stream"*); the server counts `mset.numLimitableConsumers()` for the one
  stream (`consumer.go:1130–1137`; clustered, `jetstream_cluster.go:9587–9605`). Docs issue **#124**.
- The account stopped at **67,108,842 of 67,108,864 bytes** — 22 bytes of headroom — so the check
  reserves the record rather than filling to the byte.
- **The budget comes back immediately**: a `purge` freed the storage and the next publish was accepted;
  deleting a stream freed a `max_streams` slot and the fourth stream was created.

### E · subject cardinality, one axis at a time

The same stream, the same 1,000,000 × 128 B messages, the same subject *shape* (`c.%07d.evt`, 13 bytes);
only the number of distinct subjects changes, each scene from a purged lab.

| at 10 / 10,000 / 1,000,000 distinct subjects | |
|---|---|
| `index.db` after a clean stop | **738 / 170,549 / 17,000,550 bytes** against a predicted `Σ(len+4)` of 170 / 170,000 / 17,000,000 — exactly the arithmetic plus a **~550-byte header** |
| RSS with the stream filled | **50.0 / 78.0 / 294.0 MiB** ⇒ ~**256 B of RSS per subject** |
| `Took … to start JetStream`, clean stop | **130.8 / 178.1 / 421.2 ms** |
| the same after SIGKILL | **245.8 / 279.1 / 604.9 ms** |
| `nats stream subjects` | **0.01 / 0.04 / 5.40 s** |
| `STREAM.INFO` with `subjects_filter: >` | **0.2 ms / 1,150 B**, **2.3 ms / 200,927 B**, **372.7 ms / 1,800,931 B** |
| a consumer filtered on **one** subject | create 1.1 / 0.9 / **1.0 ms**, first message 2.5 / 1.5 / **3.3 ms** — flat |
| a consumer on the **wildcard** `c.*.evt` | create 1.1 → **18.6 ms**, first message 0.1 → **19.2 ms** |
| fill rate | 179,717 / 185,289 / 198,078 msg/s — cardinality did **not** slow the publish path |

At a million subjects `STREAM.INFO` returns **100,000** of them — `total 1000000, offset 0, limit 100000,
subjects returned 100000` — paged by `offset` (`JSMaxSubjectDetails`, `jetstream_api.go:435`).

So cardinality costs **RAM and the subject-listing API**, and a few hundred milliseconds of restart. It
does not cost publish throughput, and it does not cost a consumer filtered on **one** subject. What it
costs is the **wildcard** consumer, which went 170× on create and 190× on first message between 10 and a
million subjects.

### F · the three ways to make a second copy

- **A sourcing stream costs 1.38–1.57× a mirror on disk**, for the same messages: origin 33,408 KiB,
  mirror 33,408 KiB, **sourcing stream 46,192 KiB**. With a subject transform, 168.0 B/msg at the origin,
  **164.0** in the mirror, **263.9** in the source. The reason is a header on **every** message:
  `Nats-Stream-Source: ORIG 1 orig.*.evt from-orig.{{wildcard(1)}} orig.1.evt` — origin stream, origin
  sequence, the transform's source and destination, and the original subject.
- Catch-up on 200,000 × 128 B: a mirror in **0.521 s**, a sourcing stream in **0.652 s**; both then
  followed 20,000 more messages inside the poll interval.
- **What a mirror may not be**: it may not have subjects (`10034 stream mirrors can not contain
  subjects`, on create *and* on update) and may not also have sources (`10031 stream mirrors can not
  also contain other sources`). **What it may be**: filtered (`mirror.filter_subject`) and transformed
  (`mirror.subject_transforms: [{src, dest}]`).
- **What a sourcing stream may be**: filtered, transformed, given **its own subjects** and published to
  directly, and given several sources — including **two of the same stream with different filters**.
- **Neither copy follows a delete on the origin** (`STREAM.MSG.DELETE` on sequence 5 left the message in
  both), and **both survive the origin being deleted**, still readable.
- A mirror's and a source's internal consumers **do not** count against `max_consumers` and are not
  listed by `CONSUMER.NAMES`: the server counts `len(mset.consumers) - mset.sourcingConsumers`
  (`stream.go:8587`).
- **The third shape does not exist server-side.** A push consumer delivering to `copy2.evt`, with a
  second stream subscribed on `copy2.>`, delivered **0 of 1,000** messages and `num_pending` stayed at
  1,000; a plain `nats sub copy2.evt` released all 1,000 at once. Reproduced with no stream involved
  (`d.>` against `d.evt`): `Sublist.registerNotification` counts interest only for a subscription whose
  subject is **literally equal** to the deliver subject (`sublist.go:169–190`). Server issue **SI-9**.
- **The shape that does work** is a client: pull from the origin, publish into the copy — 1,000 messages
  in 0.01 s. The copy carries **no** origin header and gets its **own** sequence numbers.

### Three numbers read from the source, not from a run

For the claims Synadia's subject-hierarchy post makes ([[s-synadia-subject-hierarchies]]), read at tag
v2.14.6:

- **the "32-token stack array" is real** — `sublist.go:576`, `:662`, `:1343`, `:1441`, `:1449`, `:1664`
  all open with `tsa := [32]string{}`; `stree/stree.go:125` and `:143` do the same with `var raw
  [32][]byte` for a filter's wildcard-delimited parts. Beyond 32 the `append` escapes to the heap, on
  every match that misses the sublist cache.
- **the "256 characters" is not a limit** — there is none — but the number is not arbitrary either: the
  subject-tree walk carries the subject it is reconstructing in `var _pre [256]byte`
  (`stree/stree.go:127`, `:145`, `:154`, `:163`, `:491`).
- **`JSMaxSubjectDetails = 100_000`** (`jetstream_api.go:435`) is a **paging** limit on `STREAM.INFO`,
  not a cap on a stream's subjects.

Neither the 32 nor the 256 is enforced: exceeding them costs an allocation per operation, not a
rejection. The **"16 tokens" three public sources state appears nowhere in the server** (docs issues
#81, #82).

## Practical takeaways

- **Streams are cheap to create and expensive to restart.** The floor is 8 KiB and ~55 KiB of RSS, but
  10,000 of them are 5.4 s of startup at `R1` and 1,000 of them are 18 s at `R3`.
- **Replication, not the stream, is the unit of cost.** `R1` → `R3` is 0.6 ms → 110 ms per create and
  turns each stream into an HA asset.
- **Filtering is indexed, at every scale measured.** The expensive things are *many filters on one
  consumer* (create time) and *a wildcard consumer on a high-cardinality stream* (create and first
  fetch) — not the number of consumers and not the size of the stream.
- **One stream with N filtered consumers beats N streams with one consumer each** on every axis
  measured: RSS, disk and ingest.
- **Cardinality is a RAM and API budget**, ~256 B per subject here, and it makes `nats stream subjects`
  and `STREAM.INFO`'s subject list slow and paged long before it touches throughput.
- **A copy is a mirror or a source, and nothing else.** The consumer-made copy is not a server-side
  shape at all.

## Notable quotes

Not applicable — this is a run, not a written source. The log lines quoted above are the server's.

## Relevance to the wiki

The measured half of phase G1: the numbers behind [[subject-design]] and [[stream-topology-design]], and
the run evidence for [[retention-policies]]' choosing section and [[event-sourcing-on-jetstream]]. Also
the origin of docs issue **#124** and server issue **SI-9**.

## Questions it answers

Rows **108**, **109**, **111**, **114** — the cost half of each; row 9 (cardinality) in part.

## Pages touched

[[subject-design]] · [[stream-topology-design]] · [[stream]] · [[subjects-and-wildcards]] ·
[[filestore-layout]] · [[jetstream-sizing]] · [[jetstream-slows-as-consumers-grow]] ·
[[mirrors-and-sources]] · [[consumer]] · [[account]] · [[jetstream-recovery-is-slow]] ·
[[event-sourcing-on-jetstream]] · [[meta-layer]]
