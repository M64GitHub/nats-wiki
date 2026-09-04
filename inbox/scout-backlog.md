# Scout backlog — what to scout next, and what not to (written 2026-09-01)

**Not a scout.** A standing list of the topics that still want one, so a fresh session can pick one up
without re-deriving the grouping. Written the day
`inbox/scout-delivery-timing-2026-09-01.md` was, from the question bank's open rows.

**State when written:** bank **105/83**, ★ complete (**42/42**), unlanded ripples **0**, citation
drift **0**. Six of the 22 open rows (16–19, 29–30) are taken by
`inbox/plan-delivery-timing-2026-09-01.md`. **Two more (37, 40) are taken by
`inbox/plan-the-meta-layer-2026-09-01.md`** — see *Not scouts* below. That leaves **14 rows**, grouped
here into three scouts.

**Update this file** when a scout is run: strike the group and name the scout file.

**Update 2026-09-03:** sections 1 and 2 struck (phase B of the maintainer's programme, plan
`inbox/plan-the-runnable-scouts-2026-09-02.md`); the wiki's last wanted page, `consumer-keeps-redelivering`,
written the same day. Bank 108 / 137, wanted 0, unlanded 0, drift 0.

---

## ~~1 · Mirror and replication internals — rows 76, 91, 105~~ — struck 2026-09-03

**Closed** by `inbox/scout-mirrors-and-replication-2026-09-02.md` and steps 1–2 of
`inbox/plan-the-runnable-scouts-2026-09-02.md`: rows 76, 91, 105 *answered* (91 with the mechanism and a
run, unanswered upstream); runs A/B/C in `raw/nats-server-src/mirrors-observed-v2.14.6.md`; gotcha
`consumer-slow-on-a-sparse-stream`; docs issues #49–#51. The expected second `SI-` did not materialise —
with no mirror the hub sees nothing of the leaf's bucket, so row 105 is not SI-1 restated.

