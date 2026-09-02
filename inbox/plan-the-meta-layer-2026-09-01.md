# Plan — the meta layer, and why a leader keeps moving (proposed 2026-09-01)

> **Result (2026-09-01): finished, all three steps.** `meta-layer`, `stream-leader-keeps-moving` and
> `evict-a-sick-server` exist and are cited by every page that pointed at them; Q37 is a stated dead
> end and Q40 is answered from the source and a run; every `## To verify` item on `raft-in-nats` is
> settled. Bank 107 rows / **93** answered, docs issues **48**, unlanded ripples 0 throughout.
> **Next:** the standing consolidation queue (`plan-consolidation-2026-08-31.md`'s largest debts:
> `concepts/account`, `concepts/stream`, `entities/nats-cli`) or a scout for the last wanted page,
> `consumer-keeps-redelivering` (issue #6921) — see *Not in this plan* below.

Say **`start the plan inbox/plan-the-meta-layer-2026-09-01.md`** to work this file — **name it
explicitly**, because a bare `start the plan` takes the *newest* `inbox/plan-*.md` and
`plan-consolidation-2026-08-31.md` may still be the one you want. `CLAUDE.md` → *Operation: plan*
says how. One step at a time, `status:` rewritten in place, `wiki/log.md` appended, lint run,
question-bank cells filled, and each step reported before the next begins.

**Two constraints for every step, on top of *Operation: plan*** — cap each ingest at **~8 summaries**,
and report `tools/lint.py`'s **unlanded-ripple count before and after** the step next to the
question-bank numbers. **Measure the baseline at the start of step 1** rather than trusting a number
written here: `plan-consolidation-2026-08-31.md` is expected to move it before this plan runs. It was
**202 across 56 pages** on 2026-09-01.

**Where the wiki stands.** `plan-the-unread-chapters-2026-08-31.md` finished all six steps on
2026-09-01: **260 pages**, question bank **105 rows / 83 answered / ★ 42 of 42**,
`inbox/docs-issues.md` at **36** verified findings, `inbox/server-issues.md` at **1**, staleness 0,
lint clean.

**Why this plan.** Three previous plans have deferred it, each for a stated reason, and the reasons
have now expired. What is left is the **last structural hole in this wiki's JetStream coverage**:

- **`meta-layer` is a red link that five pages already depend on.** `wiki/index.md`,
  [[streams-deleted-when-clustering-a-standalone-server]], [[replicas]] ("see `[[meta-layer]]` once a
  source covers it") and [[s-gh-7831-standalone-to-cluster]] ("it is the record whose absence makes a
  stream an orphan"). That is `CLAUDE.md`'s *forward reference that never landed*, in its most
  expensive form: a gotcha page that names a mechanism and no page describes it.
- **`stream-leader-keeps-moving` is the other**, pointed at from [[raft-in-nats]] and
  [[advisories]]. Step 6 of the last plan just documented its **observable** — the leader-elected
  advisory on `$JS.EVENT.ADVISORY.STREAM.LEADER_ELECTED.<stream>` — so the symptom half now exists
  and the causes half does not.
- **Two open bank rows are owned by nobody else.** **Q37** (unexpected quorum loss after days of
  stable operation, [gh#7533](https://github.com/nats-io/nats-server/discussions/7533)) and **Q40**
  (evicting a sick-but-not-dead node, [gh#6892](https://github.com/nats-io/nats-server/discussions/6892)).
- **The monitoring chapter is now read**, which was the stated reason for deferring this last time:
  `/healthz`, the advisory subjects and the `/jsz?meta=1` meta-cluster fields are all on pages, so
  this plan starts with its observables already described.

**Everything this plan needs is unfetched.** `server/jetstream_cluster.go` is **not** in
`raw/nats-server-src/`, and neither gh#7533 nor gh#6892 is in `raw/gh-discussions/`. Budget for that.

**Done when:** `meta-layer` and `stream-leader-keeps-moving` exist and are cited by the pages that
already point at them; Q37 and Q40 are answered or carry a written reason they cannot be; and
[[raft-in-nats]]'s `## To verify` list is settled or explicitly narrowed.

---

## Step 1 — read `server/jetstream_cluster.go`, and write `meta-layer` · status: done 2026-09-01 — s-nats-server-jetstream-cluster (one summary over two raw files: the 64 quoted ranges and a three-node run). `meta-layer` written and cited by 16 pages; the To-verify items on `replicas` (meta replica count), `raft-in-nats` (heartbeat/election keys) and `choosing-a-topology` / `gateway` (global quorum) are settled — which is step 3's first and fourth item done early. Docs issues #43–#46. Unlanded ripples 0 → 0. Bank 107 rows / 91 answered → 91 (Q36 and Q38 gained the page; Q40's peer-remove half is observed, the thread is step 2)

```
ingest https://raw.githubusercontent.com/nats-io/nats-server/v2.14.6/server/jetstream_cluster.go
```

**This is a genuinely large read** — the reason three plans deferred it. Do not summarise the file;
**read it for the questions below** and store only the quoted ranges in
`raw/nats-server-src/jetstream-cluster-v2.14.6.md`, the way `filestore-v2.14.6.md` and
`topology-v2.14.6.md` were done.

The questions, in the order an operator meets them:

1. **What the meta group is** — one cluster-wide Raft group over *all* JetStream-enabled servers,
   distinct from the per-stream and per-consumer groups [[raft-in-nats]] already covers. Name the
   subjects it uses and how it differs from a stream's own group.
2. **What it stores**: stream and consumer *assignments* — which stream exists, on which peers, with
   which config. This is the record whose absence makes a stream an orphan, which is the mechanism
   [[streams-deleted-when-clustering-a-standalone-server]] needs and does not have.
3. **The meta group's replica count**, and how it relates to a stream's `num_replicas`. This is an
   open `## To verify` item on [[replicas]] and the docs state nothing.
4. **What happens when the meta leader is lost** — what still works, what blocks. The observed
   symptom from step 5 of the last plan is worth starting from: an MQTT connection failed with
   `lookup sessions stream … timeout` while the log said
   `JetStream has not established contact with a meta leader`.
5. **`meta.Reset()`** — already quoted in [[s-nats-server-leafnode-js-domains]] as what a leafnode
   with a matching domain triggers ("discards local metagroup state"). What that actually discards.

**Expected page:** `wiki/internals/meta-layer.md` (`type: internals`). Per the internals template it
must say **what you can observe** — `/jsz?meta=1`'s `meta_cluster.leader` and `cluster_size`,
`$JS.API.META.*`, the `Creating MQTT streams/consumers with replicas N` line's dependence on it — and
**why an operator cares**, which is rule 3 of the internals template: *do not write internals pages
that no gotcha, sizing or concept page needs*. Four already need this one.

**Ripple to expect:** [[streams-deleted-when-clustering-a-standalone-server]] (the mechanism it names),
[[replicas]] (the To-verify item), [[raft-in-nats]], [[jetstream-domain]],
[[no-suitable-peers-for-placement]], [[js-api-subjects]], `wiki/index.md`'s *Wanted pages*.

## Step 2 — Q37 and Q40, and `stream-leader-keeps-moving` · status: done 2026-09-01 — s-gh-7533-quorum-loss-mqtt, s-gh-6892-evict-a-sick-node, s-nats-server-kick-ldm-mqtt-session. **Both threads were unanswered** (zero comments each); the rows say so. `stream-leader-keeps-moving` written symptom-first with six ranked causes from pages already verified, and gh#7533's sequence mapped line by line (the `10071` first line traced to `mqttSession.save`'s expected-last-subject-sequence header; its cause stays unexplained). Q40 got its own runbook, `evict-a-sick-server`, because the thread gave no procedure and no existing runbook owned one: the KICK and LDM system requests were read and run (KICK disconnects, LDM only informs), peer-remove's five-minute rejoin from step 1 is the other half. Bank 91 → 93 answered (Q37 as no-public-answer, Q40 answered). Unlanded ripples 0 → 0

```
ingest https://github.com/nats-io/nats-server/discussions/7533   # Q37, quorum loss after days stable
ingest https://github.com/nats-io/nats-server/discussions/6892   # Q40, evicting a sick-but-not-dead node
```

**Read the threads before deciding the page's shape.** Both are unread, and either may turn out to be
unanswered — in which case say so on the row and on the page, as Q75, Q78, Q81 and Q103 were handled.
Do not manufacture an answer from the source and present it as the thread's.

**Expected page:** `wiki/gotchas/stream-leader-keeps-moving.md`, **symptom-first** per the gotcha
template — the title is what someone would say. Its *Symptom* section has an unusual advantage: the
observable is already documented, so open with the real advisory subject
`$JS.EVENT.ADVISORY.STREAM.LEADER_ELECTED.<stream>` and the fact that **advisories are published once
and stored nowhere**, so catching a flap that happened overnight needs a stream already capturing
`$JS.EVENT.ADVISORY.>` ([[advisories]]).

**Causes to rank**, gathered from pages that already exist and must be cited rather than restated:
`resetClusteredState` and the `Resetting stream cluster state` log line ([[raft-in-nats]]); a stream
lagging its group (`has high message lag`, [[stream-has-high-message-lag]]); slow disk on one peer
([[filestore-layout]]); a saturated route ([[monitoring-endpoints]]'s `/routez` `rtt`, **remembering
that a client's `rtt` is up to an hour old and a route's is not**).

**Q40 is a runbook question inside a gotcha page.** If the thread gives a real procedure — peer-remove,
lame-duck, or otherwise — it may belong on [[rebalance-streams]] or [[upgrade-a-cluster]] instead of a
new page. Decide from the thread, not from here.

## Step 3 — settle `raft-in-nats`'s open items · status: done 2026-09-01 — s-docs-monitor-raftz, s-nats-server-raftz. All four items settled: the heartbeat/election constants and the global-quorum claim had already fallen out of step 1; `/raftz` was read from `monitor.go` and **run** (follower and leader views, six filter combinations) — its field set is on `monitoring-endpoints` and `raft-in-nats`; compaction and snapshot timing are a table of constants on `raft-in-nats`. The docs page that was supposed to document all of this is 173 bytes with no response fields (docs issue #47, verified live), and the sibling sweep found six monitor reference pages printing system-request payload names the HTTP handlers ignore (#48 ★, observed on `/accountz` and `/raftz`). Unlanded ripples 0 → 0

```
ingest raw/nats-docs/reference/system/monitor/raftz.md      # if present; else fetch it
```

Three items sit unsettled on [[raft-in-nats]] and one on [[choosing-a-topology]]:

- **The heartbeat interval and the 4–9 s election window** are stated in docs prose only; no source
  read so far names a config key that sets them, **if any is exposed**. Settle from
  `jetstream_cluster.go` / `raft.go` constants at v2.14.6 — and if no key is exposed, **say that**,
  because "you cannot tune this" is the answer an operator needs.
- **`/raftz`'s field set** is unread. [[monitoring-endpoints]] records the endpoint and its `account`
  and `group` parameters but not what it returns. **Run it** — a 3-node cluster is cheap, and step 5 of
  the last plan already has a working recipe (`raw/nats-server-src/mqtt-websocket-observed-v2.14.6.md`
  §14 builds one; note the port collision it hit).
- **Log compaction and snapshot timing** are documented with `/raftz` and likewise unread.
- **"stream and consumer creation needs a global quorum"** is asserted on
  [[choosing-a-topology]] and [[multi-region-jetstream]] with no source. Either confirm it from the
  meta-layer read in step 1 or mark it `(unverified)` explicitly.

**Watch for docs issues.** `/raftz`'s reference page is in the generated tree — the same tree that
produced docs issues #1–#3, #19, #22 and #23. If a field or default there disagrees with the server,
that is a row in `inbox/docs-issues.md`, and by now the sweep instinct applies: **check the siblings**.

---

## Not in this plan, and why

- **Filing `inbox/docs-issues.md` and `inbox/server-issues.md`.** Deliberately parked: the current
  phase is **collecting**, not reporting. Both files are shaped to be sent whenever that changes; keep
  adding to them, and keep `upstream` reading `not filed`.
- **The rest of `plan-consolidation-2026-08-31.md`** (steps 2, 3, 5–8). That is the standing follow-on
  queue and is worked on its own, not folded in here. Its largest debts as of 2026-09-01:
  `concepts/account` 21, `concepts/stream` 16, `concepts/replicas` 15, `entities/nats-cli` 11.
- **`consumer-keeps-redelivering`**, the third wanted page. Still needs a public thread with a real
  symptom. The best candidate found so far is **issue #6921** (open, labelled *defect*, assigned to
  @neilalexander): acks stalling on a stream with `max_msgs_per_subject: 5` and a `LastPerSubject`
  deliver policy, resolved by changing `AckPolicy` to `None` or `DeliverPolicy` to `All`. Scout it if
  step 2's threads are cheap; otherwise leave it.
- **`learn/core-nats`, 0 of 11**, and **`learn/resilient-clients`, 0 of 8.** Mostly
  application-development material that `CLAUDE.md` puts out of scope. The server-facing minority is a
  small plan of its own.
- **Q105** (why `nats object ls` fails on a *mirror* of an object bucket across two JetStream domains).
  Answered upstream by a maintainer and by nothing here; it is a mirrors-and-subject-transform question,
  not a meta-layer one.

## Method notes

- **The binary must stay at 2.14.6.** Every "observed" note in this wiki is attributable only while
  `nats-server --version` matches `verified-against`. Upgrade the binary and those fields together or
  neither.
- **Keep running things.** Five rows across the last two plans were closed by running the server rather
  than reading — Q75, Q80, Q97, Q60, Q61 — and two of this plan's three steps are runnable.
- **A source that confirms an existing page is still a result.** Say so in the log; it is what stops
  the same file being re-read in three plans' time.
- **Question-bank arithmetic to beat:** 105 rows, **83 answered**, ★ 42 of 42. Landing Q37 and Q40
  gives **85**. Both are single unread threads, so either may close as a dead end instead — which
  counts as work done, not as a miss.
