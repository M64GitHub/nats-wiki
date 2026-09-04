<!-- source: run locally against nats-server v2.14.6 (`nats-server --version` -> v2.14.6) and nats CLI
     0.4.0 · observed 2026-09-04 · scripts, commands and output verbatim below; the lab directory
     (tools/lab/cluster.sh's `${TMPDIR}/nats-lab`) is shortened to <lab>. The run scripts are
     `stream-topology-run{A,A2,C,D,D2,R3,E,F,F2,F3,F4,F5}.sh` in this directory with
     `stream-topology-topolab.py`, `stream-topology-snap.py` and `stream-topology-limits.conf`.
     Three transcripts (`runA3`, `runD3`, `runF5b`) are of command blocks typed at the shell rather
     than of a script, and each says at its head what it was and why it was needed.
     Where a transcript contained a traceback from the run script's *own* python helper, that
     traceback is replaced by a one-line note; nothing the server or the CLI printed is edited.
     Two readings in the transcripts are artefacts of the harness, not of the server, and are
     labelled where they appear: `cluster.sh stop k` (and `stop k -9`) returns before the process
     has released its ports, so the `start` that follows can be refused and the poll that follows
     *that* measures the harness, not a restart (run A2 B5, run R3 R6). Both were re-run by hand and
     the re-runs are the numbers quoted. -->

# Observed on nats-server v2.14.6 — what a stream costs, what a thousand of them cost, what a filtered consumer costs, and the three ways to copy a stream

Runs A–F of step 3 of `inbox/plan-stream-and-subject-design-2026-09-04.md` (question-bank rows
**108**, **109**, **111**, **114**), made after ingesting the six discussions in step 2
(`raw/gh-discussions/gh-6100.md`, `gh-4170.md`, `gh-4499.md`, `gh-3405.md`, `gh-6571.md`,
`gh-3772.md`) and Synadia's subject-hierarchy post
(`raw/synadia-blog/designing-nats-subject-hierarchies.txt`). Those sources answer rows 108, 111 and
114 with a *shape* — "it's rarely a good idea to have stream per subject", "the server doesn't do
like a table scan", "it's not because a stream is larger that delivery takes longer" — and with no
number anywhere. These runs put numbers next to the shapes.

One standalone server through `bash tools/lab/cluster.sh up 1` (`127.0.0.1:4291`, monitoring `8291`)
for runs A, A2, C, E, F; the three-node cluster `east` through `up 3` for the R3 run; a purpose-built
two-account server on `4321` (`stream-topology-limits.conf`) for run D. Apple silicon, an internal
SSD, macOS, everything on one machine — **so every number here is one laptop.** They are evidence of
a *mechanism* and of a *ratio* — what grows with what, which shape is cheaper than which, where a
cost stops being linear — never of a limit or of a figure to size a production cluster by. The
three-node numbers are worse than a real cluster's in one way (three servers sharing one CPU and one
disk) and better in another (no network), so treat them only as an ordering.

- **Run A / B** — row 108: what one empty stream costs, then 10, 100, 1,000 and 10,000 of them; the
  publish rate into one stream at each count; the same 100,000 messages spread over 1,000 streams
  against one stream with a tenant token; the restart at each count, clean and after SIGKILL.
- **Run R3** — row 108 with replicas: the same counts at `R3` on the three-node lab, the meta layer's
  `ha_assets` and `_meta_` directory, and a node restart at 1,000 replicated streams.
- **Run C** — row 111: the sparse seek gh#3405 claims is indexed, measured; 1 → 1,000 filtered
  consumers on one stream; 1 → 5,000 disjoint filters on *one* consumer; and the same 300-way
  fan-out built both ways.
- **Run D** — row 108's tenancy half: what a tenant sees at `max_streams`, `max_consumers` and
  `max_file`, with the exact code and message, and which of those limits is per account and which is
  per stream.
- **Run E** — row 109: the same 1,000,000 messages over 10, 10,000 and 1,000,000 subjects, and
  nothing else changed.
- **Run F** — row 114: a mirror, a sourcing stream and a consumer-made copy of the same stream, what
  each costs and what each can and cannot be configured to do.

## What the runs settled, in one table

