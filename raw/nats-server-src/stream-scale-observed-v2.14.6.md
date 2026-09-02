<!-- source: run locally against nats-server v2.14.6 (`nats-server --version` -> v2.14.6) and
     nats CLI 0.4.0 · observed 2026-09-02 · scripts, commands and output verbatim below; the lab directory
     (tools/lab/cluster.sh's `${TMPDIR}/nats-lab`) is shortened to <lab>. The two run scripts are
     `stream-scale-runE.sh` and `stream-scale-runD.sh` in this directory, with the `stream-scale-agg*.json`
     stream configs; the goroutine samples and iostat captures they mention are in the maintainer's local
     cache, not in raw/. Where a transcript contained a traceback from the run script's *own* python helper
     (a `stream info` read while the server was still restoring), that traceback is replaced by a one-line
     note; nothing the server or the CLI printed is edited. -->

# Observed on nats-server v2.14.6 — a 50 M-message stream restarted six ways, a sourcing stream with an empty source, 1.2 M subjects against 6, and `--max-msgs` past a billion

Runs D, E and F of step 4 of `inbox/plan-the-runnable-scouts-2026-09-02.md` (question-bank rows 4, 5,
9 and 13), made after reading the threads (`raw/gh-discussions/gh-8001.md`, `gh-8333.md`, `gh-5202.md`,
`gh-7147.md`, `gh-7032.md`) and the source at v2.14.6 (`filestore-recovery-v2.14.6.md` in this
directory). One standalone server through `bash tools/lab/cluster.sh up 1` (`127.0.0.1:4291`,
monitoring `8291`), Apple silicon, an internal SSD, macOS. **Every number is one laptop.** They are
evidence of a *mechanism* and of a *ratio* — which restart path is taken, what it reads, what it
costs relative to another — never of a limit or of a figure to size by.

- **Run E** — row 9: `CARD`, 3,000,000 × 100 B over **1,200,000** subjects (above
  `highCardinalityThreshold`), against `FLAT`, the same messages over 6 subjects. RSS, the periodic
  `index.db`, and the restart after a clean stop, after SIGKILL, and with `index.db` deleted. Plus the
  probes that followed, which turned a mistaken filter into a finding.
- **Run D** — row 13: `EVENTS`, 50,000,000 × 100 B over 6 subjects (the thread's shape without its
  S2 compression), restarted after a clean stop, after SIGKILL, with `index.db` deleted, and then as
  the source of `AGG`, a stream with two and three sources one of which is empty.
- **Run F** — rows 4 and 5: `--max-msgs 1000000000` and `10000000000`, and the on-disk arithmetic.

## What the runs settled, in one table

| question | measured | where |
|---|---|---|
| a clean stop, then start, 50.2–50.6 M messages | **3–27 ms** (`Restored … in`) in six restarts made with the disk idle; **1.8–7.0 s** in the four restarts made within seconds of a bulk write (6.2 GB fill, a 1.1 GB sourcing catch-up, a full rebuild) | D2, D5a–d, D2-redo, b2b1–3, W1 |
| SIGKILL after new writes, then start | `Filestore [EVENTS] Stream state outdated, last block has additional entries, will rebuild`, then **6.372 s** for 50.6 M messages / 6.8 GB at 1.0–1.6 GB/s of reads; 37 of 37 goroutine samples in `recoverMsgs` → `rebuildState` (read, HighwayHash, subject-tree inserts) | D3-redo |
| `index.db` deleted from a cleanly stopped store, then start | no warning; **9.524 s** for 50.2 M | D4 |
| a stream with an **empty source**, clean stop, start | `AGG` (8.43 M messages, 1.6 GB, three sources, one empty): **2.572 s / 2.577 s**; 15 of 15 samples in `startingSequenceForSources` → `LoadPrevMsgMulti` → `LoadPrevMsg` → `prevMatching` → `loadMsgsWithLock`; from the page cache, ~620 MB/s, no disk reads | D5e, D5f |
| the same stream with the empty source removed | **23 ms** | D5g |
| the same, in the busy-disk regime | 4.656 s with the empty source, 1.645 s without | D5a, D5b |
| 1.2 M subjects: RSS | 17.7 → **540.6 MiB** after `CARD`; **+87.4 MiB** more after `FLAT` (same messages, 6 subjects) ⇒ ~**380 B per subject** of whole-process RSS, block caches included | E |
| 1.2 M subjects: the periodic `index.db` | none in 5 min (`FLAT`'s appeared at +130 s, 1,324 B); the clean stop wrote `CARD`'s: **19,201,304 B** (predicted Σ(len+4) = 18,088,890 B) | E |
| 1.2 M subjects: restart | clean stop **153 ms** (`FLAT` 2 ms); SIGKILL **1.024 s** (`FLAT` 303 ms); no `index.db` **850 ms** (`FLAT` 309 ms) — 3.2 M messages each | E1, E2, E4 |
| `max_msgs` past a billion | `1000000000` and `10000000000` accepted; 134 B/msg on disk ⇒ 10⁹ messages of this shape = **124.8 GiB**, as arithmetic | F |
| a `*` inside a token as a consumer filter | `pt.1*` on a 5-message stream: `num_pending` **3**, the subjects report **3 subjects**, delivery **nothing**, direct get **no message found** | SI probe |

Not measured: the thread's S2 compression (skipped, as the pick allowed — the mechanism is settled
without it); a filtered read timed for the `checkSkipFirstBlock` guard (run E's step E3 used
`card.1*`, which is not a wildcard, and became the SI probe instead); anything on a replicated stream
(the scan runs after the `Restored` line there, `stream.go:4966`); disk-bound behaviour (the page cache
held every store after the first read).

---

## Run E · the cardinality pair (`stream-scale-runE.sh`)

```
### [23:32:40] versions
nats-server: v2.14.6
0.4.0

### [23:32:40] fresh lab: up 1
binary: nats-server: v2.14.6 (/opt/homebrew/bin/nats-server)
lab dir: <lab>
n1: pid 70328  client 127.0.0.1:4291  http 127.0.0.1:8291  log <lab>/n1/n1.log
healthy: standalone n1, /healthz ok
nats CLI: nats --server nats://sys:sys@127.0.0.1:4291 …

### [23:32:40] baseline
varz mem: 18513920 bytes = 17.7 MiB
ps rss: 18464 KB = 18.0312 MiB

### [23:32:40] fill CARD: 3,000,000 × 100 B over 1,200,000 subjects
23:32:40 Starting JetStream asynchronous publisher benchmark [batch=500, clients=1, dedup-window=2m0s, deduplication=false, max-bytes=4,294,967,296, msg-size=100 B, msgs=3,000,000, multi-subject=true, multi-subject-max=1,200,000, multi-subject-randomize=false, purge=false, replicas=1, sleep=0s, storage=file, stream=CARD, subject=card.*]
23:32:40 Using stream: CARD
23:32:40 [1] Starting JetStream asynchronous publisher, publishing 3,000,000 messages
NATS JetStream asynchronous publisher stats: 356,627 msgs/sec ~ 34 MiB/sec ~ min: 1,166.83us ~ avg: 1,401.49us ~ max: 10,655.33us ~ P50: 1,334.91us ~ P90: 1,574.54us ~ P99: 2,670.66us ~ P99.9: 7,155.95us
stream CARD subjects ['card.*'] messages 3000000 bytes 426000000 first 1 last 3000000 num_subjects 1200000 num_deleted 0
varz mem: 566853632 bytes = 540.6 MiB
ps rss: 553568 KB = 540.594 MiB
CARD: 51 files in msgs/, 406M, index.db: 

### [23:32:50] fill FLAT: 3,000,000 × 100 B over 6 subjects
23:32:51 Starting JetStream asynchronous publisher benchmark [batch=500, clients=1, dedup-window=2m0s, deduplication=false, max-bytes=4,294,967,296, msg-size=100 B, msgs=3,000,000, multi-subject=true, multi-subject-max=6, multi-subject-randomize=false, purge=false, replicas=1, sleep=0s, storage=file, stream=FLAT, subject=flat.*]
23:32:51 Using stream: FLAT
23:32:51 [1] Starting JetStream asynchronous publisher, publishing 3,000,000 messages
NATS JetStream asynchronous publisher stats: 400,720 msgs/sec ~ 38 MiB/sec ~ min: 1,060.79us ~ avg: 1,247.18us ~ max: 13,134.95us ~ P50: 1,175.33us ~ P90: 1,413.45us ~ P99: 2,531.62us ~ P99.9: 6,305.70us
stream FLAT subjects ['flat.*'] messages 3000000 bytes 408000000 first 1 last 3000000 num_subjects 6 num_deleted 0
varz mem: 658554880 bytes = 628.0 MiB
ps rss: 643120 KB = 628.047 MiB
FLAT: 49 files in msgs/, 389M, index.db: 

### [23:33:00] predicted index.db subject term for CARD: sum(len(subject)+4)
18088890 bytes for 1,200,000 subjects; FLAT: 60

### [23:33:00] watch for the periodic index.db (flushStreamStateLoop) for up to 5 min
[23:33:10] +10s  CARD index.db:    FLAT index.db: 
[23:33:20] +20s  CARD index.db:    FLAT index.db: 
[23:33:30] +30s  CARD index.db:    FLAT index.db: 
[23:33:40] +40s  CARD index.db:    FLAT index.db: 
[23:33:50] +50s  CARD index.db:    FLAT index.db: 
[23:34:00] +60s  CARD index.db:    FLAT index.db: 
[23:34:10] +70s  CARD index.db:    FLAT index.db: 
[23:34:20] +80s  CARD index.db:    FLAT index.db: 
[23:34:30] +90s  CARD index.db:    FLAT index.db: 
[23:34:40] +100s  CARD index.db:    FLAT index.db: 
[23:34:50] +110s  CARD index.db:    FLAT index.db: 
[23:35:01] +120s  CARD index.db:    FLAT index.db: 
[23:35:11] +130s  CARD index.db:    FLAT index.db: 1324 bytes
[23:35:21] +140s  CARD index.db:    FLAT index.db: 1324 bytes
[23:35:31] +150s  CARD index.db:    FLAT index.db: 1324 bytes
[23:35:41] +160s  CARD index.db:    FLAT index.db: 1324 bytes
[23:35:51] +170s  CARD index.db:    FLAT index.db: 1324 bytes
[23:36:01] +180s  CARD index.db:    FLAT index.db: 1324 bytes
[23:36:11] +190s  CARD index.db:    FLAT index.db: 1324 bytes
[23:36:21] +200s  CARD index.db:    FLAT index.db: 1324 bytes
[23:36:31] +210s  CARD index.db:    FLAT index.db: 1324 bytes
[23:36:41] +220s  CARD index.db:    FLAT index.db: 1324 bytes
[23:36:51] +230s  CARD index.db:    FLAT index.db: 1324 bytes
[23:37:01] +240s  CARD index.db:    FLAT index.db: 1324 bytes
[23:37:11] +250s  CARD index.db:    FLAT index.db: 1324 bytes
[23:37:21] +260s  CARD index.db:    FLAT index.db: 1324 bytes
[23:37:31] +270s  CARD index.db:    FLAT index.db: 1324 bytes
[23:37:41] +280s  CARD index.db:    FLAT index.db: 1324 bytes
[23:37:51] +290s  CARD index.db:    FLAT index.db: 1324 bytes
[23:38:01] +300s  CARD index.db:    FLAT index.db: 1324 bytes
CARD: 51 files in msgs/, 406M, index.db: 
FLAT: 50 files in msgs/, 389M, index.db: 1324 bytes
varz mem: 659046400 bytes = 628.5 MiB
ps rss: 643600 KB = 628.516 MiB

### [23:38:01] E1 · clean stop (SIGTERM) → up 1
n1: stopped (SIGTERM, pid 70328)
stores kept under <lab> ('down --purge' deletes them)
CARD: 52 files in msgs/, 425M, index.db: 19201304 bytes
FLAT: 50 files in msgs/, 389M, index.db: 1324 bytes
[70328] 2026/09/02 23:32:40.346812 [INF] Took 457.375µs to start JetStream
[70328] 2026/09/02 23:38:01.678026 [INF] Trapped "terminated" signal
[70328] 2026/09/02 23:38:01.678238 [INF] Initiating JetStream Shutdown...
[70328] 2026/09/02 23:38:01.703503 [INF] JetStream Shutdown
[70328] 2026/09/02 23:38:01.703578 [INF] Server Exiting..
[73701] 2026/09/02 23:38:02.922319 [INF] Starting nats-server
[73701] 2026/09/02 23:38:02.922730 [INF] Starting JetStream
[73701] 2026/09/02 23:38:02.923210 [INF]   Starting restore for stream '$G > FLAT'
[73701] 2026/09/02 23:38:02.923460 [INF]   Starting restore for stream '$G > CARD'
[73701] 2026/09/02 23:38:02.924995 [INF]   Restored 3,000,000 messages for stream '$G > FLAT' in 2ms
[73701] 2026/09/02 23:38:03.076620 [INF]   Restored 3,000,000 messages for stream '$G > CARD' in 153ms
[73701] 2026/09/02 23:38:03.076700 [INF] Took 153.966542ms to start JetStream
varz mem: 130138112 bytes = 124.1 MiB
ps rss: 127264 KB = 124.281 MiB

### [23:38:04] E2 · 200,000 more messages into each, then SIGKILL within the flush window → start 1
NATS JetStream asynchronous publisher stats: 341,015 msgs/sec ~ 32 MiB/sec ~ min: 1,195.75us ~ avg: 1,465.37us ~ max: 4,930.45us ~ P50: 1,341.66us ~ P90: 1,659.33us ~ P99: 4,000.12us ~ P99.9: 4,930.45us
NATS JetStream asynchronous publisher stats: 403,409 msgs/sec ~ 38 MiB/sec ~ min: 1,066.91us ~ avg: 1,238.68us ~ max: 3,289.04us ~ P50: 1,179.62us ~ P90: 1,433.54us ~ P99: 2,290.29us ~ P99.9: 3,289.04us
stream CARD subjects ['card.*'] messages 3200000 bytes 454400000 first 1 last 3200000 num_subjects 1200000 num_deleted 0
stream FLAT subjects ['flat.*'] messages 3200000 bytes 435200000 first 1 last 3200000 num_subjects 6 num_deleted 0
CARD: 56 files in msgs/, 452M, index.db: 19201304 bytes
FLAT: 53 files in msgs/, 415M, index.db: 1324 bytes
n1: SIGKILL sent to pid 73701
CARD: 56 files in msgs/, 452M, index.db: 19201304 bytes
FLAT: 53 files in msgs/, 415M, index.db: 1324 bytes
[73701] 2026/09/02 23:38:03.076700 [INF] Took 153.966542ms to start JetStream
[73846] 2026/09/02 23:38:07.738667 [INF] Starting nats-server
[73846] 2026/09/02 23:38:07.739074 [INF] Starting JetStream
[73846] 2026/09/02 23:38:07.739513 [INF]   Starting restore for stream '$G > FLAT'
[73846] 2026/09/02 23:38:07.739524 [INF]   Starting restore for stream '$G > CARD'
[73846] 2026/09/02 23:38:07.739922 [WRN] Filestore [FLAT] Stream state outdated, last block has additional entries, will rebuild
[73846] 2026/09/02 23:38:07.739928 [WRN] Filestore [FLAT] Recovering stream state from index errored: prior state file
[73846] 2026/09/02 23:38:07.894724 [WRN] Filestore [CARD] Stream state outdated, last block has additional entries, will rebuild
[73846] 2026/09/02 23:38:07.894748 [WRN] Filestore [CARD] Recovering stream state from index errored: prior state file
[73846] 2026/09/02 23:38:08.042969 [INF]   Restored 3,200,000 messages for stream '$G > FLAT' in 303ms
[73846] 2026/09/02 23:38:08.763894 [INF]   Restored 3,200,000 messages for stream '$G > CARD' in 1.024s
[73846] 2026/09/02 23:38:08.763966 [INF] Took 1.024889666s to start JetStream
varz mem: 396918784 bytes = 378.5 MiB
ps rss: 387824 KB = 378.734 MiB
stream CARD subjects ['card.*'] messages 3200000 bytes 454400000 first 1 last 3200000 num_subjects 1200000 num_deleted 0
stream FLAT subjects ['flat.*'] messages 3200000 bytes 435200000 first 1 last 3200000 num_subjects 6 num_deleted 0

### [23:38:11] E3 · a filtered pull consumer on each (card.1* / flat.1), read once, timed
CARD F1 filter=card.1* num_pending=400000
23:38:12 [1] Starting JetStream durable consumer (callback), expecting 400,000 messages
FLAT F1 filter=flat.1 num_pending=533334
NATS JetStream durable consumer (callback) stats: 875,995 msgs/sec ~ 107 MiB/sec

### [23:39:45] E4 · delete index.db on a cleanly stopped store → up 1 (the no-file path)
n1: stopped (SIGTERM, pid 73846)
stores kept under <lab> ('down --purge' deletes them)
<lab>/n1/store/jetstream/$G/streams/CARD/msgs/index.db
<lab>/n1/store/jetstream/$G/streams/FLAT/msgs/index.db
CARD: 55 files in msgs/, 434M, index.db: 
FLAT: 52 files in msgs/, 415M, index.db: 
[73846] 2026/09/02 23:38:08.763966 [INF] Took 1.024889666s to start JetStream
[73846] 2026/09/02 23:39:45.349191 [INF] Trapped "terminated" signal
[73846] 2026/09/02 23:39:45.400299 [INF] Initiating JetStream Shutdown...
[73846] 2026/09/02 23:39:45.436738 [INF] JetStream Shutdown
[73846] 2026/09/02 23:39:45.436812 [INF] Server Exiting..
[75042] 2026/09/02 23:39:46.603363 [INF] Starting nats-server
[75042] 2026/09/02 23:39:46.603721 [INF] Starting JetStream
[75042] 2026/09/02 23:39:46.604146 [INF]   Starting restore for stream '$G > FLAT'
[75042] 2026/09/02 23:39:46.604153 [INF]   Starting restore for stream '$G > CARD'
[75042] 2026/09/02 23:39:46.912955 [INF]   Restored 3,200,000 messages for stream '$G > FLAT' in 309ms
[75042] 2026/09/02 23:39:47.453840 [INF]   Restored 3,200,000 messages for stream '$G > CARD' in 850ms
[75042] 2026/09/02 23:39:47.456361 [INF] Took 852.640125ms to start JetStream

### [23:39:48] done; leaving the server up
node pid     alive client http  healthz  js-meta  meta_leader cluster_size
n1   75042   yes   4291   8291  200      200      -           -
lab dir: <lab>   version gate: v2.14.6
```

### E5 · the probes after the script (the `card.1*` filter, and what the subjects are called)

The script's step E3 hung: `nats bench js consume --consumer F1` waited for messages that never came.
Investigated by hand on the same server, verbatim:

```
$ nats consumer info CARD F1 --json | … {num_pending,num_waiting,delivered}
F1: {'num_pending': 400000, 'num_waiting': 0, 'num_ack_pending': 0, 'delivered': {'consumer_seq': 0, 'stream_seq': 0}, 'ack_floor': {'consumer_seq': 0, 'stream_seq': 0}}
$ nats consumer next CARD F1 --count 2 --timeout 5s
nats: error: no message received: nats: timeout
F1 after next: {'num_pending': 0, 'delivered': {'consumer_seq': 0, 'stream_seq': 0}}
--- a fresh filtered consumer F2, same filter card.1* ---
F2: {'num_pending': 400000, 'delivered': {'consumer_seq': 0, 'stream_seq': 0}}
F2 after next: {'num_pending': 0, 'delivered': {'consumer_seq': 0, 'stream_seq': 0}}
--- same on FLAT, filter flat.1 ---
FLAT F2: {'num_pending': 533334, 'delivered': {'consumer_seq': 0, 'stream_seq': 0}}
FLAT F2 after next: {'num_pending': 533332, 'delivered': {'consumer_seq': 2, 'stream_seq': 8, ...}}
```

`F1`'s config after the bench was unchanged (`filter card.1*  deliver_policy all  ack none`). Then, one
consumer per filter, `num_pending` at creation → `consumer next --count 3` → `num_pending,delivered`
afterwards:

```
FLAT G1 filter=flat.1*:      num_pending at create=0;        next --count 3 delivered=0;  after: 0 0
CARD G2 filter=card.1:       num_pending at create=0;        next --count 3 delivered=0;  after: 0 0
CARD G3 filter=card.*:       num_pending at create=3200001;  next --count 3 delivered=3;  after: 3199998 3
CARD G4 filter=card.1199999: num_pending at create=2;        next --count 3 delivered=2;  after: 0 2
CARD G5 filter=card.0:       num_pending at create=0;        next --count 3 delivered=0;  after: 0 0
CARD G6 filter=card.1*:      num_pending at create=400001;   next --count 3 delivered=0;  after: 0 1
```

(`3200001` and `400001`: one message had been published by hand to the literal subject `card.1*`
between the two probes — `nats pub 'card.1*' probe` → `Published 5 bytes to "card.1*"`.) Then what
the subjects are actually called — the bench zero-pads the token to seven digits, so `card.1`,
`card.0` and `card.600000` do not exist and their zero counts are correct:

```
$ nats stream get CARD 1
Item: CARD#1 received 2026-09-02 21:32:40.499901 +0000 UTC on Subject card.0000000
$ nats stream get CARD 1200000
Item: CARD#1200000 received 2026-09-02 21:32:43.930017 +0000 UTC on Subject card.1199999
$ nats stream get CARD 1200001
Item: CARD#1200001 received 2026-09-02 21:32:43.930483 +0000 UTC on Subject card.0000000
$ nats stream get CARD --last-for card.1199999
Item: CARD#2400000 received 2026-09-02 21:32:47.251179 +0000 UTC on Subject card.1199999
$ nats stream get CARD --last-for card.0
nats: error: could not retrieve CARD#-1: no message found (10037)
$ nats stream subjects CARD card.1
No subjects found matching card.1
$ nats stream subjects CARD card.1199999
│                 1 Subjects in stream CARD                │
$ nats stream subjects CARD 'card.12*'
No subjects found matching card.12*
```

So `card.1*` counted **400,000** = the 200,000 subjects `card.1000000`–`card.1199999` × 2 messages —
the subject tree read `1*` as "`1`, then anything to the end of the token" — while delivery, which
uses the sublist's literal-or-token-wildcard rule, matched nothing. Reproduced on a five-message
stream at the end of this file (*SI probe*) and recorded as `SI-3` in `inbox/server-issues.md`.

---

## Run D · the thread's shape: 50 M messages, restarted (`stream-scale-runD.sh`)

`NATS_LAB_WAIT=1200`. `cluster.sh start k` does **not** wait for `/healthz` (only `up` does), which
is why D3's wall time reads `0 s` and its `stream info` failed — the SIGKILL restart is repeated
properly below as *D3-redo*. The `Healthcheck failed` lines are the lab's own `/healthz` poll every
~270 ms while `up` waits, i.e. one line per poll for as long as the restore takes — the same shape
the row-13 thread saw from the Helm chart's readiness probe.

```
### [23:43:01] versions
nats-server: v2.14.6
0.4.0
/dev/disk3s5   926Gi   808Gi    97Gi    90%    2.5M  1.0G    0%   /System/Volumes/Data

### [23:43:01] fresh lab: down --purge, up 1
binary: nats-server: v2.14.6 (/opt/homebrew/bin/nats-server)
lab dir: <lab>
n1: pid 77145  client 127.0.0.1:4291  http 127.0.0.1:8291  log <lab>/n1/n1.log
healthy: standalone n1, /healthz ok
nats CLI: nats --server nats://sys:sys@127.0.0.1:4291 …
varz mem: 18137088 bytes = 17.3 MiB

### [23:43:02] D1 · fill EVENTS: 50,000,000 × 100 B over 6 subjects (watchdog 15 min)
23:43:02 Starting JetStream asynchronous publisher benchmark [batch=500, clients=1, dedup-window=2m0s, deduplication=false, max-bytes=21,474,836,480, msg-size=100 B, msgs=50,000,000, multi-subject=true, multi-subject-max=6, multi-subject-randomize=false, purge=false, replicas=1, sleep=0s, storage=file, stream=EVENTS, subject=ev.*]
23:43:02 Using stream: EVENTS
23:43:02 [1] Starting JetStream asynchronous publisher, publishing 50,000,000 messages
NATS JetStream asynchronous publisher stats: 383,895 msgs/sec ~ 37 MiB/sec ~ min: 1,076.16us ~ avg: 1,301.86us ~ max: 105,455.95us ~ P50: 1,220.04us ~ P90: 1,454.33us ~ P99: 1,805.79us ~ P99.9: 3,714.29us
fill wall time: 130 s
stream EVENTS subjects ['ev.*'] sources [] messages 50000000 bytes 6700000000 first 1 last 50000000 num_subjects 6 num_deleted 0 src-state []
varz mem: 56098816 bytes = 53.5 MiB
EVENTS: 800 files in msgs/, 6.2G, index.db: 21659 bytes
6.2G	<lab>/n1/store/jetstream/$G/streams/EVENTS
total 13087296
-rw-------@ 1 m64  staff  8388534 Sep  2 23:43 1.blk
-rw-------@ 1 m64  staff  8388534 Sep  2 23:43 10.blk
-rw-------@ 1 m64  staff  8388534 Sep  2 23:43 100.blk
-rw-------@ 1 m64  staff  8388534 Sep  2 23:43 98.blk
-rw-------@ 1 m64  staff  8388534 Sep  2 23:43 99.blk
-rw-------@ 1 m64  staff    21659 Sep  2 23:45 index.db

### [23:45:14] D2 · clean stop (SIGTERM, cluster.sh down) → up 1
n1: stopped (SIGTERM, pid 77145)
stores kept under <lab> ('down --purge' deletes them)
EVENTS: 800 files in msgs/, 6.2G, index.db: 22877 bytes
wall time for 'bash tools/lab/cluster.sh up 1': 8 s (until /healthz answered)
iostat (disk0 MB/s column), peak and mean while it ran:
  samples 7 peak MB/s 821.22 mean MB/s 802.1
[78800] 2026/09/02 23:45:19.837366 [WRN] Healthcheck failed: "failed to be ready for connections after 1ms: server"
[78800] 2026/09/02 23:45:20.105780 [WRN] Healthcheck failed: "failed to be ready for connections after 1ms: server"
[78800] 2026/09/02 23:45:20.372132 [WRN] Healthcheck failed: "failed to be ready for connections after 1ms: server"
[78800] 2026/09/02 23:45:20.639360 [WRN] Healthcheck failed: "failed to be ready for connections after 1ms: server"
[78800] 2026/09/02 23:45:20.906730 [WRN] Healthcheck failed: "failed to be ready for connections after 1ms: server"
[78800] 2026/09/02 23:45:21.171345 [WRN] Healthcheck failed: "failed to be ready for connections after 1ms: server"
[78800] 2026/09/02 23:45:21.439912 [WRN] Healthcheck failed: "failed to be ready for connections after 1ms: server"
[78800] 2026/09/02 23:45:21.707648 [WRN] Healthcheck failed: "failed to be ready for connections after 1ms: server"
[78800] 2026/09/02 23:45:21.975007 [WRN] Healthcheck failed: "failed to be ready for connections after 1ms: server"
[78800] 2026/09/02 23:45:22.242619 [WRN] Healthcheck failed: "failed to be ready for connections after 1ms: server"
[78800] 2026/09/02 23:45:22.511294 [WRN] Healthcheck failed: "failed to be ready for connections after 1ms: server"
[78800] 2026/09/02 23:45:22.779021 [WRN] Healthcheck failed: "failed to be ready for connections after 1ms: server"
[78800] 2026/09/02 23:45:23.003639 [INF]   Restored 50,000,000 messages for stream '$G > EVENTS' in 7.014s
[78800] 2026/09/02 23:45:23.003752 [INF] Took 7.014798291s to start JetStream
Healthcheck failed lines in the log so far: 26
varz mem: 58671104 bytes = 56.0 MiB

### [23:45:23] D3 · 200,000 more messages, then SIGKILL → start 1 (index.db older than the last block)
NATS JetStream asynchronous publisher stats: 396,170 msgs/sec ~ 38 MiB/sec ~ min: 1,120.25us ~ avg: 1,261.43us ~ max: 2,470.70us ~ P50: 1,214.66us ~ P90: 1,450.54us ~ P99: 1,741.08us ~ P99.9: 2,470.70us
stream EVENTS subjects ['ev.*'] sources [] messages 50200000 bytes 6726800000 first 1 last 50200000 num_subjects 6 num_deleted 0 src-state []
EVENTS: 803 files in msgs/, 6.3G, index.db: 22877 bytes
n1: SIGKILL sent to pid 78800
EVENTS: 803 files in msgs/, 6.3G, index.db: 22877 bytes
wall time for 'bash tools/lab/cluster.sh start 1': 0 s (until /healthz answered)
iostat (disk0 MB/s column), peak and mean while it ran:
  samples 1 peak MB/s 0.92 mean MB/s 0.9
[78800] 2026/09/02 23:45:21.171345 [WRN] Healthcheck failed: "failed to be ready for connections after 1ms: server"
[78800] 2026/09/02 23:45:21.439912 [WRN] Healthcheck failed: "failed to be ready for connections after 1ms: server"
[78800] 2026/09/02 23:45:21.707648 [WRN] Healthcheck failed: "failed to be ready for connections after 1ms: server"
[78800] 2026/09/02 23:45:21.975007 [WRN] Healthcheck failed: "failed to be ready for connections after 1ms: server"
[78800] 2026/09/02 23:45:22.242619 [WRN] Healthcheck failed: "failed to be ready for connections after 1ms: server"
[78800] 2026/09/02 23:45:22.511294 [WRN] Healthcheck failed: "failed to be ready for connections after 1ms: server"
[78800] 2026/09/02 23:45:22.779021 [WRN] Healthcheck failed: "failed to be ready for connections after 1ms: server"
[78800] 2026/09/02 23:45:23.003639 [INF]   Restored 50,000,000 messages for stream '$G > EVENTS' in 7.014s
[78800] 2026/09/02 23:45:23.003752 [INF] Took 7.014798291s to start JetStream
[79103] 2026/09/02 23:45:25.825754 [INF] Starting nats-server
[79103] 2026/09/02 23:45:25.826142 [INF] Starting JetStream
[79103] 2026/09/02 23:45:25.826851 [INF]   Starting restore for stream '$G > EVENTS'
[79103] 2026/09/02 23:45:25.827488 [WRN] Filestore [EVENTS] Stream state outdated, last block has additional entries, will rebuild
[79103] 2026/09/02 23:45:25.827492 [WRN] Filestore [EVENTS] Recovering stream state from index errored: prior state file
Healthcheck failed lines in the log so far: 26
varz mem: 33013760 bytes = 31.5 MiB
nats: error: setup failed: nats: no servers available for connection
<!-- (a traceback of the run script's own python helper removed here; see the note above) -->

### [23:45:28] D4 · clean stop, delete index.db → up 1 (the no-file path)
n1: stopped (SIGTERM, pid 79103)
stores kept under <lab> ('down --purge' deletes them)
<lab>/n1/store/jetstream/$G/streams/EVENTS/msgs/index.db
EVENTS: 802 files in msgs/, 6.3G, index.db: 
wall time for 'bash tools/lab/cluster.sh up 1': 10 s (until /healthz answered)
iostat (disk0 MB/s column), peak and mean while it ran:
  samples 9 peak MB/s 1020.56 mean MB/s 360.5
[79225] 2026/09/02 23:45:35.829693 [WRN] Healthcheck failed: "failed to be ready for connections after 1ms: server"
[79225] 2026/09/02 23:45:36.097481 [WRN] Healthcheck failed: "failed to be ready for connections after 1ms: server"
[79225] 2026/09/02 23:45:36.364980 [WRN] Healthcheck failed: "failed to be ready for connections after 1ms: server"
[79225] 2026/09/02 23:45:36.630370 [WRN] Healthcheck failed: "failed to be ready for connections after 1ms: server"
[79225] 2026/09/02 23:45:36.897382 [WRN] Healthcheck failed: "failed to be ready for connections after 1ms: server"
[79225] 2026/09/02 23:45:37.162360 [WRN] Healthcheck failed: "failed to be ready for connections after 1ms: server"
[79225] 2026/09/02 23:45:37.430033 [WRN] Healthcheck failed: "failed to be ready for connections after 1ms: server"
[79225] 2026/09/02 23:45:37.697613 [WRN] Healthcheck failed: "failed to be ready for connections after 1ms: server"
[79225] 2026/09/02 23:45:37.965374 [WRN] Healthcheck failed: "failed to be ready for connections after 1ms: server"
[79225] 2026/09/02 23:45:38.233009 [WRN] Healthcheck failed: "failed to be ready for connections after 1ms: server"
[79225] 2026/09/02 23:45:38.500635 [WRN] Healthcheck failed: "failed to be ready for connections after 1ms: server"
[79225] 2026/09/02 23:45:38.768181 [WRN] Healthcheck failed: "failed to be ready for connections after 1ms: server"
[79225] 2026/09/02 23:45:38.826618 [INF]   Restored 50,200,000 messages for stream '$G > EVENTS' in 9.524s
[79225] 2026/09/02 23:45:38.826702 [INF] Took 9.524166875s to start JetStream
Healthcheck failed lines in the log so far: 62
varz mem: 60293120 bytes = 57.5 MiB

### [23:45:39] D5 · the sources variant: IDLE (empty) and AGG sourcing EVENTS/ev.1 + IDLE
IDLE created
Stream AGG was created
Information for Stream AGG created 2026-09-02 23:45:39
waiting for AGG to catch up (messages stable and lag 0), up to 15 min
[23:45:50] AGG msgs,lag = 4763379 3603286
[23:46:00] AGG msgs,lag = 8366668 0
[23:46:10] AGG msgs,lag = 8366668 0
<!-- (a traceback of the run script's own python helper removed here; see the note above) -->
AGG: 199 files in msgs/, 1.5G, index.db: 
1.5G	<lab>/n1/store/jetstream/$G/streams/AGG
varz mem: 497532928 bytes = 474.5 MiB

### [23:46:10] D5a · clean stop → up 1: AGG (two sources, one empty) against EVENTS
n1: stopped (SIGTERM, pid 79225)
stores kept under <lab> ('down --purge' deletes them)
AGG: 200 files in msgs/, 1.5G, index.db: 5249 bytes
EVENTS: 803 files in msgs/, 6.3G, index.db: 22964 bytes
wall time for 'bash tools/lab/cluster.sh up 1': 5 s (until /healthz answered)
iostat (disk0 MB/s column), peak and mean while it ran:
  samples 4 peak MB/s 776.11 mean MB/s 403.1
[79862] 2026/09/02 23:46:13.347732 [WRN] Healthcheck failed: "failed to be ready for connections after 1ms: server"
[79862] 2026/09/02 23:46:13.615627 [WRN] Healthcheck failed: "failed to be ready for connections after 1ms: server"
[79862] 2026/09/02 23:46:13.884058 [WRN] Healthcheck failed: "failed to be ready for connections after 1ms: server"
[79862] 2026/09/02 23:46:14.150366 [WRN] Healthcheck failed: "failed to be ready for connections after 1ms: server"
[79862] 2026/09/02 23:46:14.418825 [WRN] Healthcheck failed: "failed to be ready for connections after 1ms: server"
[79862] 2026/09/02 23:46:14.516391 [INF]   Restored 50,200,000 messages for stream '$G > EVENTS' in 2.889s
[79862] 2026/09/02 23:46:14.686924 [WRN] Healthcheck failed: "failed to be ready for connections after 1ms: server"
[79862] 2026/09/02 23:46:14.954683 [WRN] Healthcheck failed: "failed to be ready for connections after 1ms: server"
[79862] 2026/09/02 23:46:15.221896 [WRN] Healthcheck failed: "failed to be ready for connections after 1ms: server"
[79862] 2026/09/02 23:46:15.489220 [WRN] Healthcheck failed: "failed to be ready for connections after 1ms: server"
[79862] 2026/09/02 23:46:15.756663 [WRN] Healthcheck failed: "failed to be ready for connections after 1ms: server"
[79862] 2026/09/02 23:46:16.023817 [WRN] Healthcheck failed: "failed to be ready for connections after 1ms: server"
[79862] 2026/09/02 23:46:16.282374 [INF]   Restored 8,366,668 messages for stream '$G > AGG' in 4.656s
[79862] 2026/09/02 23:46:16.282466 [INF] Took 4.656882125s to start JetStream
Healthcheck failed lines in the log so far: 79
varz mem: 94388224 bytes = 90.0 MiB

### [23:46:16] D5b · drop the IDLE source from AGG, clean stop → up 1
Stream AGG was updated
<!-- (a traceback of the run script's own python helper removed here; see the note above) -->
n1: stopped (SIGTERM, pid 79862)
stores kept under <lab> ('down --purge' deletes them)
wall time for 'bash tools/lab/cluster.sh up 1': 2 s (until /healthz answered)
iostat (disk0 MB/s column), peak and mean while it ran:
  samples 2 peak MB/s 7.63 mean MB/s 5.6
[80143] 2026/09/02 23:46:19.192929 [INF]   Starting restore for stream '$G > EVENTS'
[80143] 2026/09/02 23:46:19.193152 [INF]   Restored 0 messages for stream '$G > IDLE' in 0s
[80143] 2026/09/02 23:46:19.305334 [WRN] Healthcheck failed: "failed to be ready for connections after 1ms: server"
[80143] 2026/09/02 23:46:19.573411 [WRN] Healthcheck failed: "failed to be ready for connections after 1ms: server"
[80143] 2026/09/02 23:46:19.839673 [WRN] Healthcheck failed: "failed to be ready for connections after 1ms: server"
[80143] 2026/09/02 23:46:20.107364 [WRN] Healthcheck failed: "failed to be ready for connections after 1ms: server"
[80143] 2026/09/02 23:46:20.375864 [WRN] Healthcheck failed: "failed to be ready for connections after 1ms: server"
[80143] 2026/09/02 23:46:20.644646 [WRN] Healthcheck failed: "failed to be ready for connections after 1ms: server"
[80143] 2026/09/02 23:46:20.836709 [INF]   Restored 8,366,668 messages for stream '$G > AGG' in 1.645s
[80143] 2026/09/02 23:46:20.915354 [WRN] Healthcheck failed: "failed to be ready for connections after 1ms: server"
[80143] 2026/09/02 23:46:21.184428 [WRN] Healthcheck failed: "failed to be ready for connections after 1ms: server"
[80143] 2026/09/02 23:46:21.452661 [WRN] Healthcheck failed: "failed to be ready for connections after 1ms: server"
[80143] 2026/09/02 23:46:21.649160 [INF]   Restored 50,200,000 messages for stream '$G > EVENTS' in 2.456s
[80143] 2026/09/02 23:46:21.649246 [INF] Took 2.457527417s to start JetStream
Healthcheck failed lines in the log so far: 88

### [23:46:21] D5c · IDLE back as a source, but with one message in it; clean stop → up 1
Stream AGG was updated
23:46:25 Published 11 bytes to "idle.one"
<!-- (a traceback of the run script's own python helper removed here; see the note above) -->
n1: stopped (SIGTERM, pid 80143)
stores kept under <lab> ('down --purge' deletes them)
wall time for 'bash tools/lab/cluster.sh up 1': 2 s (until /healthz answered)
iostat (disk0 MB/s column), peak and mean while it ran:
  samples 2 peak MB/s 0.73 mean MB/s 0.4
[80426] 2026/09/02 23:46:29.764247 [INF]   Starting restore for stream '$G > AGG'
[80426] 2026/09/02 23:46:29.765097 [INF]   Starting restore for stream '$G > EVENTS'
[80426] 2026/09/02 23:46:29.765097 [INF]   Starting restore for stream '$G > IDLE'
[80426] 2026/09/02 23:46:29.765426 [INF]   Restored 1 messages for stream '$G > IDLE' in 0s
[80426] 2026/09/02 23:46:29.878350 [WRN] Healthcheck failed: "failed to be ready for connections after 1ms: server"
[80426] 2026/09/02 23:46:30.143845 [WRN] Healthcheck failed: "failed to be ready for connections after 1ms: server"
[80426] 2026/09/02 23:46:30.412062 [WRN] Healthcheck failed: "failed to be ready for connections after 1ms: server"
[80426] 2026/09/02 23:46:30.680038 [WRN] Healthcheck failed: "failed to be ready for connections after 1ms: server"
[80426] 2026/09/02 23:46:30.948233 [WRN] Healthcheck failed: "failed to be ready for connections after 1ms: server"
[80426] 2026/09/02 23:46:31.216099 [WRN] Healthcheck failed: "failed to be ready for connections after 1ms: server"
[80426] 2026/09/02 23:46:31.386716 [INF]   Restored 8,366,669 messages for stream '$G > AGG' in 1.622s
[80426] 2026/09/02 23:46:31.481620 [WRN] Healthcheck failed: "failed to be ready for connections after 1ms: server"
[80426] 2026/09/02 23:46:31.684938 [INF]   Restored 50,200,000 messages for stream '$G > EVENTS' in 1.92s
[80426] 2026/09/02 23:46:31.685016 [INF] Took 1.921260959s to start JetStream
Healthcheck failed lines in the log so far: 95

### [23:46:31] D5d · a second restart of the same shape (nothing new sourced since D5c)
n1: stopped (SIGTERM, pid 80426)
stores kept under <lab> ('down --purge' deletes them)
wall time for 'bash tools/lab/cluster.sh up 1': 3 s (until /healthz answered)
iostat (disk0 MB/s column), peak and mean while it ran:
  samples 2 peak MB/s 0.34 mean MB/s 0.3
[80581] 2026/09/02 23:46:33.047250 [INF]   Starting restore for stream '$G > EVENTS'
[80581] 2026/09/02 23:46:33.047265 [INF]   Starting restore for stream '$G > IDLE'
[80581] 2026/09/02 23:46:33.047285 [INF]   Starting restore for stream '$G > AGG'
[80581] 2026/09/02 23:46:33.047634 [INF]   Restored 1 messages for stream '$G > IDLE' in 0s
[80581] 2026/09/02 23:46:33.158956 [WRN] Healthcheck failed: "failed to be ready for connections after 1ms: server"
[80581] 2026/09/02 23:46:33.427522 [WRN] Healthcheck failed: "failed to be ready for connections after 1ms: server"
[80581] 2026/09/02 23:46:33.691291 [WRN] Healthcheck failed: "failed to be ready for connections after 1ms: server"
[80581] 2026/09/02 23:46:33.959940 [WRN] Healthcheck failed: "failed to be ready for connections after 1ms: server"
[80581] 2026/09/02 23:46:34.224735 [WRN] Healthcheck failed: "failed to be ready for connections after 1ms: server"
[80581] 2026/09/02 23:46:34.495542 [WRN] Healthcheck failed: "failed to be ready for connections after 1ms: server"
[80581] 2026/09/02 23:46:34.719182 [INF]   Restored 8,366,669 messages for stream '$G > AGG' in 1.672s
[80581] 2026/09/02 23:46:34.763665 [WRN] Healthcheck failed: "failed to be ready for connections after 1ms: server"
[80581] 2026/09/02 23:46:34.869301 [INF]   Restored 50,200,000 messages for stream '$G > EVENTS' in 1.822s
[80581] 2026/09/02 23:46:34.869388 [INF] Took 1.823015417s to start JetStream
Healthcheck failed lines in the log so far: 102

### [23:46:35] F · --max-msgs past a billion, and the arithmetic
Stream EVENTS was updated
config.max_msgs = 1000000000
Stream EVENTS was updated
config.max_msgs = 10000000000
EVENTS: 50,200,000 messages, reported bytes 6,726,800,000 (134.00 B/msg), 802 .blk files totalling 6,726,800,000 B (134.00 B/msg on disk)
extrapolated, as arithmetic only: 1,000,000,000 messages of this shape = 124.8 GiB on disk, 124.8 GiB reported

### [23:46:35] done
node pid     alive client http  healthz  js-meta  meta_leader cluster_size
n1   80581   yes   4291   8291  200      200      -           -
lab dir: <lab>   version gate: v2.14.6
/dev/disk3s5   926Gi   815Gi    90Gi    91%    2.5M  942M    0%   /System/Volumes/Data
```

---

## Run F · `--max-msgs` past a billion (in `stream-scale-runD.sh`)

```
### [23:46:35] F · --max-msgs past a billion, and the arithmetic
Stream EVENTS was updated
config.max_msgs = 1000000000
Stream EVENTS was updated
config.max_msgs = 10000000000
EVENTS: 50,200,000 messages, reported bytes 6,726,800,000 (134.00 B/msg), 802 .blk files totalling 6,726,800,000 B (134.00 B/msg on disk)
extrapolated, as arithmetic only: 1,000,000,000 messages of this shape = 124.8 GiB on disk, 124.8 GiB reported
```

134 B per message is `30 + len("ev.N") + 100` — the record format on `filestore-layout` — and the
block files total exactly the reported bytes because nothing has been deleted. A billion messages
of this shape is 125 GiB and 15,000 blocks of 8 MB; the server accepted the limit without comment.
Nobody filled a billion messages here.

---

## After the script · the restarts repeated with goroutine samples

A sampler fetched `/stacksz` every 150–200 ms until `/healthz` answered 200; `iostat -d -w 1` ran
alongside (macOS `iostat` reports **total** MB/s, reads and writes together). Server frames of the
goroutine inside `recoverStream` / `EnableJetStream.func2` are summarised per sample.

### D2-redo · clean stop → `up 1`, three minutes after the last write

```
### [23:49:32] D2-redo · clean stop → up 1 with /stacksz sampled every 200 ms
n1: stopped (SIGTERM, pid 80581)
wall time until /healthz 200: 0.23 s
samples: 0  non-empty: 1
[82326] 2026/09/02 23:49:34.025795 [INF]   Restored 1 messages for stream '$G > IDLE' in 1ms
[82326] 2026/09/02 23:49:34.027252 [INF]   Restored 8,366,669 messages for stream '$G > AGG' in 2ms
[82326] 2026/09/02 23:49:34.029876 [INF]   Restored 50,200,000 messages for stream '$G > EVENTS' in 5ms
[82326] 2026/09/02 23:49:34.029941 [INF] Took 5.452459ms to start JetStream
--- iostat ---
   27.45   35  0.95
```

### b2b1–b2b3 · three back-to-back clean restarts

```
### [23:51:38] back-to-back clean restarts, sampled
[b2b1] Restored 1 messages for stream '$G > IDLE' in 0s;Restored 8,366,669 messages for stream '$G > AGG' in 2ms;Restored 50,200,000 messages for stream '$G > EVENTS' in 3ms;Took 3.763542ms to start JetStream;
[b2b1] iostat MB/s: 0.95
[b2b1] non-empty stack samples: 0
[b2b2] Restored 1 messages for stream '$G > IDLE' in 0s;Restored 8,366,669 messages for stream '$G > AGG' in 2ms;Restored 50,200,000 messages for stream '$G > EVENTS' in 3ms;Took 3.438792ms to start JetStream;
[b2b2] iostat MB/s: 0.95
[b2b2] non-empty stack samples: 0
[b2b3] Restored 1 messages for stream '$G > IDLE' in 0s;Restored 8,366,669 messages for stream '$G > AGG' in 2ms;Restored 50,200,000 messages for stream '$G > EVENTS' in 3ms;Took 3.654625ms to start JetStream;
[b2b3] iostat MB/s: 0.95
[b2b3] non-empty stack samples: 0
```

### W1 · 200,000 new messages, then an immediate clean restart

```
### [23:52:13] W1 · 200,000 more messages, then an immediate clean restart (sampled)
NATS JetStream asynchronous publisher stats: 230,866 msgs/sec ~ 22 MiB/sec ~ min: 1,835.08us ~ avg: 2,165.09us ~ max: 5,192.79us ~ P50: 2,101.83us ~ P90: 2,387us ~ P99: 3,041.62us ~ P99.9: 5,192.79us
[w1] wall 0.22 s; Restored 1 messages for stream '$G > IDLE' in 0s;Restored 8,400,003 messages for stream '$G > AGG' in 14ms;Restored 50,400,000 messages for stream '$G > EVENTS' in 27ms;Took 27.025833ms to start JetStream;
[w1] iostat MB/s: 0.95
[w1] non-empty stack samples: 0
```

### D3-redo · 200,000 more messages, SIGKILL, `start 1`, waited for `/healthz`

```
### [23:52:15] D3-redo · 200,000 more messages, SIGKILL, start 1 (sampled)
NATS JetStream asynchronous publisher stats: 227,966 msgs/sec ~ 22 MiB/sec ~ min: 1,186.91us ~ avg: 2,192.57us ~ max: 5,722.08us ~ P50: 2,113.83us ~ P90: 2,422.04us ~ P99: 4,819.37us ~ P99.9: 5,722.08us
EVENTS messages 50600000 last 50600000
index.db 23079 bytes Sep 2 23:52
n1: SIGKILL sent to pid 83893
[d3] wall 6.56 s; Recovering stream state from index errored: prior state file;Stream state outdated, last block has additional entries, will rebuild;Recovering stream state from index errored: prior state file;Restored 8,433,337 messages for stream '$G > AGG' in 1.598s;Restored 50,600,000 messages for stream '$G > EVENTS' in 6.372s;Took 6.372396584s to start JetStream;
[d3] iostat MB/s: 0.95 1391.68 1581.52 1050.41 1037.47 1040.27 1052.59
[d3] non-empty stack samples: 37
Healthcheck failed lines in the log (cumulative, all restarts so far): 139
EVENTS after d3: messages 50600000 last 50600000 num_deleted 0
```

The 37 samples' restoring goroutine, every time, was in `recoverMsgs` → `recoverMsgBlock` →
`rebuildState` → `rebuildStateLocked` → either `loadBlock` (a `read` syscall, 21 samples), the
HighwayHash of each record (`rebuildStateFromBufLocked` → `highwayhash.*`, 14), or the subject-tree
insert (`stree.*`, 10 — counted per frame, a sample can show more than one). Two samples in full,
innermost first:

```
== d3-001.txt
   syscall.syscalln / syscall.read / internal/poll.(*FD).Read / os.(*File).Read / io.ReadAtLeast / io.ReadFull
   (*msgBlock).loadBlock
   (*msgBlock).rebuildStateLocked
   (*msgBlock).rebuildState
   (*fileStore).recoverMsgBlock
== d3-001.txt (the same goroutine, a moment later in another sample)
   minio/highwayhash.initialize
   minio/highwayhash.(*Digest).Reset(...)
   (*msgBlock).rebuildStateFromBufLocked
   (*msgBlock).rebuildStateLocked
   (*msgBlock).rebuildState
   (*fileStore).recoverMsgBlock
   (*fileStore).recoverMsgs
   newFileStoreWithCreated
   (*stream).setupStore
   (*Account).addStreamWithAssignment
   (*Account).recoverStream(...)
   (*Account).EnableJetStream.func2
   (*Account).EnableJetStream.func3()
   parallelTaskQueue.func1()
```

### D5e–D5g · the empty-source scan, in the idle regime

`IDLE2` is a new, empty stream; `AGG` is edited to source `EVENTS/ev.1`, `IDLE` (one message) and
`IDLE2` (`stream-scale-agg-idle2.json`), then back to the first two (`stream-scale-agg.json`).

```
### [23:55:37] D5e · idle regime: add an EMPTY source IDLE2 to AGG, clean stop → up 1 (sampled)
IDLE2 created (empty)
Stream AGG was updated
AGG sources ['EVENTS', 'IDLE', 'IDLE2'] messages 8433337 src lag [('EVENTS', 0), ('IDLE', 0), ('IDLE2', 0)]
AGG msgs/: 1.6G
[d5e] wall 2.88 s; Restored 5 messages for stream '$G > PT' in 0s;Restored 1 messages for stream '$G > IDLE' in 1ms;Restored 50,600,000 messages for stream '$G > EVENTS' in 3ms;Restored 8,433,337 messages for stream '$G > AGG' in 2.572s;Took 2.572766166s to start JetStream;
[d5e] iostat MB/s: 0.97 0.68 0.34
[d5e] 15 stack samples; restoring-goroutine frames (server frames only), by count:
    3 × (*fileStore).LoadPrevMsg <- (*fileStore).LoadPrevMsgMulti <- (*stream).startingSequenceForSources <- (*stream).setupSourceConsumers <- (*stream).subscribeToStre
    2 × (*stream).startingSequenceForSources <- (*stream).setupSourceConsumers <- (*stream).subscribeToStream <- (*stream).setLeader <- (*Account).addStreamWithAssignme
    2 × (*msgBlock).indexCacheBuf <- (*msgBlock).loadMsgsWithLock <- (*msgBlock).prevMatching <- (*fileStore).LoadPrevMsg <- (*fileStore).LoadPrevMsgMulti <- (*stream).
    2 × (*msgBlock).msgFromBufEx <- (*msgBlock).cacheLookupEx <- (*msgBlock).cacheLookup(...) <- (*msgBlock).prevMatching <- (*fileStore).LoadPrevMsg <- (*fileStore).Lo
### [23:55:45] D5f · the same restart again (nothing changed)
[d5f] wall 2.9 s; Restored 1 messages for stream '$G > IDLE' in 0s;Restored 0 messages for stream '$G > IDLE2' in 0s;Restored 50,600,000 messages for stream '$G > EVENTS' in 3ms;Restored 8,433,337 messages for stream '$G > AGG' in 2.577s;Took 2.578123334s to start JetStream;
[d5f] iostat MB/s: 0.97 0.28 0.40
[d5f] 15 stack samples; restoring-goroutine frames (server frames only), by count:
    5 × (*stream).startingSequenceForSources <- (*stream).setupSourceConsumers <- (*stream).subscribeToStream <- (*stream).setLeader <- (*Account).addStreamWithAssignme
    2 × (*msgBlock).msgFromBufEx <- (*msgBlock).cacheLookupEx <- (*msgBlock).cacheLookup(...) <- (*msgBlock).prevMatching <- (*fileStore).LoadPrevMsg <- (*fileStore).Lo
    2 × (*fileStore).LoadPrevMsg <- (*fileStore).LoadPrevMsgMulti <- (*stream).startingSequenceForSources <- (*stream).setupSourceConsumers <- (*stream).subscribeToStre
    2 × (*fileStore).LoadPrevMsgMulti <- (*stream).startingSequenceForSources <- (*stream).setupSourceConsumers <- (*stream).subscribeToStream <- (*stream).setLeader <-
### [23:55:49] D5g · drop IDLE2 again (sources EVENTS/ev.1 + IDLE with one message), clean stop → up 1
Stream AGG was updated
[d5g] wall 0.22 s; Restored 5 messages for stream '$G > PT' in 0s;Restored 1 messages for stream '$G > IDLE' in 1ms;Restored 50,600,000 messages for stream '$G > EVENTS' in 2ms;Restored 8,433,337 messages for stream '$G > AGG' in 23ms;Took 23.077292ms to start JetStream;
[d5g] iostat MB/s: 0.97
[d5g] 0 stack samples; restoring-goroutine frames (server frames only), by count:
```

Every sample of D5e and D5f is the backward scan: `startingSequenceForSources` → `LoadPrevMsgMulti`
→ (`LoadPrevMsg`, because once `EVENTS` and `IDLE` are found near the tail the one remaining source
is a full wildcard) → `prevMatching` → `loadMsgsWithLock` / `indexCacheBuf` / `msgFromBufEx`. No
disk reads: the 1.6 GB came from the page cache, so 2.57 s is the CPU floor of the scan on this
machine, ~620 MB/s on one goroutine. `EVENTS`, with no sources, restored in 3 ms in the same restarts.

---

## SI probe · a `*` inside a token, on a five-message stream (`PT`)

```
### [23:53:05] SI probe · a '*' inside a token: pending counted as a prefix wildcard, delivered as a literal
stream PT created (subjects pt.>)
published pt.10
published pt.11
published pt.20
published pt.3
published pt.100
PT messages 5 num_subjects 5
filter pt.1*   num_pending at create=3    next --count 5 got: <nothing, timeout>            after: pending/delivered=0/0
filter pt.*    num_pending at create=5    next --count 5 got: <nothing, timeout>            after: pending/delivered=0/5
filter pt.1    num_pending at create=0    next --count 5 got: <nothing, timeout>            after: pending/delivered=0/0
filter pt.10   num_pending at create=1    next --count 5 got: <nothing, timeout>            after: pending/delivered=0/1
filter pt.>    num_pending at create=0    next --count 5 got: <nothing, timeout>            after: pending/delivered=0/5
filter pt.1>   num_pending at create=0    next --count 5 got: <nothing, timeout>            after: pending/delivered=0/0
--- the same filter through STREAM.INFO subjects_filter (the subjects report) ---
│               3 Subjects in stream PT               │
--- and stream get --last-for pt.1* ---
nats: error: could not retrieve PT#-1: no message found (10037)
--- versions ---
nats-server: v2.14.6
0.4.0
```

(The `got:` column is empty for every row because the probe's pattern did not match the CLI's output
format; the `delivered` counter afterwards is the evidence — `pt.*`, `pt.10` and `pt.>` delivered 5, 1
and 5, `pt.1*` delivered **0** of the **3** it had reported pending. The `0` `num_pending` at create
for `pt.>` was read within a millisecond of creation; re-read afterwards it was 5, the same as a
consumer with no filter and one with `pt.*`.) `pt.1>` is counted and delivered as a literal on both
sides; only the `*` case disagrees. Mechanism: `filestore.go:4322` (`mb.fss.Match`) and the
`subjects_filter` path count through the subject tree, whose `matchParts` (`stree/parts.go:79–147`)
truncates a literal part at a fragment boundary and then, at line 94–106, treats the remaining lone
`*` as a wildcard placeholder; delivery matches through `subjectHasWildcard` / the sublist
(`sublist.go:1172–1183`), for which a `*` not at a token boundary is a literal byte.