| row | question | asked at |
|---:|---|---|
| 76 | Why is a KV mirror on file storage far slower than on memory storage? | [gh#8417](https://github.com/nats-io/nats-server/discussions/8417) |
| 91 | Why does mirror catch-up slow down when a consumer reads the mirror at the same time? | [gh#8444](https://github.com/nats-io/nats-server/discussions/8444) |
| 105 | Why does `nats object ls <bucket>` fail on a **mirror** of an object-store bucket, and what does mirroring one across a leafnode with two JetStream domains actually give you? | [gh#5106](https://github.com/nats-io/nats-server/issues/5106) *(an issue, not a discussion)* |

**Run this one first.** Three rows, one mechanism, and the strongest odds of a finding rather than a
summary:

- **It is runnable**, which is where this wiki's best entries have come from. Row 76 is a stopwatch
  question — build the same KV mirror on file and on memory storage and time it. Row 105 is one
  command against a mirrored object bucket. The local binary was **v2.14.6** on 2026-09-01; re-check
  with `nats-server --version` before quoting anything, and keep it aligned with the pages' own
  `verified-against`.
- **The neighbouring pages already exist and already own the internals** — [[mirrors-and-sources]],
  [[key-value]], [[object-store]], [[direct-get]] — so the ripple lands rather than needing new pages.
- **Row 105 sits next to an existing server finding.** `inbox/server-issues.md` **SI-1** is the
  `$OBJ.>` / `$O.` deny-list mismatch that lets object-store data cross a JetStream domain boundary,
  measured on 2.14.6 in `raw/nats-server-src/object-store-across-leafnode-observed-v2.14.6.md`. Row
  105 asks about mirroring an object bucket across exactly that boundary. Expect a **second `SI-`
  entry**, and check whether the two are the same finding wearing different clothes before writing a
  new one.
- Row 91's shape — a reader competing with catch-up — is close to what [[jetstream-slows-as-consumers-grow]]
  and the `stalls` / `stalled_clients` counters on [[slow-consumer-detected]] already describe. Check
  those before assuming it is new.

**Expect:** 2 rows closed, 1 possible `SI-` entry. Row 91 may need a run to say anything at all.

## ~~2 · Stream scale ceilings and the filestore — rows 4, 5, 9, 13~~ — struck 2026-09-03

**Closed** by `inbox/scout-stream-scale-2026-09-02.md` and steps 3–4 of
`inbox/plan-the-runnable-scouts-2026-09-02.md`: rows 4, 5, 9, 13 *answered* — row 5 by a maintainer's
"no hard limit", not the `no-public-answer` expected here; runs D/E/F in
`raw/nats-server-src/stream-scale-observed-v2.14.6.md`; gotcha `jetstream-recovery-is-slow`; docs issues
#52–#53; `SI-3` (a `*` inside a token), found on the way.

| row | question | asked at |
|---:|---|---|
| 4 | Is there a practical cap on the number of messages in a single stream? | [gh#7147](https://github.com/nats-io/nats-server/discussions/7147) |
| 5 | What is the largest known-good value for `MaxMsgs` on a stream? | [gh#7032](https://github.com/nats-io/nats-server/discussions/7032) |
| 9 | Does a high-cardinality subject space hurt stream performance? | [gh#8333](https://github.com/nats-io/nats-server/discussions/8333) |
| 13 | Why is JetStream startup and recovery slow with tens of millions of messages? | [gh#8001](https://github.com/nats-io/nats-server/discussions/8001) |

**Why these four together:** they are all one question — *how big can one stream get before something
bends* — asked from four directions.

**What makes it tractable:** the wiki already reads the filestore source, and **row 9's mechanism is
probably already on the page unconnected to the question**. [[filestore-layout]] carries `index.db` at
**`len(subject) + 4` per subject** — which is exactly a per-subject cost that a high-cardinality
subject space multiplies. Check that before scouting: the row may be half-answered already, and the
scout is then only for the other half (does it cost *time*, not just bytes).

Row 13 is **runnable**: fill a file stream, restart the server, time the recovery, watch what it logs.
That is the same shape as the runs behind [[filestore-layout]] and the priority-groups docs issue.

**Expect:** row 9 and row 13 closable; **row 5 is very likely a `no-public-answer` row** — "the
largest known-good value" is the kind of thing nobody publishes. Per the bank's own convention that is
a real answer: fill its `answered by` with the page that says so, **in bold**, rather than leaving the
cell empty. Do not invent a number, and do not let a *measured* ceiling on one laptop become a stated
limit.

## 3 · Throughput and memory under load — rows 8, 10, 11, 68, and 66

| row | question | asked at |
|---:|---|---|
| 8 | Why is my async publish throughput far below the numbers in the docs? | [gh#7599](https://github.com/nats-io/nats-server/discussions/7599) |
| 10 | Why does server memory grow with the number of unacknowledged (pending) messages? | [gh#6820](https://github.com/nats-io/nats-server/discussions/6820) |
| 11 | How do I scale core NATS for bursty traffic — bigger nodes, more nodes, or partitioning? | [gh#7738](https://github.com/nats-io/nats-server/discussions/7738) |
| 68 | Why did throughput drop after moving from Kubernetes to a standalone VM (or back)? | [gh#6594](https://github.com/nats-io/nats-server/discussions/6594) |
| 66 | How do I grow the JetStream volume on Kubernetes? | [gh#6601](https://github.com/nats-io/nats-server/discussions/6601) |

**Row 66 rides along** rather than getting its own scout: it is a Kubernetes-storage question and half
its sources are already in `raw/` — `s-k8s-760-jetstream-pvc-per-replica`, `s-gh-7749-hostpath-jetstream`,
`s-nats-helm-chart-values-2.14.6`. Check whether [[kubernetes-storage]] can already answer it before
scouting anything.

**Row 10 has a head start:** `s-synadia-jetstream-memory-patterns` is already ingested and
[[jetstream-sizing]] already names the four things JetStream holds in memory. The open half is
specifically whether *pending* (delivered-unacked) messages are one of them — which connects to
`max_ack_pending` being a **consumer-wide** cap, now on [[ack-and-redelivery]].

**The caveat that shapes this scout:** these are the most **environment-bound** rows in the bank. A
`nats bench` number from one machine is not an answer to "why is mine slower", and row 68 is a
comparison between two environments neither of which is yours. Scout them expecting *mechanisms and
what to measure*, not figures — and be quick to write `(unverified)` or a `## To verify` item.

**Expect:** partial closure. This is the group most likely to produce good [[jetstream-sizing]]
material and fewest closed rows.

## 4 · Core NATS ordering — row 25 *(too thin for its own scout)*

| row | question | asked at |
|---:|---|---|
| 25 | What ordering guarantees does core NATS give? | [gh#7577](https://github.com/nats-io/nats-server/discussions/7577) |

**Checked 2026-09-01 and it is genuinely still open**, despite appearances: [[publishing]] has an
`## Ordering, and what breaks it` section, but it is about **JetStream** publish ordering — sync vs
async, `Nats-Expected-Last-Subject-Sequence`. Row 25 asks what **core** NATS guarantees, which no page
states. Fold it into scout 3 or do it as a one-off ingest of gh#7577 plus the core-concepts docs.

---

## Not scouts

- **Rows 37 and 40** — *owned by `inbox/plan-the-meta-layer-2026-09-01.md`*, whose step 2 ingests
  [gh#7533](https://github.com/nats-io/nats-server/discussions/7533) (quorum loss after days of stable
  operation) and [gh#6892](https://github.com/nats-io/nats-server/discussions/6892) (evicting a
  sick-but-not-dead node) by URL. Scouting them would duplicate a plan that already exists. Run that
  plan instead — and **name the file explicitly**, because a bare `start the plan` takes the newest.
- **Row 98** — is there a limit on how many accounts one account can import from?
  ([gh#5606](https://github.com/nats-io/nats-server/discussions/5606)). **The thread is already
  ingested** as `s-gh-5606-cross-account-jetstream`, and the summary records that the scale question
  "went unanswered … Nobody replied. The wiki does not state a limit, because no public source gives
  one." So this is not a scout: it is either a short read of the server source for an import ceiling
  (none is in `raw/nats-server-src/constants-v2.14.6.md`) or an honest `no-public-answer` row.
  Minutes, either way.

## Where this leaves the bank

14 rows across three scouts, plus 2 owned by the meta-layer plan and 6 by the delivery-timing plan —
which is all 22. **Two of the three scouts have a runnable component** (76/105 and 13), and that is
where this wiki's findings have actually come from: the priority-groups docs issue (#37) and `SI-1`
both came out of running the binary, not out of reading.

Be prepared for `no-public-answer` to be the right result more often here than in earlier rounds. The
easy rows were answered first; **what is left is disproportionately the questions nobody public has
answered**, and a stated dead end with a date on it is the most valuable row in the table.

---

## 5 · The posed design rows — 108–137 (added 2026-09-02) — **(a) struck 2026-09-03**, (b) open

Thirty rows written by the maintainer under the retired scope test (`CLAUDE.md`, *The question
bank*, 2026-09-02): `own` in *asked at*, `design` in *flags*, one per architecture decision an
operator or solution architect holds — stream and subject design, consumer design, KV and object
store, multi-tenancy and auth, topology, capacity, upgrades, DR, core-versus-JetStream, migration,
MQTT. Eight were filled on the day from pages whose sections state the answer; **22 are open** and
are the work queue for `kind: pattern` pages.

**Two scouts follow from them.** (a) A scout for the **public form** of each posed row — a
discussion, an issue, a Stack Overflow question, a talk — so `own` can be replaced with a URL; the
2026-08-31 mining read 484 discussions by *title*, and design questions hide in bodies and replies.
(b) A scout per **pattern page** before it is written: the Synadia *Design Patterns for Scaling NATS*
series, NATS by Example, and the docs' unread `learn/core-nats`, `learn/resilient-clients` and
`learn/services` chapters are the first places to look. Run (b) page by page, not all at once.

**(a) done 2026-09-03** — `inbox/scout-posed-rows-public-form-2026-09-03.md`, on the discussions
index of `inbox/gh-discussions-toc.md` (titles and original posts), the comment cache of
`tools/triage-discussions.py --with-comments`, and the Stack Overflow tags. **21 rows got a URL**
(108, 109, 110, 111, 113, 114, 115, 117, 118, 119, 120, 121, 122, 124, 125, 126, 129, 130, 135, 136,
137 — eight of them for one half of the row, named in the scout file). **Searched, not found — do not
search again without a new source:**

| row | what was searched | nearest, and why it is not the row |
|---|---|---|
| 112 | `Nats-Msg-Id`, `Nats-Expected-Last-Subject-Sequence`, dedup, exactly-once, idempotent, optimistic concurrency; SO "deduplication", "exactly once", "msg-id" | gh#3772's answer and gh#4417 explain `Nats-Expected-*`; nobody poses dedup *versus* expected-sequence |
| 116 | `max_ack_pending` with batch or `ack_wait`, tuning, throughput; SO `max_ack_pending`, `ack_wait`, "batch consumer" | gh#5211 / gh#4972 (rows 15, 19) ask about one knob each; so#67174521 asks how to commit by batch; the joint setting is never asked |
| 123 | account limits, `max_memory` / `max_file` / `max_streams` / `max_consumers`, quota, apportion; SO "account limits", "limits", `max_file` | gh#5128 asks how many streams a cluster takes, not how to share it between accounts |
| 127 | JetStream on all / some / dedicated servers, `jetstream: enabled` per node, mixed clusters, separate roles; SO "dedicated", "jetstream enabled", "some servers" | gh#2730 and so#71587299 are placement of a stream, not the role of a server |
| 128 | capacity, sizing, hardware requirements, disk/RAM/nodes derivation; SO "hardware", "capacity", "disk memory" | so#70550060 (score 18) asks how JetStream scales and gets "~250k msg/s R3 filestore"; rows 1, 3, 11 hold the asked pieces; the derivation is never one question |
| 131 | Kubernetes vs VM / bare metal, storage class, PVC, anti-affinity, chart decisions; SO "kubernetes", "storage class", "bare metal" | gh#6594 (row 68) is a throughput drop after a move; gh#7749 (row 66) is `hostPath`; so#72917865 / so#75588016 are chart PVC mechanics |
| 132 | disaster, RPO / RTO, backup strategy, second cluster, standby, restore elsewhere; SO "backup", "disaster", "mirror cluster" | gh#5614 and so#68767392 ask *how to back everything up*; neither weighs snapshot against mirror against R3 |
| 133 | core vs JetStream, when to use / need JetStream, persistence on core, pub/sub or request/reply with a stream; SO "core jetstream", "jetstream or core", "persistence" | gh#4984 (8 upvotes) asks for micro *plus* JetStream — a feature request, not a choice; so#74129868 asks whether JetStream can be the source of truth |
| 134 | request/reply at scale, RPC, scatter-gather, no-responders, service layer / mesh, queue-group load balancing, timeouts; SO "request reply timeout", "queue group", "no responders", "scatter" | gh#2758 (cancelling slow responders), gh#4911 (routing by id ranges), gh#4761 (no-responders across accounts), so#67502707 (the exception) — pieces, no design question |

**(b) — one page done 2026-09-04**: `services-on-core-nats` (row 134), written for step 6 of
`inbox/plan-the-client-side-2026-09-03.md`. Scouted the comment cache
(`local/scratch/gh-index/threads-2026-09-03.md`) for `nats micro`, "micro framework", "service
framework" and `$SRV`: **two hits in 484 threads**, one of them a passing mention. The other,
**gh#4984** (*Nats micro with Jetstream*, 8 upvotes, no chosen answer), is not row 134's design
question but is the public statement of where the pattern stops — a maintainer twice saying an acking
handler is "not on the immediate roadmap". It was fetched whole into `raw/gh-discussions/gh-4984.md`,
summarised as `s-gh-4984-micro-with-jetstream`, and became **bank row 193**; it is also the nearest
thread this table already named for **row 133**, so step 7 starts from the raw copy rather than
re-fetching. Row 134 stays `own`: the (a) sweep found no public form and this one did not either.
The page rests instead on ADR-32, the four docs summaries and six passes of runs on 2.14.6.

**(b) — G1 scouted 2026-09-04**: `inbox/scout-stream-and-subject-design-2026-09-04.md`, for rows 108, 109,
110, 111, 114 and 144 (`subject-design`, `stream-topology-design`, a *Choosing retention* section, and row
144). Seventeen candidates: the six bank-row threads promoted whole into `raw/gh-discussions/`, five more from
the 484-thread comment cache, **`synadia.com/blog` read end to end for the first time (111 posts — eight for
G1, one parked per later G-group, plus *Jepsen: NATS 2.12.1* for phase I)**, `natsbyexample.com` (the first
source from that site here) and both NATS tags on Stack Exchange. No `own` to replace — all six rows already
carried a URL. The scout's *seen and deliberately not in G1* table means **`synadia.com/blog` does not need
re-scouting** for G2–G8; take the named post.

The rest of (b) stays open — phase G runs it page by page.