| question | measured | where |
|---|---|---|
| one empty file stream on disk | **3 directories and 3 files** — `meta.inf` 516 B, `meta.sum` 16 B, `msgs/1.blk` 0 B — which is **8 KiB** of allocated blocks; 1,000 empty streams are 8,000 KiB and 10,000 are 80,000 KiB, exactly linear | A1, B1, B2 |
| one empty file stream in memory | ~**53–58 KiB** of RSS: 18.0 → 75.1 MiB for 1,000 streams, 18.0 → 534.2 MiB for 10,000 | B1, B2 |
| creating streams at `R1` | **1,592/s** for the first thousand (P50 **0.6 ms**), **675/s** for ten thousand (P50 1.2 ms, P90 2.8 ms, max 23.1 ms) | B1, B2 |
| creating streams at `R3` | **P50 107–112 ms each** — 100 in 10.18 s, 300 in 23.01 s, 1,000 in 80.85 s. Two orders of magnitude slower than `R1`, and it is the Raft group, not the stream | R2, R4, R5 |
| does having many streams slow the publish path into one of them | **No.** 20,000 × 128 B into `T00001` with 1, 10, 100 and 1,000 streams on the server: 194,031 / 204,803 / 209,442 / 192,309 msg/s | A1c–A4 |
| the **first** message into a fresh stream | ~**4.4 ms** — 10,000 messages into 10,000 empty streams (one each) took **43.97 s** (227 msg/s); the same 10,000 messages into the same streams again took **0.36 s** (27,493 msg/s) | B4, B5 |
| the same 100,000 × 128 B messages, 1,000 streams against one stream with a tenant token | **21,004 KiB** spread over 1,000 streams against **16,708 KiB** in one stream — **1.26×**, 215 B against 171 B per message, the difference being per-stream block slack | A5, A6 |
| restart, clean stop | 1,001 streams / 280,000 msgs: **125.19 ms** to start JetStream, `/healthz` 200 in 0.265 s. 10,000 empty streams: **5.405 s**. 10,000 streams with one message each: **5.762 s**. One stream, 1.1 M messages, 1,005 consumers: **300.80 ms** | A7, B3, B4, C2c |
| restart after SIGKILL | 10,000 streams, one write each since the last clean stop: **5.655 s**, and **10,000** `Filestore [E…] Stream state outdated, last block has additional entries, will rebuild` warnings — one per stream | B5 |
| a clean shutdown writes an `index.db` per stream | 10,000 empty streams: 30,000 files / 80,000 KiB before the stop, **40,000 files / 120,000 KiB** after | B2, B3 |
| deleting 10,000 streams | **3.02 s**, and the store goes to 0 KiB immediately; **RSS does not fall** (665.8 MiB after) — the Go heap is returned to the OS on its own schedule | B6 |
| `ha_assets` at `R1` | **0**, with 10,000 streams. It counts replicated assets only | B2 |
| `ha_assets` at `R3` | **streams + 1** (the meta group): 11, 101, 301, 1001 for 10, 100, 300, 1,000 streams | R1–R5 |
| the meta layer's own store | `$SYS/_js_/_meta_` on n1: **36 KiB** at 10 streams, **156 KiB** at 100, **476 KiB** at 300, **628 KiB** at 1,000 | R1–R5 |
| a node restart at 1,000 `R3` streams | `/healthz` 200 in **17.985 s** (`Took 329.47ms to start JetStream`, 1,000 `Restored` lines — the rest is the Raft groups). And its **SIGTERM shutdown did not finish within 10 s** | R6 |
| **a filtered consumer over a sparse subject does not scan** (gh#3405, re-measured) | one message on `big.needle.one` in the middle of 1,000,001: `CONSUMER.CREATE` **0.9 ms** with `num_pending` **1**, first message **2.3 ms** cold and **0.1 ms** warm. `big.>` over the whole stream: **0.1 ms** | C1b |
| a filter that matches nothing | `num_pending` **0**, no error — the pull simply waits out its expiry and answers `NATS/1.0 408 Request Timeout` | C1b |
| 1 → 1,000 filtered consumers on one stream | publish rate flat: 197,506 / 216,850 / 218,176 / 211,130 / 199,888 msg/s at 1 / 10 / 100 / 300 / 1,000. `CONSUMER.INFO` on one of the thousand: **0.2 ms** | C2, C2b |
| `CONSUMER.LIST` at 1,000 consumers | **4.7–4.9 ms and 145,202 bytes at both 305 and 1,005 consumers** — the response is paged (`limit` 256), so the list never grows past one page | C2, C2b |
| 1 → 5,000 **disjoint filters on one consumer** | `CONSUMER.CREATE`: 1.0 / 1.2 / 1.4 / **4.6** / **33.7** / **128.6** / **784.0 ms** at 1 / 10 / 100 / 300 / 1,000 / 2,000 / 5,000 filters. The **first fetch stays 0.2–0.4 ms** at every count, and the wildcard that covers all 1,000 costs **0.8 ms** to create. The cost of many filters is in *creating* the consumer, not in reading from it | C3 |
| the same 300-way fan-out, both ways, with 300,000 × 128 B | **300 streams with one consumer each**: RSS 203.5 MiB, disk 64,800 KiB, ingest 127,068 msg/s. **One stream with 300 filtered consumers**: RSS **73.9 MiB**, disk **53,708 KiB**, ingest **194,513 msg/s**. Empty, before any message: 55.4 MiB / 6,000 KiB against 37.1 MiB / 3,608 KiB | C4, C4b |
| account `max_streams` exceeded | `10027 maximum number of streams reached`, HTTP-equivalent code 400, on `$JS.API.STREAM.CREATE` | D1 |
| account `max_consumers` exceeded | `10026 maximum consumers limit reached` | D2 |
| per-**stream** `max_consumers` exceeded | **the same `10026 maximum consumers limit reached`** — the two limits are indistinguishable from the error | D3 |
| is an account's `max_consumers` per account or per stream | **per stream.** With the account limit at 2, `S1` took two consumers and `S2` took two more — four in the account. `nats account info` says so: *"Consumers: Maximum 2 per stream"*. The server counts `mset.numLimitableConsumers()` for the one stream (`consumer.go:1130-1137`; clustered, `jetstream_cluster.go:9587-9605`) | D2, D11 |
| account `max_file` exceeded | `10002 resource limits exceeded for account`, returned as the `PubAck` of the publish that would cross it. The account stopped at **67,108,842 of 67,108,864 bytes** — 22 bytes of headroom — and every further publish was refused, so the check reserves the record, it does not fill to the byte | D4, D8 |
| does the budget come back | **Yes, immediately.** A `purge` freed the storage and the next publish was accepted; deleting a stream freed a `max_streams` slot and the fourth stream was created | D9, D10 |
| **subject cardinality: `index.db`** | exactly **Σ(len(subject) + 4) plus a ~550-byte header**. 10 / 10,000 / 1,000,000 subjects of 13 bytes: **738**, **170,549**, **17,000,550** bytes against a predicted 170, 170,000, 17,000,000 | E1–E3 |
| subject cardinality: RSS | the same 1,000,000 × 128 B messages: **50.0 / 78.0 / 294.0 MiB** at 10 / 10,000 / 1,000,000 subjects ⇒ ~**256 B of RSS per subject** | E1–E3 |
| subject cardinality: restart | **130.8 / 178.1 / 421.2 ms** clean, **245.8 / 279.1 / 604.9 ms** after SIGKILL. Cardinality costs a few hundred milliseconds, not minutes | E1–E3 |
| subject cardinality: reading the subject list | `nats stream subjects`: **0.01 / 0.04 / 5.40 s**. `STREAM.INFO` with `subjects_filter`: **0.2 ms / 1,150 B**, **2.3 ms / 200,927 B**, **372.7 ms / 1,800,931 B** — and at a million subjects it returns **100,000 of them**, `limit: 100000`, paged by `offset` (`JSMaxSubjectDetails`, `jetstream_api.go:435`) | E1–E3 |
| subject cardinality: what it costs a *consumer* | a filter on **one** subject stays cheap at a million subjects (create 1.0 ms, `num_pending` 1, first message 3.3 ms). The **wildcard** `c.*.evt` goes from create 1.1 ms / first 0.1 ms at 10 subjects to create **18.6 ms** / first **19.2 ms** at a million | E1, E3 |
| mirror against source: catch-up | 200,000 × 128 B: a mirror caught up in **0.521 s**, a sourcing stream in **0.652 s**; both then followed 20,000 more messages inside the poll interval | F2, F3, F5 |
| mirror against source: **disk** | the same messages: origin 33,408 KiB, mirror 33,408 KiB, **sourcing stream 46,192 KiB — 1.38×**. With a subject transform: 168.0 B/msg at the origin, **164.0** in the mirror, **263.9 in the source — 1.57×** | F3, J2 |
| why the sourcing stream is bigger | it stores an origin header on **every** message: `Nats-Stream-Source: ORIG 1 orig.*.evt from-orig.{{wildcard(1)}} orig.1.evt` — origin stream, origin sequence, the transform's source and destination, and the original subject | J1 |
| what a mirror may not be | a mirror **may not have subjects** (`10034 stream mirrors can not contain subjects`, on create *and* on update) and **may not also have sources** (`10031 stream mirrors can not also contain other sources`) | I1, I2 |
| what a mirror may be | filtered (`mirror.filter_subject`) and transformed (`mirror.subject_transforms: [{src, dest}]`) | I1, J1 |
| what a sourcing stream may be | filtered, transformed, given **its own subjects** and published to directly, and given **several sources — including two of the same stream with different filters** | I1, J1 |
| does a delete on the origin propagate | **No.** `STREAM.MSG.DELETE` on the origin's sequence 5 left the message in both the mirror and the sourcing stream | F6 |
| does deleting the origin break the copies | **No.** Both kept every message and stayed readable | I3 |
| do a mirror's and a source's internal consumers count against `max_consumers` | **No**, and they are not listed by `CONSUMER.NAMES` either — the server counts `len(mset.consumers) - mset.sourcingConsumers` (`stream.go:8587`) | F3, H4 |
| **the third shape — a consumer delivering into a second stream — does not work on its own** | a push consumer on `copy2.evt` with a second stream subscribed on `copy2.>` delivered **0 of 1,000** messages and `num_pending` stayed at 1,000. Attaching a plain `nats sub copy2.evt` released all 1,000 at once, and the second stream then stored them | G1, G2 |
| …and it is about **wildcards**, not about streams | with only a wildcard subscriber `d.>` on a deliver subject `d.evt` and no stream involved: **0 delivered**. With an exact subscriber on `d.evt`: delivery starts. `Sublist.registerNotification` counts interest only for a subscription whose subject is *literally equal* to the deliver subject (`sublist.go:169-190`) | H1, H2 |
| the shape that does work | a client that pulls from the origin and publishes into the copy: 1,000 messages in 0.01 s. The copy carries **no** origin header and gets its **own** sequence numbers — it is an ordinary publish, and nothing of the origin's position survives | H3 |

### Three numbers read from the source, not from a run

`local/scratch/src/v2.14.6/` (the server at tag v2.14.6), for the claims Synadia's subject-hierarchy
post makes about subject shape (`raw/synadia-blog/designing-nats-subject-hierarchies.txt`):

| claim | at v2.14.6 |
|---|---|
| "32-token stack array" | **real.** `sublist.go:576` and `:662` (`Sublist.match`, `Sublist.hasInterest`) and `:1343`, `:1441`, `:1449`, `:1664` all open with `tsa := [32]string{}` and tokenize into `tsa[:0]`; `stree/stree.go:125` and `:143` do the same for a filter's wildcard-delimited parts with `var raw [32][]byte`. Beyond 32 the `append` escapes to the heap, on every match that misses the sublist cache |
| "256 characters" | there is **no length limit**, and the number is not arbitrary either: the subject-tree walk carries the subject it is reconstructing in `var _pre [256]byte` (`stree/stree.go:127`, `:145`, `:154`, `:163`, `:491`). A subject longer than 256 bytes escapes to the heap on every matched walk of the per-subject index |
| "100,000 per-subject metadata entries per request" | **real, and it is a paging limit, not a cap on a stream's subjects**: `const JSMaxSubjectDetails = 100_000` (`jetstream_api.go:435`), used at `:2040`, `:2043`, `:2058` to page `STREAM.INFO`'s `state.subjects` by `offset`. Run E3 saw exactly this: `total 1000000, offset 0, limit 100000, subjects returned 100000` |

Neither the 32 nor the 256 is enforced — a longer subject works, and nothing logs or errors. They are
the sizes the server allocates on the stack for the common case, so exceeding them costs an
allocation per operation rather than a rejection. The "16 tokens" that three public sources state is
**not** among them; it appears nowhere in the server (docs issues #81, #82).

## What was not tested

- Anything on a **replicated** stream beyond stream and consumer counts: no `R3` cardinality run, no
  `R3` mirror or source, no `R3` filtered-consumer fan-out. The replication cost of a *filtered
  consumer* — a consumer's own Raft group — is untouched here.
- **Real disks and real networks.** Every restart in these runs read from the page cache; the
  three-node numbers are three servers on one CPU and one SSD with loopback routes.
- **Sustained load.** Every publish measurement is a short burst from one client with an ack window;
  nothing here ran long enough to see compaction, `sync_interval` flushes, or a full block rotation
  under load.
- **Consumers actually consuming.** The consumers in run C were created and (mostly) left idle; the
  publish rates are ingest with idle consumers attached, not end-to-end throughput.
- The **`max_msgs_per_subject`** shape an event store wants (row 144), and per-subject limits
  generally.
- **Memory storage** anywhere except the one empty stream in A1b.
- Whether the `10 s` SIGTERM ceiling in run R6 is the server's shutdown or the lab's patience: the
  lab script waits ten seconds and then sends SIGKILL, so all that is established is that the
  shutdown of a node holding 1,000 replicated streams takes **longer than ten seconds**.

---

## Run A · one stream, ten, a hundred, a thousand — and one stream with a tenant token (`stream-topology-runA.sh`)

A1 is run B, the per-stream floor: the store tree and the byte sizes of one empty file stream.
A1c–A4 measure the publish rate into `T00001` after each growth step, so the question is not
"how fast is this laptop" but "does the rate move when the server holds a thousand streams".

```
### [08:16:57] versions
nats-server: v2.14.6
0.4.0
### [08:16:57] fresh lab: down --purge, up 1
binary: nats-server: v2.14.6 (/opt/homebrew/bin/nats-server)
lab dir: <lab>
n1: pid 77197  client 127.0.0.1:4291  http 127.0.0.1:8291  log <lab>/n1/n1.log
healthy: standalone n1, /healthz ok
nats CLI: nats --server nats://sys:sys@127.0.0.1:4291 …
### [08:16:58] A0 · baseline, no stream
[A0 baseline]
  varz mem 18448384 B = 17.6 MiB   ps rss 18.0 MiB   cpu 0%   subs 63   conns 0
  jsz streams 0 consumers 0 messages 0 bytes 0 memory 0 storage 0 api_total 0 api_errors 0
  store <lab>/n1/store: 0 KiB = 0.0 MiB, 1 dirs, 0 files
### [08:16:58] A1 (= run B) · the per-stream floor: one empty file stream
mkstreams: 1 streams R1 file in 0.00s (706.2 streams/s, 0 errors)
  per create: min 1.4ms  P50 1.4ms  P90 1.4ms  P99 1.4ms  max 1.4ms
[A1 one empty stream]
  varz mem 20807680 B = 19.8 MiB   ps rss 19.9 MiB   cpu 0%   subs 65   conns 0
  jsz streams 1 consumers 0 messages 0 bytes 0 memory 0 storage 0 api_total 1 api_errors 0
  store <lab>/n1/store: 8 KiB = 0.0 MiB, 6 dirs, 3 files
--- the store tree of that one stream ---
<lab>/n1/store/jetstream/$G/streams
<lab>/n1/store/jetstream/$G/streams/T00001
<lab>/n1/store/jetstream/$G/streams/T00001/meta.inf
<lab>/n1/store/jetstream/$G/streams/T00001/meta.sum
<lab>/n1/store/jetstream/$G/streams/T00001/msgs
<lab>/n1/store/jetstream/$G/streams/T00001/msgs/1.blk
<lab>/n1/store/jetstream/$G/streams/T00001/obs
--- byte sizes ---
16 <lab>/n1/store/jetstream/$G/streams/T00001/meta.sum
516 <lab>/n1/store/jetstream/$G/streams/T00001/meta.inf
0 <lab>/n1/store/jetstream/$G/streams/T00001/msgs/1.blk
--- and one empty memory stream, for the comparison ---
[A1b + one empty memory stream]
  varz mem 21299200 B = 20.3 MiB   ps rss 20.4 MiB   cpu 0%   subs 68   conns 0
  jsz streams 2 consumers 0 messages 0 bytes 0 memory 0 storage 0 api_total 3 api_errors 0
  store <lab>/n1/store: 8 KiB = 0.0 MiB, 6 dirs, 3 files
### [08:16:58] A1c · publish rate into T00001 with 1 stream on the server
pubrate t.00001.evt: 20000 x 128B in 0.103s (194031 msg/s, 0 errors)
### [08:16:58] A2 · grow to 10 streams
mkstreams: 10 streams R1 file in 0.01s (1497.3 streams/s, 0 errors)
  per create: min 0.2ms  P50 0.7ms  P90 0.9ms  P99 0.9ms  max 0.9ms
[A2 ten streams]
  varz mem 35995648 B = 34.3 MiB   ps rss 34.3 MiB   cpu 29%   subs 74   conns 0
  jsz streams 10 consumers 0 messages 20000 bytes 3380000 memory 0 storage 3380000 api_total 14 api_errors 0
  store <lab>/n1/store: 3384 KiB = 3.3 MiB, 33 dirs, 30 files
pubrate t.00001.evt: 20000 x 128B in 0.098s (204803 msg/s, 0 errors)
### [08:16:58] A3 · grow to 100 streams
mkstreams: 100 streams R1 file in 0.05s (1831.3 streams/s, 0 errors)
  per create: min 0.1ms  P50 0.6ms  P90 0.7ms  P99 0.8ms  max 0.8ms
[A3 one hundred streams]
  varz mem 51838976 B = 49.4 MiB   ps rss 49.4 MiB   cpu 29%   subs 164   conns 0
  jsz streams 100 consumers 0 messages 40000 bytes 6760000 memory 0 storage 6760000 api_total 114 api_errors 0
  store <lab>/n1/store: 7404 KiB = 7.2 MiB, 303 dirs, 300 files
pubrate t.00001.evt: 20000 x 128B in 0.095s (209442 msg/s, 0 errors)
### [08:16:59] A4 · grow to 1000 streams
mkstreams: 1000 streams R1 file in 0.58s (1724.3 streams/s, 0 errors)
  per create: min 0.0ms  P50 0.6ms  P90 0.7ms  P99 0.9ms  max 2.1ms
[A4 one thousand streams]
  varz mem 90882048 B = 86.7 MiB   ps rss 86.9 MiB   cpu 100.1%   subs 1064   conns 0
  jsz streams 1000 consumers 0 messages 60000 bytes 10140000 memory 0 storage 10140000 api_total 1114 api_errors 0
  store <lab>/n1/store: 17904 KiB = 17.5 MiB, 3003 dirs, 3001 files
pubrate t.00001.evt: 20000 x 128B in 0.104s (192309 msg/s, 0 errors)
### [08:17:00] A4b · what the server says about a thousand streams
--- nats server report jetstream ---
╭──────────────────────────────────────────────────────────────────────────────────────────────────╮
│                                         JetStream Summary                                        │
├────────┬─────────┬─────────┬───────────┬──────────┬────────┬────────┬────────┬─────────┬─────────┤
│ Server │ Cluster │ Streams │ Consumers │ Messages │ Bytes  │ Memory │ File   │ API Req │ Pending │
├────────┼─────────┼─────────┼───────────┼──────────┼────────┼────────┼────────┼─────────┼─────────┤
│ n1     │         │ 1,000   │ 0         │ 80,000   │ 13 MiB │ 0 B    │ 13 MiB │ 1,114   │       0 │
├────────┼─────────┼─────────┼───────────┼──────────┼────────┼────────┼────────┼─────────┼─────────┤
│        │         │ 1,000   │ 0         │ 80,000   │ 13 MiB │ 0 B    │ 13 MiB │ 1,114   │       0 │
╰────────┴─────────┴─────────┴───────────┴──────────┴────────┴────────┴────────┴─────────┴─────────╯

--- $JS.API.STREAM.NAMES / LIST timing ---
apitime $JS.API.STREAM.NAMES: 0.4ms, 9106 bytes
   {"type":"io.nats.jetstream.api.v1.stream_names_response","total":1000,"offset":0,"limit":1024,"streams":["T00001","T00002","T00003","T00004","T00005","T00006","T00007","T00008","T00009","T00010","T00011","T00012","T00013","T00014","T00015","T00016","T00017","T00018","T00019","T00020","T00021","T00022","T00023","T00024","T00025","T00026","T00027","T00028","T00029","T00030","T00031","T00032","T00033
apitime $JS.API.STREAM.LIST: 1.5ms, 181597 bytes
   {"type":"io.nats.jetstream.api.v1.stream_list_response","total":1000,"offset":0,"limit":256,"streams":[{"config":{"name":"T00001","subjects":["t.00001.\u003e"],"retention":"limits","max_consumers":-1,"max_msgs":-1,"max_bytes":-1,"max_age":0,"max_msgs_per_subject":-1,"max_msg_size":-1,"discard":"old","storage":"file","num_replicas":1,"duplicate_window":120000000000,"compression":"none","allow_direc
--- time nats stream ls ---
nats stream ls -n: 0.02s, 1000 lines
--- /jsz (no accounts) ---
{
    "memory": 0,
    "storage": 13520000,
    "reserved_memory": 0,
    "reserved_storage": 0,
    "accounts": 1,
    "ha_assets": 0,
    "api": {
        "level": 4,
        "total": 1117,
        "errors": 0
    },
    "server_id": "NBYPNGCNEHZNQ36ZCVDOBV7S77KKDRYQSOFHEOYR4GUVNQBYRTHUB4VR",
    "now": "2026-09-04T06:17:00.464945Z",
    "config": {
        "max_memory": 25769803776,
        "max_storage": 72612639744,
        "store_dir": "<lab>/n1/store/jetstream",
        "sync_interval": 120000000000,
        "strict": true
    },
    "limits": {},
    "streams": 1000,
    "consumers": 0,
    "messages": 80000,
    "bytes": 13520000,
    "total": 1
}
### [08:17:00] A5 · fill the thousand streams: 100 messages of 128 B each = 100,000 messages
streams dir before: 21204 KiB
fill: 100000 x 128B over 1000 subject(s) in 0.83s (121188 msg/s, 0 errors)
[A5 1000 streams x 100 msgs]
  varz mem 246759424 B = 235.3 MiB   ps rss 235.4 MiB   cpu 149%   subs 1064   conns 0
  jsz streams 1000 consumers 0 messages 180000 bytes 30420000 memory 0 storage 30420000 api_total 1117 api_errors 0
  store <lab>/n1/store: 42208 KiB = 41.2 MiB, 3003 dirs, 3001 files
streams dir after: 42208 KiB
one filled stream: 14236 KiB
### [08:17:01] A6 · the same volume through ONE stream with a tenant token
[A6a ONE created]
  varz mem 247119872 B = 235.7 MiB   ps rss 235.8 MiB   cpu 222.2%   subs 1067   conns 0
  jsz streams 1001 consumers 0 messages 180000 bytes 30420000 memory 0 storage 30420000 api_total 1119 api_errors 0
  store <lab>/n1/store: 42216 KiB = 41.2 MiB, 3006 dirs, 3004 files
fill: 100000 x 128B over 1000 subject(s) in 0.53s (188907 msg/s, 0 errors)
[A6b ONE filled with the same 100,000 messages over 1000 subjects]
  varz mem 322764800 B = 307.8 MiB   ps rss 307.8 MiB   cpu 121.1%   subs 1067   conns 0
  jsz streams 1001 consumers 0 messages 280000 bytes 47520000 memory 0 storage 47520000 api_total 1119 api_errors 0
  store <lab>/n1/store: 58916 KiB = 57.5 MiB, 3006 dirs, 3006 files
ONE: 16708 KiB
Information for Stream ONE created 2026-09-04 08:17:01

                     Subjects: one.>
                     Replicas: 1
                      Storage: File

Options:

                    Retention: Limits
              Acknowledgments: true
               Discard Policy: Old
             Duplicate Window: 2m0s
                   Direct Get: true
  Allows Atomic Batch Publish: false
    Allows Fast Batch Publish: false
              Allows Counters: false
            Allows Msg Delete: true
       Allows Per-Message TTL: false
                 Allows Purge: true
             Allows Schedules: false
               Allows Rollups: false

Limits:

             Maximum Messages: unlimited
--- ONE's store tree ---
16 <lab>/n1/store/jetstream/$G/streams/ONE/meta.sum
508 <lab>/n1/store/jetstream/$G/streams/ONE/meta.inf
8388576 <lab>/n1/store/jetstream/$G/streams/ONE/msgs/1.blk
8388576 <lab>/n1/store/jetstream/$G/streams/ONE/msgs/2.blk
322848 <lab>/n1/store/jetstream/$G/streams/ONE/msgs/3.blk
### [08:17:02] A7 · restart with 1001 streams and 180,000 messages: clean stop, start, time to healthy
│ ONE    │ File    │           │ 0         │ 100,000  │ 16 MiB │ 0    │ 0       │ 0         │          │
╰────────┴─────────┴───────────┴───────────┴──────────┴────────┴──────┴─────────┴───────────┴──────────╯

n1: stopped (SIGTERM, pid 77197)
start -> /healthz 200 in 0.265s (code 200)
[A7 after restart]
  varz mem 96256000 B = 91.8 MiB   ps rss 91.9 MiB   cpu 0%   subs 1066   conns 0
  jsz streams 1001 consumers 0 messages 280000 bytes 47520000 memory 0 storage 47520000 api_total 0 api_errors 0
  store <lab>/n1/store: 62936 KiB = 61.5 MiB, 3006 dirs, 4007 files
--- what the log says about the restart ---
[77424] 2026/09/04 08:17:03.191218 [INF]   Restored 100 messages for stream '$G > T00963' in 7ms
[77424] 2026/09/04 08:17:03.191278 [INF]   Restored 100 messages for stream '$G > T00961' in 7ms
[77424] 2026/09/04 08:17:03.191307 [INF]   Restored 100 messages for stream '$G > T00988' in 5ms
[77424] 2026/09/04 08:17:03.190984 [INF]   Restored 100 messages for stream '$G > T00951' in 7ms
[77424] 2026/09/04 08:17:03.191357 [INF]   Restored 100 messages for stream '$G > T00978' in 5ms
[77424] 2026/09/04 08:17:03.191369 [INF]   Restored 100 messages for stream '$G > T00972' in 6ms
… (34 more `Restored 100 messages for stream …` lines, one per stream, elided) …
[77424] 2026/09/04 08:17:03.192221 [INF] Took 125.187875ms to start JetStream
[77424] 2026/09/04 08:17:03.192284 [INF] Listening for client connections on 127.0.0.1:4291
[77424] 2026/09/04 08:17:03.192289 [INF] Server is ready
--- 'Restored' lines in this boot ---
1001
### [08:17:03] A7b · restart again, this time after a SIGKILL
n1: SIGKILL sent to pid 77424
SIGKILL, start -> /healthz 200 in 0.264s (code 200)
[A7b after the SIGKILL restart]
  varz mem 90767360 B = 86.6 MiB   ps rss 86.7 MiB   cpu 0%   subs 1066   conns 0
  jsz streams 1001 consumers 0 messages 280000 bytes 47520000 memory 0 storage 47520000 api_total 0 api_errors 0
  store <lab>/n1/store: 62936 KiB = 61.5 MiB, 3006 dirs, 4007 files
0
### [08:17:03] done
```

## Run A2 · the same with nothing published, at 10,000 streams, and the dirty restart (`stream-topology-runA2.sh`)

B1 and B2 are the clean per-stream floor: empty streams only, so the RSS and the disk belong to
the streams and not to their messages. **B5's reading in this transcript is wrong and is left in
for the record**: `cluster.sh stop 1 -9` returns as soon as the signal is sent, the `start` that
followed was refused because the port was still bound, and the poll then measured the harness for
900 seconds. The scene was re-run by hand immediately afterwards (`runA3`, below) and the server's
own `Took … to start JetStream` line is the number quoted in the table.

```
### [08:18:03] versions
nats-server: v2.14.6
0.4.0
### [08:18:03] fresh lab: down --purge, up 1
binary: nats-server: v2.14.6 (/opt/homebrew/bin/nats-server)
lab dir: <lab>
n1: pid 78402  client 127.0.0.1:4291  http 127.0.0.1:8291  log <lab>/n1/n1.log
healthy: standalone n1, /healthz ok
nats CLI: nats --server nats://sys:sys@127.0.0.1:4291 …
### [08:18:04] B0 · baseline
[B0 baseline, no stream]
  varz mem 18857984 B = 18.0 MiB   ps rss 18.5 MiB   cpu 0%   subs 63   conns 0
  jsz streams 0 consumers 0 messages 0 bytes 0 memory 0 storage 0 api_total 0 api_errors 0
  store <lab>/n1/store: 0 KiB = 0.0 MiB, 1 dirs, 0 files
### [08:18:04] B1 · 1000 empty file streams, nothing published
mkstreams: 1000 streams R1 file in 0.63s (1592.4 streams/s, 0 errors)
  per create: min 0.5ms  P50 0.6ms  P90 0.7ms  P99 0.9ms  max 2.9ms
[B1 1000 empty file streams]
  varz mem 78708736 B = 75.1 MiB   ps rss 75.1 MiB   cpu 77.5%   subs 1064   conns 0
  jsz streams 1000 consumers 0 messages 0 bytes 0 memory 0 storage 0 api_total 1000 api_errors 0
  store <lab>/n1/store: 8000 KiB = 7.8 MiB, 3003 dirs, 3000 files
### [08:18:05] B2 · 10,000 empty file streams
mkstreams: 10000 streams R1 file in 14.80s (675.5 streams/s, 0 errors)
  per create: min 0.1ms  P50 1.2ms  P90 2.8ms  P99 4.3ms  max 23.1ms
[B2 10,000 empty file streams]
  varz mem 560168960 B = 534.2 MiB   ps rss 535.8 MiB   cpu 94.5%   subs 10064   conns 0
  jsz streams 10000 consumers 0 messages 0 bytes 0 memory 0 storage 0 api_total 11000 api_errors 0
  store <lab>/n1/store: 80000 KiB = 78.1 MiB, 30003 dirs, 30000 files
--- ha_assets and the account view ---
{'streams': 10000, 'consumers': 0, 'ha_assets': 0, 'memory': 0, 'storage': 0, 'accounts': 1}
--- STREAM.NAMES paging at 10,000 ---
apitime $JS.API.STREAM.NAMES: 1.7ms, 9323 bytes
   {"type":"io.nats.jetstream.api.v1.stream_names_response","total":10000,"offset":0,"limit":1024,"streams":["E00001","E00002","E00003","E00004","E00005","E00006","E00007","E00008","E00009","E00010","E00011","E00012","E00013","E00014","E00015","E00016","E00017","E00018","E00019","E00020","E00021","E00022","E00023","E00024","E00025","E00026","E00027","E00028","E00029","E00030","E00031","E00032","E0003
nats stream ls -n: 0.04s, 10000 lines
--- nats server report jetstream ---
╭───────────────────────────────────────────────────────────────────────────────────────────────╮
│                                       JetStream Summary                                       │
├────────┬─────────┬─────────┬───────────┬──────────┬───────┬────────┬──────┬─────────┬─────────┤
│ Server │ Cluster │ Streams │ Consumers │ Messages │ Bytes │ Memory │ File │ API Req │ Pending │
├────────┼─────────┼─────────┼───────────┼──────────┼───────┼────────┼──────┼─────────┼─────────┤
│ n1     │         │ 10,000  │ 0         │ 0        │ 0 B   │ 0 B    │ 0 B  │ 11,011  │       0 │
├────────┼─────────┼─────────┼───────────┼──────────┼───────┼────────┼──────┼─────────┼─────────┤
│        │         │ 10,000  │ 0         │ 0        │ 0 B   │ 0 B    │ 0 B  │ 11,011  │       0 │
### [08:18:22] B3 · restart with 10,000 empty streams
n1: stopped (SIGTERM, pid 78402)
B3 clean stop, 10,000 empty streams: start -> /healthz 200 in 5.514s (code 200)
[B3 after restart]
  varz mem 557416448 B = 531.6 MiB   ps rss 533.3 MiB   cpu 143.3%   subs 10063   conns 0
  jsz streams 10000 consumers 0 messages 0 bytes 0 memory 0 storage 0 api_total 0 api_errors 0
  store <lab>/n1/store: 120000 KiB = 117.2 MiB, 30003 dirs, 40000 files
[78402] 2026/09/04 08:18:04.383980 [INF] Took 510.625µs to start JetStream
[78751] 2026/09/04 08:18:28.987586 [INF] Took 5.405313958s to start JetStream
10000
### [08:18:30] B4 · one message into each of the 10,000 streams, then a clean restart
fill: 10000 x 128B over 10000 subject(s) in 43.97s (227 msg/s, 0 errors)
[B4 10,000 streams x 1 msg]
  varz mem 922435584 B = 879.7 MiB   ps rss 881.2 MiB   cpu 379.8%   subs 10063   conns 0
  jsz streams 10000 consumers 0 messages 10000 bytes 1690000 memory 0 storage 1690000 api_total 0 api_errors 0
  store <lab>/n1/store: 160000 KiB = 156.2 MiB, 30003 dirs, 40000 files
n1: stopped (SIGTERM, pid 78751)
B4 clean stop, 10,000 streams with one message each: start -> /healthz 200 in 5.862s (code 200)
[B4 after restart]
  varz mem 649003008 B = 618.9 MiB   ps rss 620.7 MiB   cpu 130.6%   subs 10063   conns 0
  jsz streams 10000 consumers 0 messages 10000 bytes 1690000 memory 0 storage 1690000 api_total 0 api_errors 0
  store <lab>/n1/store: 160000 KiB = 156.2 MiB, 30003 dirs, 40000 files
### [08:19:25] B5 · write, then SIGKILL, then start (the dirty case at 10,000 streams)
fill: 10000 x 128B over 10000 subject(s) in 0.36s (27493 msg/s, 0 errors)
n1: SIGKILL sent to pid 79280
B5 SIGKILL after writes, 10,000 streams: start -> /healthz 200 in 900.001s (code 0)
(the run script's own python helper raised here; see the note above this transcript)

During handling of the above exception, another exception occurred:

(the run script's own python helper raised here; see the note above this transcript)
--- rebuild / outdated lines in the log ---
0
[79280] 2026/09/04 08:19:23.863343 [INF] Took 5.762241583s to start JetStream
### [08:34:26] B6 · deleting 10,000 streams
(the run script's own python helper raised here; see the note above this transcript)
(the run script's own python helper raised here; see the note above this transcript)

During handling of the above exception, another exception occurred:

(the run script's own python helper raised here; see the note above this transcript)
### [08:34:26] done
```

```
### [08:35:17] B5 (re-run by hand after the lab's `stop -9` race) + B6
--- every 'Took … to start JetStream' in this log, in order ---
[78402] 2026/09/04 08:18:04.383980 [INF] Took 510.625µs to start JetStream
[78751] 2026/09/04 08:18:28.987586 [INF] Took 5.405313958s to start JetStream
[79280] 2026/09/04 08:19:23.863343 [INF] Took 5.762241583s to start JetStream
[91044] 2026/09/04 08:34:52.153993 [INF] Took 5.655035375s to start JetStream
--- 'will rebuild' warnings in the dirty boot ---
10000
[B5 after the SIGKILL restart, 10,000 streams x 2 msgs]
  varz mem 567738368 B = 541.4 MiB   ps rss 541.6 MiB   cpu 0.1%   subs 10063   conns 0
  jsz streams 10000 consumers 0 messages 20000 bytes 3380000 memory 0 storage 3380000 api_total 0 api_errors 0
  store <lab>/n1/store: 160000 KiB = 156.2 MiB, 30003 dirs, 40000 files
### [08:35:18] B6 · deleting 10,000 streams
rmstreams: 10000 deleted in 3.02s
[B6 after deleting them]
  varz mem 698155008 B = 665.8 MiB   ps rss 665.8 MiB   cpu 287.6%   subs 64   conns 0
  jsz streams 0 consumers 0 messages 0 bytes 0 memory 0 storage 0 api_total 10000 api_errors 0
  store <lab>/n1/store: 0 KiB = 0.0 MiB, 3 dirs, 0 files
```

## Run R3 · the same counts with replicas, on the three-node lab (`stream-topology-runR3.sh`)

The same shape at `R3`. **R6's `616.828s` in this transcript is the same harness artefact as
run A2's B5** — n3 was SIGKILLed by the lab after its SIGTERM shutdown ran past ten seconds, and
the `start` that followed was refused on a bound port. The re-run by hand is the second
transcript, and its **17.985 s** is the number quoted. R7 is inconclusive and is quoted nowhere:
the three nodes had not converged on the new R1 streams when the snapshot was taken (n2 reports
2,000 streams, n1 and n3 1,000).

```
### [08:45:07] versions
nats-server: v2.14.6
0.4.0
### [08:45:07] fresh lab: down --purge, up 3
binary: nats-server: v2.14.6 (/opt/homebrew/bin/nats-server)
lab dir: <lab>
n1: pid 2464  client 127.0.0.1:4291  http 127.0.0.1:8291  log <lab>/n1/n1.log
n2: pid 2484  client 127.0.0.1:4292  http 127.0.0.1:8292  log <lab>/n2/n2.log
n3: pid 2504  client 127.0.0.1:4293  http 127.0.0.1:8293  log <lab>/n3/n3.log
healthy: 3 nodes, /healthz?js-meta-only=true ok on every node; meta leader n2, cluster_size 3
nats CLI: nats --server nats://sys:sys@127.0.0.1:4291 …
[R0 baseline, three nodes, no stream]
  n1: rss 23.5 MiB  varz mem 23.3 MiB  streams 0 consumers 0 ha_assets 1  leader n2  store 28 KiB  _meta_ 28 KiB
  n2: rss 23.8 MiB  varz mem 23.6 MiB  streams 0 consumers 0 ha_assets 1  leader n2  store 28 KiB  _meta_ 28 KiB
  n3: rss 23.4 MiB  varz mem 23.3 MiB  streams 0 consumers 0 ha_assets 1  leader n2  store 28 KiB  _meta_ 28 KiB
--- the _meta_ directory before any stream ---
<lab>/n1/store/jetstream/$SYS/_js_/_meta_/tav.idx
<lab>/n1/store/jetstream/$SYS/_js_/_meta_/peers.idx
<lab>/n1/store/jetstream/$SYS/_js_/_meta_/snapshots/snap.1.3
<lab>/n1/store/jetstream/$SYS/_js_/_meta_/meta.sum
<lab>/n1/store/jetstream/$SYS/_js_/_meta_/meta.inf
<lab>/n1/store/jetstream/$SYS/_js_/_meta_/msgs/index.db
<lab>/n1/store/jetstream/$SYS/_js_/_meta_/msgs/3.blk
28	<lab>/n1/store/jetstream/$SYS/_js_/_meta_
### [08:45:09] R1 · 10 R3 streams
mkstreams: 10 streams R3 file in 1.14s (8.7 streams/s, 0 errors)
  per create: min 101.7ms  P50 115.9ms  P90 130.3ms  P99 130.3ms  max 130.3ms
[R1 10 R3 streams]
  n1: rss 26.0 MiB  varz mem 26.0 MiB  streams 10 consumers 0 ha_assets 11  leader n2  store 316 KiB  _meta_ 36 KiB
  n2: rss 27.3 MiB  varz mem 27.3 MiB  streams 10 consumers 0 ha_assets 11  leader n2  store 316 KiB  _meta_ 36 KiB
  n3: rss 25.7 MiB  varz mem 25.6 MiB  streams 10 consumers 0 ha_assets 11  leader n2  store 316 KiB  _meta_ 36 KiB
### [08:45:10] R2 · 100 R3 streams
mkstreams: 100 streams R3 file in 10.18s (9.8 streams/s, 0 errors)
  per create: min 0.3ms  P50 112.3ms  P90 120.9ms  P99 128.4ms  max 128.4ms
[R2 100 R3 streams]
  n1: rss 44.3 MiB  varz mem 44.2 MiB  streams 100 consumers 0 ha_assets 101  leader n2  store 2956 KiB  _meta_ 156 KiB
  n2: rss 45.4 MiB  varz mem 45.4 MiB  streams 100 consumers 0 ha_assets 101  leader n2  store 2956 KiB  _meta_ 156 KiB
  n3: rss 42.9 MiB  varz mem 42.8 MiB  streams 100 consumers 0 ha_assets 101  leader n2  store 2956 KiB  _meta_ 156 KiB
--- nats server report jetstream ---
╭───────────────────────────────────────────────────────────────────────────────────────────────╮
│                                       JetStream Summary                                       │
├────────┬─────────┬─────────┬───────────┬──────────┬───────┬────────┬──────┬─────────┬─────────┤
│ Server │ Cluster │ Streams │ Consumers │ Messages │ Bytes │ Memory │ File │ API Req │ Pending │
├────────┼─────────┼─────────┼───────────┼──────────┼───────┼────────┼──────┼─────────┼─────────┤
│ n1     │ east    │ 100     │ 0         │ 0        │ 0 B   │ 0 B    │ 0 B  │ 48      │       0 │
│ n2*    │ east    │ 100     │ 0         │ 0        │ 0 B   │ 0 B    │ 0 B  │ 38      │       0 │
│ n3     │ east    │ 100     │ 0         │ 0        │ 0 B   │ 0 B    │ 0 B  │ 44      │       0 │
├────────┼─────────┼─────────┼───────────┼──────────┼───────┼────────┼──────┼─────────┼─────────┤
│        │         │ 300     │ 0         │ 0        │ 0 B   │ 0 B    │ 0 B  │ 130     │       0 │
╰────────┴─────────┴─────────┴───────────┴──────────┴───────┴────────┴──────┴─────────┴─────────╯

╭───────────────────────────────────────────────────────────────────────╮
│            RAFT Meta Group Information - Lead cluster: east           │
--- the meta log on n1 ---
total 272
-rw-------@ 1 m64  staff  119420 Sep  4 08:45 3.blk
-rw-------@ 1 m64  staff      52 Sep  4 08:45 index.db
--- one stream's raft directory on n1 ---
16 <lab>/n1/store/jetstream/$G/streams/R00001/meta.sum
516 <lab>/n1/store/jetstream/$G/streams/R00001/meta.inf
0 <lab>/n1/store/jetstream/$G/streams/R00001/msgs/1.blk
### [08:45:21] R3 · publish rate into one R3 stream with 100 R3 streams present
pubrate r.00001.evt: 20000 x 128B in 0.125s (159470 msg/s, 0 errors)
pubrate r.00001.evt: 20000 x 128B in 0.140s (142470 msg/s, 0 errors)
[R3 after 40,000 R3 messages]
  n1: rss 98.2 MiB  varz mem 98.1 MiB  streams 100 consumers 0 ha_assets 101  leader n2  store 18276 KiB  _meta_ 156 KiB
  n2: rss 92.6 MiB  varz mem 92.6 MiB  streams 100 consumers 0 ha_assets 101  leader n2  store 18264 KiB  _meta_ 156 KiB
  n3: rss 85.7 MiB  varz mem 85.7 MiB  streams 100 consumers 0 ha_assets 101  leader n2  store 18276 KiB  _meta_ 156 KiB
### [08:45:22] R4 · 300 R3 streams
mkstreams: 300 streams R3 file in 23.01s (13.0 streams/s, 0 errors)
  per create: min 0.2ms  P50 109.2ms  P90 124.0ms  P99 132.1ms  max 144.2ms
[R4 300 R3 streams]
  n1: rss 109.4 MiB  varz mem 109.4 MiB  streams 300 consumers 0 ha_assets 301  leader n2  store 24196 KiB  _meta_ 476 KiB
  n2: rss 116.4 MiB  varz mem 116.4 MiB  streams 300 consumers 0 ha_assets 301  leader n2  store 24184 KiB  _meta_ 476 KiB
  n3: rss 104.6 MiB  varz mem 104.6 MiB  streams 300 consumers 0 ha_assets 301  leader n2  store 24196 KiB  _meta_ 476 KiB
pubrate r.00001.evt: 20000 x 128B in 0.127s (157876 msg/s, 0 errors)
### [08:45:45] R5 · 1000 R3 streams — where the meta layer starts to hurt
mkstreams: 1000 streams R3 file in 80.85s (12.4 streams/s, 0 errors)
  per create: min 0.2ms  P50 107.6ms  P90 122.4ms  P99 135.4ms  max 586.3ms
[R5 1000 R3 streams]
  n1: rss 200.0 MiB  varz mem 200.0 MiB  streams 1000 consumers 0 ha_assets 1001  leader n2  store 42544 KiB  _meta_ 628 KiB
  n2: rss 205.2 MiB  varz mem 205.1 MiB  streams 1000 consumers 0 ha_assets 1001  leader n2  store 42532 KiB  _meta_ 628 KiB
  n3: rss 199.7 MiB  varz mem 199.5 MiB  streams 1000 consumers 0 ha_assets 1001  leader n2  store 43508 KiB  _meta_ 1592 KiB
pubrate r.00001.evt: 20000 x 128B in 0.115s (173326 msg/s, 0 errors)
--- how long does STREAM.INFO on one of them take now ---
streaminfo R00001: 0.2ms, reply 1184 bytes, messages 80000, bytes 13520000, num_subjects 1, subjects returned 0
--- and the meta leader's raft state ---
['$SYS']
### [08:47:07] R6 · restart one node with 1000 R3 streams: stop 3, start 3, time to healthy and to caught up
n3: pid 2504 did not exit on SIGTERM within 10s, killed
n3 /healthz 200 in 616.828s
n3 reports 1000 streams 0.002s after healthy
[R6 after n3 rejoined]
  n1: rss 288.6 MiB  varz mem 398.1 MiB  streams 1000 consumers 0 ha_assets 1001  leader n2  store 54100 KiB  _meta_ 80 KiB
  n2: rss 342.7 MiB  varz mem 452.7 MiB  streams 1000 consumers 0 ha_assets 1001  leader n2  store 54088 KiB  _meta_ 80 KiB
  n3: rss 189.1 MiB  varz mem 188.7 MiB  streams 1000 consumers 0 ha_assets 1001  leader n2  store 52604 KiB  _meta_ 76 KiB
--- n3's log, the JetStream start line ---
[2504] 2026/09/04 08:45:08.225065 [INF] Took 24.720541ms to start JetStream
[13624] 2026/09/04 08:57:17.159920 [INF] Took 329.471375ms to start JetStream
--- how many 'Restored' lines n3 printed on this boot ---
1000
### [08:57:35] R7 · what 1000 R3 streams cost against 1000 R1 streams (the same lab, R1 for comparison)
mkstreams: 1000 streams R1 file in 1.21s (823.9 streams/s, 0 errors)
  per create: min 0.9ms  P50 1.0ms  P90 1.2ms  P99 6.0ms  max 11.7ms
[R7 + 1000 R1 streams alongside]
  n1: rss 288.8 MiB  varz mem 398.1 MiB  streams 1000 consumers 0 ha_assets 1001  leader n2  store 55144 KiB  _meta_ 1124 KiB
  n2: rss 343.2 MiB  varz mem 452.7 MiB  streams 2000 consumers 0 ha_assets 1001  leader n2  store 63132 KiB  _meta_ 1124 KiB
  n3: rss 208.4 MiB  varz mem 208.2 MiB  streams 1000 consumers 0 ha_assets 1001  leader n2  store 53648 KiB  _meta_ 1120 KiB
### [08:57:37] done
```

```
binary: nats-server: v2.14.6 (/opt/homebrew/bin/nats-server)
n3: pid 13624  client 127.0.0.1:4293  http 127.0.0.1:8293  log <lab>/n3/n3.log
R6 (re-run by hand; the lab's `stop` returns before the port is free) — n3 restart with 1000 R3 streams: /healthz 200 in 17.985s
n3 reports 1000 streams 0.001s after healthy (ha_assets 1001)
```

## Run C · filtered consumers on one big stream (`stream-topology-runC.sh`)

C1b is the gh#3405 question measured: one message on `big.needle.one`, published between two
500,000-message fills, then a filtered consumer created on exactly that subject.
C3 is the *other* filter question — many disjoint filters on one consumer, the shape
[[jetstream-slows-as-consumers-grow]] carries a public "~300" for.

```
### [08:40:51] versions
nats-server: v2.14.6
0.4.0
### [08:40:51] fresh lab: down --purge, up 1
binary: nats-server: v2.14.6 (/opt/homebrew/bin/nats-server)
lab dir: <lab>
n1: pid 97005  client 127.0.0.1:4291  http 127.0.0.1:8291  log <lab>/n1/n1.log
healthy: standalone n1, /healthz ok
nats CLI: nats --server nats://sys:sys@127.0.0.1:4291 …
[C0 baseline]
  varz mem 18268160 B = 17.4 MiB   ps rss 17.8 MiB   cpu 0%   subs 63   conns 0
  jsz streams 0 consumers 0 messages 0 bytes 0 memory 0 storage 0 api_total 0 api_errors 0
  store <lab>/n1/store: 0 KiB = 0.0 MiB, 1 dirs, 0 files
### [08:40:51] C1 · BIG: 1,000,000 x 128 B over 1000 subjects, with one needle in the middle
fill: 500000 x 128B over 1000 subject(s) in 2.50s (199840 msg/s, 0 errors)
08:40:54 Published 31 bytes to "big.needle.one"
fill: 500000 x 128B over 1000 subject(s) in 2.54s (197075 msg/s, 0 errors)
[C1 BIG filled]
  varz mem 54067200 B = 51.6 MiB   ps rss 51.7 MiB   cpu 166.1%   subs 67   conns 0
  jsz streams 1 consumers 0 messages 1000001 bytes 171000075 memory 0 storage 171000075 api_total 2 api_errors 0
  store <lab>/n1/store: 167004 KiB = 163.1 MiB, 6 dirs, 23 files
                     Subjects: big.>
             Maximum Messages: unlimited
                Maximum Bytes: unlimited
                     Messages: 1,000,001
                        Bytes: 163 MiB
               First Sequence: 1 @ 2026-09-04 08:40:51
                Last Sequence: 1,000,001 @ 2026-09-04 08:40:57
           Number of Subjects: 1,001
streaminfo BIG: 0.2ms, reply 905 bytes, messages 1000001, bytes 171000075, num_subjects 1001, subjects returned 0
### [08:40:57] C1b · the seek: a filter with ONE match in the middle of a million
firstfetch needle: CONSUMER.CREATE 0.9ms (num_pending 1), first message 2.3ms -> big.needle.one
firstfetch needle-again: CONSUMER.CREATE 0.8ms (num_pending 1), first message 0.1ms -> big.needle.one
--- against a dense filter (1000 matches, the first at sequence 1) ---
firstfetch dense: CONSUMER.CREATE 0.8ms (num_pending 1000), first message 1.7ms -> big.00001.evt
--- against the whole stream ---
firstfetch all: CONSUMER.CREATE 0.8ms (num_pending 1000001), first message 0.1ms -> big.00001.evt
--- and a filter that matches nothing at all ---
firstfetch absent: CONSUMER.CREATE 0.8ms (num_pending 0), first message 30001.3ms -> NATS/1.0 408 Request Timeout
### [08:41:27] C2 · N consumers with one filter each: 1, 10, 100, 300
mkcons: 1 consumers on BIG in 0.00s (1098.9/s, 0 errors)
  per create: min 0.9ms  P50 0.9ms  P90 0.9ms  P99 0.9ms  max 0.9ms
[C2 1 filtered consumers on BIG]
  varz mem 70369280 B = 67.1 MiB   ps rss 67.1 MiB   cpu 0.4%   subs 87   conns 0
  jsz streams 1 consumers 6 messages 1000001 bytes 171000075 memory 0 storage 171000075 api_total 10 api_errors 0
  store <lab>/n1/store: 167076 KiB = 163.2 MiB, 12 dirs, 41 files
pubrate big.00001.evt: 20000 x 128B in 0.101s (197506 msg/s, 0 errors)
conslist BIG: CONSUMER.NAMES 0.2ms (total 6), CONSUMER.LIST 0.3ms (3441 bytes)
mkcons: 10 consumers on BIG in 0.01s (1533.9/s, 0 errors)
  per create: min 0.5ms  P50 0.5ms  P90 1.6ms  P99 1.6ms  max 1.6ms
[C2 10 filtered consumers on BIG]
  varz mem 74891264 B = 71.4 MiB   ps rss 71.4 MiB   cpu 0.4%   subs 132   conns 0
  jsz streams 1 consumers 15 messages 1020001 bytes 174420075 memory 0 storage 174420075 api_total 22 api_errors 0
  store <lab>/n1/store: 171280 KiB = 167.3 MiB, 21 dirs, 68 files
pubrate big.00001.evt: 20000 x 128B in 0.092s (216850 msg/s, 0 errors)
conslist BIG: CONSUMER.NAMES 0.1ms (total 15), CONSUMER.LIST 0.4ms (8542 bytes)
mkcons: 100 consumers on BIG in 0.05s (2008.2/s, 0 errors)
  per create: min 0.3ms  P50 0.5ms  P90 0.7ms  P99 0.7ms  max 0.7ms
[C2 100 filtered consumers on BIG]
  varz mem 90062848 B = 85.9 MiB   ps rss 85.9 MiB   cpu 86.1%   subs 582   conns 0
  jsz streams 1 consumers 105 messages 1040001 bytes 177840075 memory 0 storage 177840075 api_total 124 api_errors 0
  store <lab>/n1/store: 175028 KiB = 170.9 MiB, 111 dirs, 339 files
pubrate big.00001.evt: 20000 x 128B in 0.092s (218176 msg/s, 0 errors)
conslist BIG: CONSUMER.NAMES 0.2ms (total 105), CONSUMER.LIST 2.0ms (59561 bytes)
mkcons: 300 consumers on BIG in 0.13s (2248.1/s, 0 errors)
  per create: min 0.3ms  P50 0.4ms  P90 0.6ms  P99 0.7ms  max 0.8ms
[C2 300 filtered consumers on BIG]
  varz mem 90308608 B = 86.1 MiB   ps rss 86.1 MiB   cpu 86.1%   subs 1582   conns 0
  jsz streams 1 consumers 305 messages 1060001 bytes 181260075 memory 0 storage 181260075 api_total 426 api_errors 0
  store <lab>/n1/store: 180768 KiB = 176.5 MiB, 311 dirs, 939 files
pubrate big.00001.evt: 20000 x 128B in 0.095s (211130 msg/s, 0 errors)
conslist BIG: CONSUMER.NAMES 0.2ms (total 305), CONSUMER.LIST 4.7ms (145195 bytes)
### [08:41:28] C2b · 1000 consumers on the one stream
mkcons: 1000 consumers on BIG in 0.46s (2167.9/s, 0 errors)
  per create: min 0.3ms  P50 0.5ms  P90 0.6ms  P99 0.8ms  max 2.4ms
[C2b 1000 filtered consumers on BIG]
  varz mem 106512384 B = 101.6 MiB   ps rss 101.6 MiB   cpu 95%   subs 5082   conns 0
  jsz streams 1 consumers 1005 messages 1080001 bytes 184680075 memory 0 storage 184680075 api_total 1428 api_errors 0
  store <lab>/n1/store: 192508 KiB = 188.0 MiB, 1011 dirs, 3040 files
pubrate big.00001.evt: 20000 x 128B in 0.100s (199888 msg/s, 0 errors)
conslist BIG: CONSUMER.NAMES 0.2ms (total 1005), CONSUMER.LIST 4.9ms (145202 bytes)
--- what one consumer info costs at that count ---
apitime $JS.API.CONSUMER.INFO.BIG.C0500: 0.2ms, 662 bytes
   {"type":"io.nats.jetstream.api.v1.consumer_info_response","stream_name":"BIG","name":"C0500","created":"2026-09-04T06:41:28.726986Z","config":{"durable_name":"C0500","name":"C0500","deliver_policy":"all","ack_policy":"explicit","ack_wait":30000000000,"max_deliver":-1,"filter_subject":"big.00500.evt","replay_policy":"instant","max_waiting":512,"max_ack_pending":1000,"num_replicas":0,"metadata":{"_n
### [08:41:29] C2c · restart with 1000 consumers on one stream
n1: stopped (SIGTERM, pid 97005)
C2c clean restart, 1 stream / 1,020,000 msgs / 1000 consumers: /healthz 200 in 0.401s (code 200)
[C2c after restart]
  varz mem 84344832 B = 80.4 MiB   ps rss 80.5 MiB   cpu 0%   subs 5081   conns 0
  jsz streams 1 consumers 1005 messages 1100001 bytes 188100075 memory 0 storage 188100075 api_total 0 api_errors 0
  store <lab>/n1/store: 195868 KiB = 191.3 MiB, 1011 dirs, 3041 files
[97620] 2026/09/04 08:41:29.844454 [INF] Took 300.802375ms to start JetStream
### [08:41:29] C3 · ONE consumer with N disjoint filters (the 2.10 multi-filter form)
multifetch 1: 1 disjoint filters, CONSUMER.CREATE 1.0ms (num_pending 101000), first message 1.8ms
multifetch 10: 10 disjoint filters, CONSUMER.CREATE 1.2ms (num_pending 110000), first message 0.2ms
multifetch 100: 100 disjoint filters, CONSUMER.CREATE 1.4ms (num_pending 200000), first message 0.2ms
multifetch 300: 300 disjoint filters, CONSUMER.CREATE 4.6ms (num_pending 400000), first message 0.2ms
multifetch 1000: 1000 disjoint filters, CONSUMER.CREATE 33.7ms (num_pending 1100000), first message 0.4ms
--- 2000 and 5000, to find where it stops being reasonable ---
multifetch 2000: 2000 disjoint filters, CONSUMER.CREATE 128.6ms (num_pending 1100000), first message 0.3ms
multifetch 5000: 5000 disjoint filters, CONSUMER.CREATE 784.0ms (num_pending 1100000), first message 0.4ms
--- the wildcard that covers all 1000, for comparison ---
firstfetch wildcard: CONSUMER.CREATE 0.8ms (num_pending 1100000), first message 0.2ms -> big.00001.evt
### [08:41:31] C4 · the same fan-out as 300 small streams with one consumer each
binary: nats-server: v2.14.6 (/opt/homebrew/bin/nats-server)
lab dir: <lab>
n1: pid 97731  client 127.0.0.1:4291  http 127.0.0.1:8291  log <lab>/n1/n1.log
healthy: standalone n1, /healthz ok
nats CLI: nats --server nats://sys:sys@127.0.0.1:4291 …
[C4 baseline]
  varz mem 18333696 B = 17.5 MiB   ps rss 18.0 MiB   cpu 0%   subs 63   conns 0
  jsz streams 0 consumers 0 messages 0 bytes 0 memory 0 storage 0 api_total 0 api_errors 0
  store <lab>/n1/store: 0 KiB = 0.0 MiB, 1 dirs, 0 files
mkstreams: 300 streams R1 file in 0.18s (1649.7 streams/s, 0 errors)
  per create: min 0.5ms  P50 0.6ms  P90 0.7ms  P99 1.1ms  max 1.6ms
one consumer on each of 300 streams: 0.15s
[C4 300 streams, 300 consumers (one each)]
  varz mem 58097664 B = 55.4 MiB   ps rss 55.4 MiB   cpu 63.3%   subs 1864   conns 0
  jsz streams 300 consumers 300 messages 0 bytes 0 memory 0 storage 0 api_total 600 api_errors 0
  store <lab>/n1/store: 6000 KiB = 5.9 MiB, 1203 dirs, 1800 files
fill: 300000 x 128B over 300 subject(s) in 2.36s (127068 msg/s, 0 errors)
[C4 filled with 300,000 messages]
  varz mem 213336064 B = 203.5 MiB   ps rss 203.5 MiB   cpu 367.6%   subs 1864   conns 0
  jsz streams 300 consumers 300 messages 300000 bytes 50700000 memory 0 storage 50700000 api_total 600 api_errors 0
  store <lab>/n1/store: 64800 KiB = 63.3 MiB, 1203 dirs, 1800 files
pubrate s.00001.evt: 20000 x 128B in 0.104s (192070 msg/s, 0 errors)
--- the same 300,000 messages and 300 consumers on ONE stream, for the comparison ---
binary: nats-server: v2.14.6 (/opt/homebrew/bin/nats-server)
lab dir: <lab>
n1: pid 97876  client 127.0.0.1:4291  http 127.0.0.1:8291  log <lab>/n1/n1.log
healthy: standalone n1, /healthz ok
nats CLI: nats --server nats://sys:sys@127.0.0.1:4291 …
mkcons: 300 consumers on ONE in 0.15s (1936.6/s, 0 errors)
  per create: min 0.4ms  P50 0.5ms  P90 0.6ms  P99 1.1ms  max 1.3ms
[C4b ONE stream, 300 filtered consumers]
  varz mem 38928384 B = 37.1 MiB   ps rss 37.3 MiB   cpu 0%   subs 1567   conns 0
  jsz streams 1 consumers 300 messages 0 bytes 0 memory 0 storage 0 api_total 302 api_errors 0
  store <lab>/n1/store: 3608 KiB = 3.5 MiB, 306 dirs, 903 files
fill: 300000 x 128B over 300 subject(s) in 1.54s (194513 msg/s, 0 errors)
[C4b filled with the same 300,000 messages]
  varz mem 77512704 B = 73.9 MiB   ps rss 73.9 MiB   cpu 198.1%   subs 1567   conns 0
  jsz streams 1 consumers 300 messages 300000 bytes 51300000 memory 0 storage 51300000 api_total 302 api_errors 0
  store <lab>/n1/store: 53708 KiB = 52.4 MiB, 306 dirs, 909 files
pubrate one.00001.evt: 20000 x 128B in 0.095s (210534 msg/s, 0 errors)
### [08:41:37] done
```

## Run D · a tenant at its account limits (`stream-topology-runD.sh`, `-runD2.sh`, `stream-topology-limits.conf`)

One server, two accounts: `TENANT` with `max_streams: 3`, `max_consumers: 2`, `max_file: 64MB`,
`max_mem: 16MB`; `FREE` with `jetstream: enabled` and no limits. D11 is the scene that settles
whether the account's `max_consumers` is per account or per stream.

```
### [08:42:03] versions
nats-server: v2.14.6
0.4.0
server healthy in 0.01s
### [08:42:03] D0 · what the tenant sees before it has anything
Account Information

                           User: t
                        Account: TENANT (TENANT)
                 System Account: false
                        Expires: never
                      Client ID: 7
                      Client IP: 127.0.0.1
                            RTT: 99µs
              Headers Supported: true
                Maximum Payload: 1.0 MiB
                  Connected URL: nats://t:t@127.0.0.1:4321
              Connected Address: 127.0.0.1:4321
            Connected Server ID: NAFO3DHVSJKKGOQL45AXS7H4LBZEF24QGZHHDZD3CHVQ4DDDWIUZSN5W
       Connected Server Version: 2.14.6
          Connected Server Name: limitsD
                 TLS Connection: no

JetStream Account Information:

Account Usage:

                        Storage: 0 B
                         Memory: 0 B
                        Streams: 0
                      Consumers: 0

Account Limits:

            Max Message Payload: 1.0 MiB

  Tier: Default:

      Configuration Requirements:

        Stream Requires Max Bytes Set: false
         Consumer Maximum Ack Pending: Unlimited

      Stream Resource Usage Limits:

### [08:42:03] D1 · max_streams: 3 allowed, the 4th refused
--- stream S1 ---
               First Sequence: 0
                Last Sequence: 0
             Active Consumers: 0
--- stream S2 ---
               First Sequence: 0
                Last Sequence: 0
             Active Consumers: 0
--- stream S3 ---
               First Sequence: 0
                Last Sequence: 0
             Active Consumers: 0
--- stream S4 ---
nats: error: could not create Stream: maximum number of streams reached (10027)
--- the raw API error for the 4th ---
apitime $JS.API.STREAM.CREATE.S4: 0.2ms, 146 bytes
   {"type":"io.nats.jetstream.api.v1.stream_create_response","error":{"code":400,"err_code":10027,"description":"maximum number of streams reached"}}
### [08:42:03] D2 · max_consumers: 2 allowed on the account, the 3rd refused
--- consumer C1 on S1 ---
    Redelivered Messages: 0
    Unprocessed Messages: 0
           Waiting Pulls: 0 of maximum 512
--- consumer C2 on S1 ---
    Redelivered Messages: 0
    Unprocessed Messages: 0
           Waiting Pulls: 0 of maximum 512
--- consumer C3 on S1 ---
nats: error: Consumer creation failed: maximum consumers limit reached (10026)
--- the raw API error for the 3rd ---
apitime $JS.API.CONSUMER.DURABLE.CREATE.S1.C3: 0.2ms, 146 bytes
   {"type":"io.nats.jetstream.api.v1.consumer_create_response","error":{"code":400,"err_code":10026,"description":"maximum consumers limit reached"}}
### [08:42:03] D3 · the per-STREAM max_consumers (a different limit, a different code)
               First Sequence: 0
                Last Sequence: 0
             Active Consumers: 0
    Unprocessed Messages: 0
           Waiting Pulls: 0 of maximum 512
nats: error: Consumer creation failed: maximum consumers limit reached (10026)
--- the raw API error ---
apitime $JS.API.CONSUMER.DURABLE.CREATE.PS.B: 0.2ms, 146 bytes
   {"type":"io.nats.jetstream.api.v1.consumer_create_response","error":{"code":400,"err_code":10026,"description":"maximum consumers limit reached"}}
### [08:42:04] D4 · max_file: fill S1 past 64 MB
stdout tail:

stderr tail:
08:42:04 Starting JetStream synchronous publisher benchmark [batch=0, clients=1, msg-size=128 B, msgs=600,000, multi-subject=false, multi-subject-max=100,000, multi-subject-randomize=false, purge=false, sleep=0s, stream=S1, subject=s1.bulk]
08:42:04 Using stream: S1
08:42:04 [1] Starting JetStream synchronous publisher, publishing 600,000 messages
08:42:16 Fatal error from client 0: publishing: publishing synchronously: nats: nats: API error: code=400 err_code=10002 description=resource limits exceeded for account
nats: error: publishing: publishing synchronously: nats: nats: API error: code=400 err_code=10002 description=resource limits exceeded for account
(12.4s)
--- the raw API error on a publish past the account's max_file ---
apitime s1.overflow: 0.7ms, 28 bytes
   {"stream":"S1","seq":406721}
             Maximum Messages: unlimited
                Maximum Bytes: unlimited
                     Messages: 406,721
                        Bytes: 64 MiB
Account Information

                           User: t
                        Account: TENANT (TENANT)
                 System Account: false
                        Expires: never
                      Client ID: 43
                      Client IP: 127.0.0.1
                            RTT: 52µs
              Headers Supported: true
                Maximum Payload: 1.0 MiB
                  Connected URL: nats://t:t@127.0.0.1:4321
              Connected Address: 127.0.0.1:4321
            Connected Server ID: NAFO3DHVSJKKGOQL45AXS7H4LBZEF24QGZHHDZD3CHVQ4DDDWIUZSN5W
       Connected Server Version: 2.14.6
          Connected Server Name: limitsD
                 TLS Connection: no

JetStream Account Information:

Account Usage:

                        Storage: 64 MiB
                         Memory: 0 B
                        Streams: 3
                      Consumers: 2

Account Limits:

            Max Message Payload: 1.0 MiB

  Tier: Default:

      Configuration Requirements:

        Stream Requires Max Bytes Set: false
         Consumer Maximum Ack Pending: Unlimited

      Stream Resource Usage Limits:

### [08:42:16] D5 · what the system account sees
╭───────────────────────────────────────────────────────────────────────────────────────────────────╮
│                                         JetStream Summary                                         │
├─────────┬─────────┬─────────┬───────────┬──────────┬────────┬────────┬────────┬─────────┬─────────┤
│ Server  │ Cluster │ Streams │ Consumers │ Messages │ Bytes  │ Memory │ File   │ API Req │ Pending │
├─────────┼─────────┼─────────┼───────────┼──────────┼────────┼────────┼────────┼─────────┼─────────┤
│ limitsD │         │ 4       │ 3         │ 406,721  │ 64 MiB │ 0 B    │ 64 MiB │ 32      │       0 │
├─────────┼─────────┼─────────┼───────────┼──────────┼────────┼────────┼────────┼─────────┼─────────┤
│         │         │ 4       │ 3         │ 406,721  │ 64 MiB │ 0 B    │ 64 MiB │ 32      │       0 │
╰─────────┴─────────┴─────────┴───────────┴──────────┴────────┴────────┴────────┴─────────┴─────────╯

{
    "memory": 0,
    "storage": 67108842,
    "reserved_memory": 0,
    "reserved_storage": 0,
    "accounts": 2,
    "ha_assets": 0,
    "api": {
        "level": 4,
        "total": 32,
        "errors": 11
    },
    "server_id": "NAFO3DHVSJKKGOQL45AXS7H4LBZEF24QGZHHDZD3CHVQ4DDDWIUZSN5W",
    "now": "2026-09-04T06:42:16.902319Z",
    "config": {
        "max_memory": 25769803776,
        "max_storage": 72575984640,
        "store_dir": "storeD/jetstream",
        "sync_interval": 120000000000,
        "strict": true
    },
    "limits": {},
    "streams": 4,
    "consumers": 3,
    "messages": 406721,
    "bytes": 67108842,
    "account_details": [
        {
            "name": "FREE",
            "id": "FREE",
            "memory": 0,
            "storage": 0,
            "reserved_memory": 18446744073709551615,
            "reserved_storage": 18446744073709551615,
            "accounts": 0,
            "ha_assets": 0,
            "api": {
                "level": 0,
                "total": 9,
                "errors": 4
            }
        },
        {
            "name": "TENANT",
            "id": "TENANT",
            "memory": 0,
            "storage": 67108842,
            "reserved_memory": 16777216,
            "reserved_storage": 67108864,
            "accounts": 0,
            "ha_assets": 0,
            "api": {
                "level": 0,
                "total": 23,
                "errors": 7
            }
        }
    ],
    "total": 2
}
### [08:42:16] D6 · reserved storage: what the tenant's limit costs before a byte is written
{'memory': 0, 'storage': 67108842, 'reserved_memory': 0, 'reserved_storage': 0, 'accounts': 2, 'streams': 4, 'consumers': 3, 'ha_assets': 0}
### [08:42:16] done
```

```
### [08:42:53] D7 · the tenant's own view of its limits, in full
JetStream Account Information:

Account Usage:

                        Storage: 64 MiB
                         Memory: 0 B
                        Streams: 3
                      Consumers: 2

Account Limits:

            Max Message Payload: 1.0 MiB

  Tier: Default:

      Configuration Requirements:

        Stream Requires Max Bytes Set: false
         Consumer Maximum Ack Pending: Unlimited

      Stream Resource Usage Limits:

                               Memory: 0 B of 16 MiB 
                    Memory Per Stream: Unlimited
                              Storage: 64 MiB of 64 MiB 
                   Storage Per Stream: Unlimited
                              Streams: 3 of 3
                            Consumers: Maximum 2 per stream
### [08:42:53] D8 · five single publishes at the edge of max_file
   {"error":{"code":400,"err_code":10002,"description":"resource limits exceeded for account"},"stream":"S1","seq":0}
   {"error":{"code":400,"err_code":10002,"description":"resource limits exceeded for account"},"stream":"S1","seq":0}
   {"error":{"code":400,"err_code":10002,"description":"resource limits exceeded for account"},"stream":"S1","seq":0}
   {"error":{"code":400,"err_code":10002,"description":"resource limits exceeded for account"},"stream":"S1","seq":0}
   {"error":{"code":400,"err_code":10002,"description":"resource limits exceeded for account"},"stream":"S1","seq":0}
TENANT storage 67108842 reserved_storage 67108864 headroom 22
### [08:42:53] D9 · purge S1: does the budget come back, and what does the tenant see
       Last Sequence: 406,721 @ 2026-09-04 08:42:16
    Active Consumers: 2
Account Usage:

   {"stream":"S1","seq":406722}
### [08:42:54] D10 · and the fourth stream, once one of the three is deleted
                Last Sequence: 0
             Active Consumers: 0
S1
S2
S4
### [08:42:54] done
```

```
### [08:43:19] D11 · is the account max_consumers per account or per stream?
--- consumers on S1 now ---
│ C2   │             │ 2026-09-04 08:42:03 │           0 │           0 │ never         │
╰──────┴─────────────┴─────────────────────┴─────────────┴─────────────┴───────────────╯


--- a consumer on S2, with the account's two already used on S1 ---
    Unprocessed Messages: 0
           Waiting Pulls: 0 of maximum 512
    Unprocessed Messages: 0
           Waiting Pulls: 0 of maximum 512
nats: error: Consumer creation failed: maximum consumers limit reached (10026)
--- totals ---
server consumers: 5
                      Consumers: 4
                            Consumers: Maximum 2 per stream
```

## Run E · subject cardinality, one axis at a time (`stream-topology-runE.sh`)

The same stream, the same 1,000,000 × 128 B messages, the same subject *shape* (`c.%07d.evt`,
13 bytes each) — only the number of distinct subjects changes, and each scene starts from a
purged lab so its RSS delta belongs to it alone.

```
### [08:57:55] versions
nats-server: v2.14.6
0.4.0
### [08:57:55] E · E1 ten subjects — 1,000,000 x 128 B over 10 subject(s)
healthy: standalone n1, /healthz ok
nats CLI: nats --server nats://sys:sys@127.0.0.1:4291 …
[E1 ten subjects baseline]
  varz mem 18677760 B = 17.8 MiB   ps rss 18.3 MiB   cpu 0%   subs 63   conns 0
  jsz streams 0 consumers 0 messages 0 bytes 0 memory 0 storage 0 api_total 0 api_errors 0
  store <lab>/n1/store: 0 KiB = 0.0 MiB, 1 dirs, 0 files
fill: 1000000 x 128B over 10 subject(s) in 5.56s (179717 msg/s, 0 errors)
[E1 ten subjects filled]
  varz mem 52379648 B = 50.0 MiB   ps rss 50.0 MiB   cpu 159.7%   subs 67   conns 0
  jsz streams 1 consumers 0 messages 1000000 bytes 171000000 memory 0 storage 171000000 api_total 2 api_errors 0
  store <lab>/n1/store: 167004 KiB = 163.1 MiB, 6 dirs, 23 files
--- stream info ---
streaminfo CARD: 0.2ms, reply 902 bytes, messages 1000000, bytes 171000000, num_subjects 10, subjects returned 0
--- subject details: STREAM.INFO with subjects_filter '>' ---
subjdetails CARD filter=> offset=0: 0.2ms, reply 1150 bytes, total 10, offset 0, limit 100000, num_subjects 10, subjects returned 10
--- and at offset 100000 (JSMaxSubjectDetails = 100,000 at v2.14.6) ---
subjdetails CARD filter=> offset=100000: 0.2ms, reply 913 bytes, total 10, offset 100000, limit 100000, num_subjects 10, subjects returned 0
--- nats stream subjects ---
nats stream subjects CARD: 0.01s, 12 stdout lines, 0 stderr lines
  first stderr line: 
--- a filtered consumer's first fetch, on one subject and on the wildcard ---
firstfetch one-subject: CONSUMER.CREATE 1.1ms (num_pending 100000), first message 2.5ms -> c.0000001.evt
firstfetch wildcard: CONSUMER.CREATE 1.1ms (num_pending 1000000), first message 0.1ms -> c.0000001.evt
--- clean stop, then the index.db the stop wrote ---
n1: stopped (SIGTERM, pid 15294)
738 <lab>/n1/store/jetstream/$G/streams/CARD/msgs/index.db
predicted sum(len(subject) + 4) = 10 x (13 + 4) = 170 bytes
E1 ten subjects restart after a clean stop: start -> /healthz 200 in 0.208s (code 200)
[E1 ten subjects after restart]
  varz mem 43581440 B = 41.6 MiB   ps rss 41.7 MiB   cpu 0%   subs 72   conns 0
  jsz streams 1 consumers 2 messages 1000000 bytes 171000000 memory 0 storage 171000000 api_total 0 api_errors 0
  store <lab>/n1/store: 167032 KiB = 163.1 MiB, 8 dirs, 30 files
[15500] 2026/09/04 08:58:34.588696 [INF] Took 130.758416ms to start JetStream
--- and once more, after a SIGKILL that follows a write ---
pubrate c.9999999.evt: 1000 x 128B in 0.006s (166432 msg/s, 0 errors)
n1: SIGKILL sent to pid 15500
E1 ten subjects restart after SIGKILL: start -> /healthz 200 in 0.356s (code 200)
[E1 ten subjects after the SIGKILL restart]
  varz mem 51331072 B = 49.0 MiB   ps rss 49.0 MiB   cpu 0%   subs 72   conns 0
  jsz streams 1 consumers 2 messages 1001000 bytes 171171000 memory 0 storage 171171000 api_total 0 api_errors 0
  store <lab>/n1/store: 167196 KiB = 163.3 MiB, 8 dirs, 30 files
[15989] 2026/09/04 08:58:50.948789 [INF] Took 245.812125ms to start JetStream
1
### [08:58:51] E · E2 ten thousand subjects — 1,000,000 x 128 B over 10000 subject(s)
healthy: standalone n1, /healthz ok
nats CLI: nats --server nats://sys:sys@127.0.0.1:4291 …
[E2 ten thousand subjects baseline]
  varz mem 18710528 B = 17.8 MiB   ps rss 18.3 MiB   cpu 0%   subs 63   conns 0
  jsz streams 0 consumers 0 messages 0 bytes 0 memory 0 storage 0 api_total 0 api_errors 0
  store <lab>/n1/store: 0 KiB = 0.0 MiB, 1 dirs, 0 files
fill: 1000000 x 128B over 10000 subject(s) in 5.40s (185289 msg/s, 0 errors)
[E2 ten thousand subjects filled]
  varz mem 81739776 B = 78.0 MiB   ps rss 78.0 MiB   cpu 163.7%   subs 67   conns 0
  jsz streams 1 consumers 0 messages 1000000 bytes 171000000 memory 0 storage 171000000 api_total 2 api_errors 0
  store <lab>/n1/store: 167004 KiB = 163.1 MiB, 6 dirs, 23 files
--- stream info ---
streaminfo CARD: 0.2ms, reply 905 bytes, messages 1000000, bytes 171000000, num_subjects 10000, subjects returned 0
--- subject details: STREAM.INFO with subjects_filter '>' ---
subjdetails CARD filter=> offset=0: 2.3ms, reply 200927 bytes, total 10000, offset 0, limit 100000, num_subjects 10000, subjects returned 10000
--- and at offset 100000 (JSMaxSubjectDetails = 100,000 at v2.14.6) ---
subjdetails CARD filter=> offset=100000: 2.3ms, reply 919 bytes, total 10000, offset 100000, limit 100000, num_subjects 10000, subjects returned 0
--- nats stream subjects ---
nats stream subjects CARD: 0.04s, 3341 stdout lines, 0 stderr lines
  first stderr line: 
--- a filtered consumer's first fetch, on one subject and on the wildcard ---
firstfetch one-subject: CONSUMER.CREATE 0.9ms (num_pending 100), first message 1.5ms -> c.0000001.evt
firstfetch wildcard: CONSUMER.CREATE 1.0ms (num_pending 1000000), first message 0.6ms -> c.0000001.evt
--- clean stop, then the index.db the stop wrote ---
n1: stopped (SIGTERM, pid 16094)
170549 <lab>/n1/store/jetstream/$G/streams/CARD/msgs/index.db
predicted sum(len(subject) + 4) = 10000 x (13 + 4) = 170000 bytes
E2 ten thousand subjects restart after a clean stop: start -> /healthz 200 in 0.258s (code 200)
[E2 ten thousand subjects after restart]
  varz mem 69926912 B = 66.7 MiB   ps rss 66.7 MiB   cpu 0%   subs 72   conns 0
  jsz streams 1 consumers 2 messages 1000000 bytes 171000000 memory 0 storage 171000000 api_total 0 api_errors 0
  store <lab>/n1/store: 167196 KiB = 163.3 MiB, 8 dirs, 30 files
[16307] 2026/09/04 08:58:57.558926 [INF] Took 178.145625ms to start JetStream
--- and once more, after a SIGKILL that follows a write ---
pubrate c.9999999.evt: 1000 x 128B in 0.007s (151052 msg/s, 0 errors)
n1: SIGKILL sent to pid 16307
E2 ten thousand subjects restart after SIGKILL: start -> /healthz 200 in 0.361s (code 200)
[E2 ten thousand subjects after the SIGKILL restart]
  varz mem 73744384 B = 70.3 MiB   ps rss 70.6 MiB   cpu 0%   subs 72   conns 0
  jsz streams 1 consumers 2 messages 1001000 bytes 171171000 memory 0 storage 171171000 api_total 0 api_errors 0
  store <lab>/n1/store: 167360 KiB = 163.4 MiB, 8 dirs, 30 files
[16744] 2026/09/04 08:59:13.529033 [INF] Took 279.102375ms to start JetStream
1
### [08:59:13] E · E3 one million subjects — 1,000,000 x 128 B over 1000000 subject(s)
healthy: standalone n1, /healthz ok
nats CLI: nats --server nats://sys:sys@127.0.0.1:4291 …
[E3 one million subjects baseline]
  varz mem 18268160 B = 17.4 MiB   ps rss 17.8 MiB   cpu 0%   subs 63   conns 0
  jsz streams 0 consumers 0 messages 0 bytes 0 memory 0 storage 0 api_total 0 api_errors 0
  store <lab>/n1/store: 0 KiB = 0.0 MiB, 1 dirs, 0 files
fill: 1000000 x 128B over 1000000 subject(s) in 5.05s (198078 msg/s, 0 errors)
[E3 one million subjects filled]
  varz mem 308297728 B = 294.0 MiB   ps rss 294.1 MiB   cpu 181.9%   subs 67   conns 0
  jsz streams 1 consumers 0 messages 1000000 bytes 171000000 memory 0 storage 171000000 api_total 2 api_errors 0
  store <lab>/n1/store: 167004 KiB = 163.1 MiB, 6 dirs, 23 files
--- stream info ---
streaminfo CARD: 0.2ms, reply 907 bytes, messages 1000000, bytes 171000000, num_subjects 1000000, subjects returned 0
--- subject details: STREAM.INFO with subjects_filter '>' ---
subjdetails CARD filter=> offset=0: 372.7ms, reply 1800931 bytes, total 1000000, offset 0, limit 100000, num_subjects 1000000, subjects returned 100000
--- and at offset 100000 (JSMaxSubjectDetails = 100,000 at v2.14.6) ---
subjdetails CARD filter=> offset=100000: 289.8ms, reply 1800936 bytes, total 1000000, offset 100000, limit 100000, num_subjects 1000000, subjects returned 100000
--- nats stream subjects ---
nats stream subjects CARD: 5.40s, 333341 stdout lines, 0 stderr lines
  first stderr line: 
--- a filtered consumer's first fetch, on one subject and on the wildcard ---
firstfetch one-subject: CONSUMER.CREATE 1.0ms (num_pending 1), first message 3.3ms -> c.0000001.evt
firstfetch wildcard: CONSUMER.CREATE 18.6ms (num_pending 1000000), first message 19.2ms -> c.0000001.evt
--- clean stop, then the index.db the stop wrote ---
n1: stopped (SIGTERM, pid 16819)
17000550 <lab>/n1/store/jetstream/$G/streams/CARD/msgs/index.db
predicted sum(len(subject) + 4) = 1000000 x (13 + 4) = 17000000 bytes
E3 one million subjects restart after a clean stop: start -> /healthz 200 in 0.531s (code 200)
[E3 one million subjects after restart]
  varz mem 215318528 B = 205.3 MiB   ps rss 205.6 MiB   cpu 0%   subs 72   conns 0
  jsz streams 1 consumers 2 messages 1000000 bytes 171000000 memory 0 storage 171000000 api_total 0 api_errors 0
  store <lab>/n1/store: 183632 KiB = 179.3 MiB, 8 dirs, 30 files
[17084] 2026/09/04 08:59:26.172664 [INF] Took 421.210167ms to start JetStream
--- and once more, after a SIGKILL that follows a write ---
pubrate c.9999999.evt: 1000 x 128B in 0.006s (162045 msg/s, 0 errors)
n1: SIGKILL sent to pid 17084
E3 one million subjects restart after SIGKILL: start -> /healthz 200 in 0.688s (code 200)
[E3 one million subjects after the SIGKILL restart]
  varz mem 215613440 B = 205.6 MiB   ps rss 206.0 MiB   cpu 111%   subs 72   conns 0
  jsz streams 1 consumers 2 messages 1001000 bytes 171171000 memory 0 storage 171171000 api_total 0 api_errors 0
  store <lab>/n1/store: 184656 KiB = 180.3 MiB, 8 dirs, 30 files
[17567] 2026/09/04 08:59:42.553020 [INF] Took 604.9495ms to start JetStream
1
### [08:59:42] done
```

## Run F · the three ways to make a second copy (`stream-topology-runF.sh` … `-runF5.sh`)

F is the first pass; **its shape (iii) delivered nothing**, and F2/F3 are why. F4's two transform
cases were refused because the field name in that pass was wrong (`subject_transform_dest`; the
server's `StreamSource` carries `subject_transforms: [{src, dest}]`, `stream.go:411` and `:174`),
and F5 redoes them. F4's `I2` traceback is the run script reading `config` out of an error
response — the refusal it was testing for.

```
### [09:00:12] versions
nats-server: v2.14.6
0.4.0
### [09:00:12] fresh lab: down --purge, up 1
healthy: standalone n1, /healthz ok
nats CLI: nats --server nats://sys:sys@127.0.0.1:4291 …
[F0 baseline]
  varz mem 18448384 B = 17.6 MiB   ps rss 18.1 MiB   cpu 0%   subs 63   conns 0
  jsz streams 0 consumers 0 messages 0 bytes 0 memory 0 storage 0 api_total 0 api_errors 0
  store <lab>/n1/store: 0 KiB = 0.0 MiB, 1 dirs, 0 files
### [09:00:12] F1 · SRC: 200,000 x 128 B over 100 subjects
fill: 200000 x 128B over 100 subject(s) in 1.14s (174942 msg/s, 0 errors)
[F1 SRC filled]
  varz mem 51412992 B = 49.0 MiB   ps rss 49.0 MiB   cpu 147.2%   subs 67   conns 0
  jsz streams 1 consumers 0 messages 200000 bytes 34200000 memory 0 storage 34200000 api_total 2 api_errors 0
  store <lab>/n1/store: 33408 KiB = 32.6 MiB, 6 dirs, 7 files
  SRC: 33408 KiB
### [09:00:14] F2 · (i) a mirror
stream add MIR --mirror SRC: 0.019s
Stream MIR was created

Information for Stream MIR created 2026-09-04 09:00:14

                     Replicas: 1
                      Storage: File
lagwait MIR: reached 200000 messages in 0.521s
  SRC: 33408 KiB
  MIR: 33408 KiB
[F2 mirror caught up]
  varz mem 140099584 B = 133.6 MiB   ps rss 133.6 MiB   cpu 95.3%   subs 77   conns 0
  jsz streams 2 consumers 0 messages 400000 bytes 68400000 memory 0 storage 68400000 api_total 28 api_errors 0
  store <lab>/n1/store: 66816 KiB = 65.2 MiB, 9 dirs, 14 files
--- what the mirror's config looks like ---
apitime $JS.API.STREAM.INFO.MIR: 0.2ms, 916 bytes
   {"type":"io.nats.jetstream.api.v1.stream_info_response","total":0,"offset":0,"limit":0,"config":{"name":"MIR","retention":"limits","max_consumers":-1,"max_msgs":-1,"max_bytes":-1,"max_age":0,"max_msgs_per_subject":-1,"max_msg_size":-1,"discard":"old","storage":"file","num_replicas":1,"mirror":{"name":"SRC"},"compression":"none","allow_direct":true,"mirror_direct":true,"sealed":false,"deny_delete":
--- can you publish into a mirror? ---
09:00:14 Published 15 bytes to "src.00001.evt"
09:00:14 Stored in Stream: SRC Sequence: 200,001
   
--- a mirror has no subjects of its own: what nats stream info says ---
subjects: None mirror: {'name': 'SRC'} mirror_direct: True state.messages: 200001 first_seq: 1
--- and a direct get from the mirror (mirror_direct off, then on) ---
apitime $JS.API.DIRECT.GET.MIR.src.00001.evt: 0.4ms, 15 bytes
   direct into SRC
mirror_direct update: ok, mirror_direct=True
apitime $JS.API.DIRECT.GET.MIR.src.00001.evt: 0.1ms, 15 bytes
   direct into SRC
### [09:00:15] F3 · (ii) a sourcing stream
stream add SRCD --source SRC --subjects own.>: 0.018s
Stream SRCD was created

Information for Stream SRCD created 2026-09-04 09:00:15

                     Subjects: own.>
                     Replicas: 1
lagwait SRCD: reached 200001 messages in 0.652s
  SRC: 33408 KiB
  MIR: 33408 KiB
  SRCD: 46192 KiB
[F3 sourcing stream caught up]
  varz mem 168902656 B = 161.1 MiB   ps rss 161.1 MiB   cpu 77.6%   subs 86   conns 0
  jsz streams 3 consumers 0 messages 600003 bytes 115689135 memory 0 storage 115689135 api_total 64 api_errors 0
  store <lab>/n1/store: 113008 KiB = 110.4 MiB, 12 dirs, 22 files
--- a sourcing stream CAN have its own subjects ---
09:00:15 Published 28 bytes to "own.thing"
09:00:15 Stored in Stream: SRCD Sequence: 200,002
streaminfo SRCD: 0.2ms, reply 982 bytes, messages 200002, bytes 47289086, num_subjects 101, subjects returned 0
--- do the source's consumers count against max_consumers? (numLimitableConsumers) ---
conslist SRC: CONSUMER.NAMES 0.2ms (total 0), CONSUMER.LIST 0.1ms (106 bytes)
  SRC consumer_count 0
  MIR consumer_count 0
  SRCD consumer_count 0
### [09:00:15] F4 · (iii) a consumer that delivers into a second stream
push consumer SRC/TOCOPY -> copy.evt created in 0.9ms
lagwait COPY: TIMED OUT at 0 of 200000 after 300s
  SRC: 33424 KiB
  MIR: 33412 KiB
  SRCD: 46196 KiB
  COPY: 12 KiB
[F4 consumer copy caught up]
  varz mem 169607168 B = 161.8 MiB   ps rss 161.8 MiB   cpu 2.2%   subs 92   conns 0
  jsz streams 4 consumers 1 messages 600004 bytes 115689202 memory 0 storage 115689202 api_total 12444 api_errors 0
  store <lab>/n1/store: 113044 KiB = 110.4 MiB, 16 dirs, 32 files
--- what the copy actually holds: subject, sequence, headers ---
SRC: seq 1 subject src.00001.evt hdrs False
MIR: seq 1 subject src.00001.evt hdrs False
SRCD: seq 1 subject src.00001.evt hdrs True
COPY: error {'code': 404, 'err_code': 10037, 'description': 'no message found'}
### [09:05:16] F5 · lag: 20,000 more messages into SRC, how fast does each copy follow
pubrate src.00001.evt: 20000 x 128B in 0.136s (146687 msg/s, 0 errors)
lagwait MIR: reached 220001 messages in 0.000s
lagwait SRCD: reached 220002 messages in 0.000s
lagwait COPY: TIMED OUT at 0 of 220000 after 120s
streaminfo SRC: 0.2ms, reply 901 bytes, messages 220001, bytes 37620058, num_subjects 100, subjects returned 0
streaminfo MIR: 0.1ms, reply 915 bytes, messages 220001, bytes 37620058, num_subjects 100, subjects returned 0
streaminfo SRCD: 0.2ms, reply 982 bytes, messages 220002, bytes 52029086, num_subjects 101, subjects returned 0
streaminfo COPY: 0.2ms, reply 853 bytes, messages 0, bytes 0, num_subjects None, subjects returned 0
  SRC: 36944 KiB
  MIR: 36932 KiB
  SRCD: 50928 KiB
  COPY: 12 KiB
[F5 after 20,000 more]
  varz mem 169820160 B = 162.0 MiB   ps rss 162.0 MiB   cpu 2%   subs 92   conns 0
  jsz streams 4 consumers 1 messages 660004 bytes 127269202 memory 0 storage 127269202 api_total 17360 api_errors 1
  store <lab>/n1/store: 124816 KiB = 121.9 MiB, 16 dirs, 33 files
### [09:07:16] F6 · what each shape does with a delete on the source
SRC first_seq 1
delete seq 5 from SRC: {"type":"io.nats.jetstream.api.v1.stream_msg_delete_response","success":true}
  SRC seq 5: gone: {"code": 404, "err_code": 10037, "description": "no message found"}
  MIR seq 5: still there: src.00005.evt
  SRCD seq 5: still there: src.00005.evt
  COPY seq 5: gone: {"code": 404, "err_code": 10037, "description": "no message found"}
### [09:07:18] F7 · restart: what each shape costs at boot
n1: stopped (SIGTERM, pid 18141)
restart with SRC + mirror + source + copy: /healthz 200 in 0.189s
[24569] 2026/09/04 09:07:19.009548 [INF]   Restored 0 messages for stream '$G > COPY' in 0s
[24569] 2026/09/04 09:07:19.009683 [INF]   Restored 220,000 messages for stream '$G > SRC' in 0s
[24569] 2026/09/04 09:07:19.009694 [INF]   Restored 220,001 messages for stream '$G > MIR' in 0s
[24569] 2026/09/04 09:07:19.010309 [INF]   Restored 220,002 messages for stream '$G > SRCD' in 1ms
[24569] 2026/09/04 09:07:19.010349 [INF] Took 1.901416ms to start JetStream
[F7 after restart]
  varz mem 25182208 B = 24.0 MiB   ps rss 24.2 MiB   cpu 0%   subs 84   conns 0
  jsz streams 4 consumers 1 messages 660003 bytes 127269031 memory 0 storage 127269031 api_total 1 api_errors 0
  store <lab>/n1/store: 124816 KiB = 121.9 MiB, 16 dirs, 33 files
### [09:07:19] done
```

```
### [09:08:37] versions
nats-server: v2.14.6
0.4.0
nats CLI: nats --server nats://sys:sys@127.0.0.1:4291 …
### [09:08:38] G1 · SRC2 with 1000 messages, COPY2 on copy2.>, and no subscriber anywhere
fill: 1000 x 128B over 10 subject(s) in 0.01s (150104 msg/s, 0 errors)
--- does COPY2's subscription show up in the account sublist? ---
num_subscriptions 11
   $JS.API.DIRECT.GET.SRC2 sid 2 account $G
   $JS.API.DIRECT.GET.SRC2.> sid 3 account $G
   $JS.API.DIRECT.GET.COPY2 sid 2 account $G
   $JS.API.DIRECT.GET.COPY2.> sid 3 account $G
   $JS.API.> sid 5 account $G
   src2.> sid 1 account $G
   copy2.> sid 1 account $G
   $SYS.REQ.SERVER.PING.CONNZ sid 2 account $G
   $SYS.REQ.USER.INFO sid 4 account $G
   $SYS.REQ.ACCOUNT.PING.CONNZ sid 1 account $G
   $SYS.REQ.ACCOUNT.PING.STATZ sid 3 account $G
create: ok
consumer after 3s: delivered {'consumer_seq': 0, 'stream_seq': 0} num_pending 1000 push_bound None
COPY2 messages: 0
### [09:08:41] G2 · the same consumer with a real subscriber on copy2.evt
consumer with a subscriber: delivered {'consumer_seq': 1000, 'stream_seq': 1000, 'last_active': '2026-09-04T07:08:41.52868Z'} num_pending 0 push_bound None
COPY2 messages: 1000
--- what the subscriber saw ---
09:08:41 Subscribing on copy2.evt 
[#1] Received on "src2.001.evt" with reply "$JS.ACK.SRC2.TOCOPY.1.1.1.1788505718393227000.999"
vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv


[#2] Received on "src2.002.evt" with reply "$JS.ACK.SRC2.TOCOPY.1.2.2.1788505718393295000.998"
vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv


[#3] Received on "src2.003.evt" with reply "$JS.ACK.SRC2.TOCOPY.1.3.3.1788505718393302000.997"
vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv

COPY2 messages after the subscriber ran: 1000
COPY2 seq 1: ('src2.001.evt', False)
### [09:08:43] G3 · the shape that actually works: a client that pulls from SRC2 and publishes into COPY2
(the run script's own python helper raised here; see the note above this transcript)
208	<lab>/n1/store/jetstream/$G/streams/COPY2
52	<lab>/n1/store/jetstream/$G/streams/COPY3
204	<lab>/n1/store/jetstream/$G/streams/SRC2
### [09:10:44] done
```

```
### [09:11:45] versions
nats-server: v2.14.6
0.4.0
nats CLI: nats --server nats://sys:sys@127.0.0.1:4291 …
### [09:11:45] H1 · a push consumer with only a WILDCARD subscriber on its deliver subject
fill: 1000 x 128B over 10 subject(s) in 0.01s (161158 msg/s, 0 errors)
--- subscriber: nats sub 'd.>' (a wildcard that covers d.evt) ---
create: ok
with only a WILDCARD subscriber d.> : delivered 0 num_pending 1000
--- what the wildcard subscriber saw ---
0
### [09:11:50] H2 · now an EXACT subscriber on d.evt, same consumer
with an EXACT subscriber d.evt : delivered 349 num_pending 651
3
### [09:11:52] H3 · the working relay: pull from S, publish into COPY, on two connections
relay: 1000 messages pulled from S and republished into COPY in 0.01s (103304 msg/s), 0 publish errors
COPY: 1000 messages, 170000 bytes, first_seq 1
COPY seq 1: copy.001.evt hdrs False
S: 1000 messages, 167000 bytes
176	<lab>/n1/store/jetstream/$G/streams/COPY
196	<lab>/n1/store/jetstream/$G/streams/S
### [09:11:52] H4 · and the same 1000 messages copied by a mirror, for the price comparison
lagwait MIR2: reached 1000 messages in 0.150s
176	<lab>/n1/store/jetstream/$G/streams/COPY
172	<lab>/n1/store/jetstream/$G/streams/MIR2
196	<lab>/n1/store/jetstream/$G/streams/S
conslist S: CONSUMER.NAMES 0.2ms (total 2), CONSUMER.LIST 0.2ms (1169 bytes)
### [09:11:52] done
```

```
### [09:12:46] versions
nats-server: v2.14.6
0.4.0
nats CLI: nats --server nats://sys:sys@127.0.0.1:4291 …
### [09:12:47] I0 · ORIG on orig.>, 10,000 messages over 4 subjects
fill: 10000 x 128B over 4 subject(s) in 0.06s (172509 msg/s, 0 errors)
### [09:12:47] I1 · a stream that is a mirror AND has subjects of its own
  mirror + subjects                    -> REFUSED 10034 stream mirrors can not contain subjects
  mirror + sources                     -> REFUSED 10031 stream mirrors can not also contain other sources
  mirror, filtered                     -> created M3
  mirror, transformed                  -> REFUSED 10025 invalid JSON: json: unknown field "subject_transform_dest"
  source + own subjects + transform    -> REFUSED 10025 invalid JSON: json: unknown field "subject_transform_dest"
  two sources of the same stream       -> created S2
  ORIG: 10000 messages, num_subjects 4, subjects cfg ['orig.>']
      seq 1 subject: orig.1.evt
  M3: 2500 messages, num_subjects 1, subjects cfg None
      seq 1 subject: orig.1.evt
  M4: not there
  S1: not there
  S2: 5000 messages, num_subjects 2, subjects cfg None
      seq 1 subject: orig.2.evt
### [09:12:49] I2 · adding subjects to an existing mirror by update
  add subjects to a mirror: REFUSED 10034 stream mirrors can not contain subjects
(the run script's own python helper raised here; see the note above this transcript)
### [09:12:49] I3 · delete the origin: what happens to the mirror and to the sourcing stream
  M3: still here, 2500 messages
  M4: gone
  S1: gone
  S2: still here, 5000 messages
--- and can you still read from the mirror ---
apitime $JS.API.DIRECT.GET.M3.orig.1.evt: 0.1ms, 0 bytes
   
--- the log ---
[29931] 2026/09/04 09:12:46.910229 [INF] -------------------------------------------
[29931] 2026/09/04 09:12:46.910451 [INF] Took 450.042µs to start JetStream
[29931] 2026/09/04 09:12:46.910478 [INF] Listening for client connections on 127.0.0.1:4291
[29931] 2026/09/04 09:12:46.910486 [INF] Server is ready
[29931] 2026/09/04 09:12:47.188984 [WRN] Invalid JetStream request '$G > $JS.API.STREAM.CREATE.M4': json: unknown field "subject_transform_dest"
[29931] 2026/09/04 09:12:47.189099 [WRN] Invalid JetStream request '$G > $JS.API.STREAM.CREATE.S1': json: unknown field "subject_transform_dest"
### [09:12:52] done
```

```
### [09:13:21] versions
nats-server: v2.14.6
0.4.0
nats CLI: nats --server nats://sys:sys@127.0.0.1:4291 …
### [09:13:22] J0 · ORIG on orig.>, 10,000 messages over 4 subjects
fill: 10000 x 128B over 4 subject(s) in 0.06s (173944 msg/s, 0 errors)
### [09:13:22] J1 · a transformed mirror and a sourcing stream with its own subjects and a transform
  mirror + subject_transforms          -> created M4
  source + own subjects + transform    -> created S1
  ORIG: 10000 messages, num_subjects 4, cfg subjects ['orig.>']
      seq 1 subject: orig.1.evt  hdrs False
  M4: 10000 messages, num_subjects 4, cfg subjects None
      seq 1 subject: copy.1  hdrs False
  S1: 10000 messages, num_subjects 4, cfg subjects ['own.>']
      seq 1 subject: from-orig.1  hdrs True
  --- publish own.thing into the sourcing stream ---
      {"stream":"S1","seq":10001}
### [09:13:24] J2 · disk: origin, mirror, sourcing stream, for the same 10,000 messages
1612	<lab>/n1/store/jetstream/$G/streams/M4
1652	<lab>/n1/store/jetstream/$G/streams/ORIG
2588	<lab>/n1/store/jetstream/$G/streams/S1
  ORIG: 10000 messages, 1680000 bytes (168.0 B/msg)
  M4: 10000 messages, 1640000 bytes (164.0 B/msg)
  S1: 10001 messages, 2638937 bytes (263.9 B/msg)
### [09:13:24] done
```

```
S1 seq 1 subject: from-orig.1
S1 seq 1 headers (decoded):
NATS/1.0
Nats-Stream-Source: ORIG 1 orig.*.evt from-orig.{{wildcard(1)}} orig.1.evt
```
