---
title: "Consumer keeps redelivering"
type: gotcha
area: [jetstream]
since: [2.10]
verified-against: nats-server 2.14.6
verified-on: 2026-09-03
tags: [redelivery, ack, ack_wait, max_deliver, max_ack_pending, backoff, nak, batch, last_per_subject, defect, measured]
aliases: ["consumer keeps redelivering", "messages processed twice", "messages redelivered after ack", "acked messages redelivered", "redelivery loop", "acks not registered", "tries: 2", "duplicate deliveries", "consumer-keeps-redelivering"]
sources: [s-issue-6921-last-per-subject-acks, s-so-78603662-acked-but-redelivered, s-nats-server-redelivery-observed, s-gh-6628-ackwait-vs-dupe-window, s-gh-6350-exponential-backoff, s-gh-4972-nak-with-delay-blocks, s-gh-5631-nak-not-immediate, s-nats-server-nak-backoff-observed, s-docs-delivery-and-acknowledgment, s-docs-acknowledgment, s-relnotes-2.11.5, s-relnotes-2.11.2, s-relnotes-2.14.1, s-relnotes-2.10, s-relnotes-2.11, s-relnotes-2.12, s-relnotes-2.14]
created: 2026-09-03
updated: 2026-09-03
---

# Consumer keeps redelivering

A JetStream consumer hands the same message out again, and again: the handler sees `tries: 2`, then
`3`, the work is done twice, and — the form that reaches a forum — it happens **even though every
message is acked**. The server logs nothing at all. This page is what a redelivery loop looks like
from the outside, the three reads that narrow it down, and the causes in the order they turn out to
be the answer. The loop itself is explained on [[ack-and-redelivery]].

## Symptom

From a run on nats-server 2.14.6 (`ack_wait: 2s`, three messages fetched without acking, then again
three seconds later; source: [[s-nats-server-redelivery-observed]]):

```
$ nats consumer next LOOP worker --no-ack
[00:34:29] subj: loop.job / tries: 1 / cons seq: 1 / str seq: 1 / pending: 2
…
$ nats consumer next LOOP worker --no-ack
[00:34:32] subj: loop.job / tries: 2 / cons seq: 4 / str seq: 1 / pending: 0
```

`tries:` is the delivery count; `str seq` repeats while `cons seq` keeps climbing. In `nats consumer
info` the loop is three numbers that stop moving together:

```
  Last Delivered Message: Consumer sequence: 6 Stream sequence: 3 Last delivery: 11ms ago
    Acknowledgment Floor: Consumer sequence: 0 Stream sequence: 0
        Outstanding Acks: 3 out of maximum 1,000
    Redelivered Messages: 3
```

and in JSON `num_redelivered: 3`, `num_ack_pending: 3`, `ack_floor.stream_seq: 0` while
`delivered.consumer_seq` climbs. **The server log says nothing** — zero lines at `INF`, `WRN` or `ERR`
mention the stream across the run; at `-DV` every delivery is a `->> [MSG <subject> …
$JS.ACK.<stream>.<consumer>.<delivered>.<stream seq>.<consumer seq>.<ts>.<pending> …]` trace line, and
the delivery count is the first number after the consumer name.

The two public forms of the complaint: "my consumer processes each message twice, despite calling
`msg.AckAsync()`" (source: [[s-so-78603662-acked-but-redelivered]]), and "after a few successfully
ACKed messages … the messages are being redelivered, but ACK are still not registered", with the
floor frozen (source: [[s-issue-6921-last-per-subject-acks]]).

## Rule out first: a loop, or a stall — and two things it is not

- **`Outstanding Acks: N out of maximum N` with nothing being delivered is a stall, not a loop.** The
  cap is full of messages that are sleeping — delayed naks hold their slot for the whole delay, an
  abandoned batch holds its slots until `ack_wait` — and the consumer delivers nothing new until one
  expires (source: [[s-gh-4972-nak-with-delay-blocks]], confirmed on 2.14.6 in
  [[s-nats-server-nak-backoff-observed]]). See *A delayed nak keeps its `max_ack_pending` slot* on
  [[ack-and-redelivery]] and [[worker-pool]].
- **It is not the duplicate window.** `duplicate_window` bounds re-*publication* of a `Nats-Msg-Id`;
  no stream setting suppresses a re-*delivery*, and setting the window longer than `ack_wait` changes
  nothing (source: [[s-gh-6628-ackwait-vs-dupe-window]]).
- **A window of *different* sequences arriving again across a leafnode is another page**:
  [[duplicate-messages-across-a-leafnode]].

## Quick triage

```
# 1 · the controls and the state in one read — Ack Wait, Deliver Policy, the floor, Redelivered Messages
nats consumer info <stream> <consumer>
nats consumer info <stream> <consumer> --json | jq '{num_ack_pending, num_redelivered, ack_floor, delivered, ack_wait: .config.ack_wait, backoff: .config.backoff, max_deliver: .config.max_deliver, ver: .config.metadata["_nats.ver"]}'

# 2 · are the acks reaching the server at all, and before or after the next delivery? (server started with -DV)
grep -E '\$JS.ACK.<stream>.<consumer>\.' nats-server.log | grep -E '<<- \[PUB|->> \[MSG' | tail -20

# 3 · the server version, if the consumer's metadata does not carry it
nats --server nats://sys:sys@<host>:4222 server list
```

Read the answers against the causes: `Ack Wait` in microseconds or a second, or a `backoff` whose
first entry is short, is cause 1; `Outstanding Acks: 0`, `Redelivered Messages: 0` at the time you
look and a handler that fetches in batches is cause 2; no `<<- [PUB $JS.ACK…` lines for a delivery is
cause 3; `MSG_NAKED` advisories or `--nak` in the handler is cause 4; `Deliver Policy: Last Per
Subject` on a 2.11.0–2.11.4 server, or an R3 consumer after a rollout on an old 2.10 or 2.11, is
cause 5.

## Causes, ranked

### 1 · The ack deadline is shorter than the work — including a `backoff` that replaced `ack_wait`

**The trap.** `ack_wait` starts the moment a message is *delivered*, not when the handler picks it up,
and the default is 30 s (source: [[s-docs-delivery-and-acknowledgment]]). Two ways to shrink it
without noticing:

- **A `backoff` overwrites `ack_wait` with its first entry**, in the server (`consumer.go:658` at
  2.14.6). `--backoff-min=1s` is a one-second deadline for every first delivery (source:
  [[s-nats-server-nak-backoff-observed]]).
- **On the API the entries are nanoseconds.** A client whose `Backoff` field takes plain integers
  sends them as they are: `backoff: [10000]` is stored as `ack_wait: 10000` and prints as **`Ack Wait:
  10µs`**. That is the Stack Overflow question behind this page's title — `MaxDeliver = 2`, `Backoff =
  [10000]`, every message processed twice despite `AckAsync`, more times with a higher `MaxDeliver`
  (source: [[s-so-78603662-acked-but-redelivered]]).

Measured on 2.14.6 with the poster's numbers and a handler that takes 5 ms before acking: **every
message delivered exactly twice** with `max_deliver: 2`, **ten times each** with `max_deliver`
unlimited until the pull's batch of 100 was used up, once with `ack_wait: 30s`. Acked the instant
they arrived on localhost, six pulls of seven delivered once and the seventh redelivered the same ten
messages ninety times in six milliseconds — the ack's arrival is what stops the redelivery, and the
timer does not wait for it, so the symptom looks intermittent (source:
[[s-nats-server-redelivery-observed]]).

**How to confirm.** `Ack Wait:` in `nats consumer info` against the handler's real time per message;
`config.backoff` present when you never set one; on `-DV`, the `<<- [PUB $JS.ACK…` for delivery 1
arriving *after* the `->> [MSG … .2.<seq>.…]` for delivery 2.

**The fix.** Raise `ack_wait` past the slow case, or send **in-progress** from a long handler. Never
write `ack_wait` next to `backoff` and believe the `ack_wait`; make the first backoff entry at least
the normal processing time. If the client's backoff type is a number, check the unit before typing
one. And set `max_deliver` — with the default `-1` a bad deadline redelivers forever.

### 2 · A pull batch bigger than the workers can drain within `ack_wait`

**The trap.** A fetch delivers the whole batch at once, so **every message in the batch is on the
clock from the moment the batch lands**. With `ack_wait: 8m`, a batch of 100 and a few seconds of
work per message, the tail of the batch is past its deadline before the worker reaches it — and the
consumer's state looks fine in between: the reporter's `nats consumer info` showed `Outstanding Acks:
0`, `Redelivered Messages: 0`, and the cause was found by describing the fetch loop, not from server
output. Fetching one message at a time ended it (source: [[s-gh-6628-ackwait-vs-dupe-window]]).

The tail comes back **on the open pull**: a redelivery needs a pull waiting at the moment the deadline
passes, which a consume loop's standing pull provides. With the batch exactly the message count, the
first pull was satisfied before the timer fired, the acks cleared the queue, and the next pull found
nothing (source: [[s-nats-server-redelivery-observed]], run H.3).

**How to confirm.** Redeliveries clustered at the end of each batch; `tries: 2` on messages the
worker never reached before their deadline; the arithmetic `batch × time per message > ack_wait ×
workers`.

**The fix.** Size the batch to fit inside `ack_wait × workers` — the same rule [[consumer]] states
from the other end — or ack as you go rather than at the end; and keep `max_ack_pending` at or above
the batch size so the two limits do not fight.

### 3 · The handler does not ack on the success path, or the ack never arrives

**The trap.** A handler that processes but never acks is indistinguishable from a crashed reader: the
message stays in flight, `ack_wait` elapses, and with the default `max_deliver: -1` that repeats
**forever** (source: [[s-docs-delivery-and-acknowledgment]]). A plain ack is fire-and-forget; one lost
on a dropped connection leaves the floor where it was, and the message is redelivered to a reader that
already handled it. Acking twice does nothing useful — Go and Python reject the second ack locally with
*"message was already acknowledged"*, the server ignores it (source:
[[s-docs-delivery-and-acknowledgment]]).

**How to confirm.** `Outstanding Acks` growing at the rate of delivery with `Redelivered Messages`
following after one `ack_wait`; on `-DV`, `->> [MSG …]` lines with no matching `<<- [PUB $JS.ACK…]`.

**The fix.** Ack on every success path, once, in one place. Where reprocessing is harmful and the
handler cannot be made idempotent, use the **double ack** — a request that waits for the server's
confirmation (`DoubleAck` in Go, `ackAck` in JavaScript, `ack_sync` in Python, `ackSync` in Java,
`double_ack` in Rust). Design the handler for at-least-once regardless: this is the delivery
guarantee, not a bug in it.

### 4 · The handler naks, and `max_deliver` is unlimited

**The trap.** A bare nak asks for redelivery **immediately** — measured `0.00 s` on 2.14.6 — so a
transient failure retries in the same instant, fails again and pins a worker on one message; a
poison message with no term path burns every attempt and holds up the messages behind it (source:
[[s-docs-acknowledgment]], [[s-nats-server-nak-backoff-observed]]). Two things make it worse:

- **`max_deliver` defaults to `-1`**, so the loop has no end and no advisory.
- **A nak that carries a delay, on a consumer with a `backoff`, does not wait the delay** — it waits
  `delay + (backoff[delivery count] − backoff[0])`, and `-NAK {}` with an empty options object counts
  as a delayed nak. The docs say the backoff does not slow a nak; that is true only of a bare one
  (source: [[s-nats-server-nak-backoff-observed]]; `inbox/docs-issues.md` #38, `inbox/server-issues.md`
  SI-2). A nak that fails to redeliver *at once* — the reporter of an unanswered 2024 thread saw
  exactly that, with no error, on 2.10.14 — is this rule seen from the other side (source:
  [[s-gh-5631-nak-not-immediate]]).

**How to confirm.** `$JS.EVENT.ADVISORY.CONSUMER.MSG_NAKED.<stream>.<consumer>` advisories (`nats
events --js-advisory`); `tries:` climbing on the same message with no `ack_wait` between attempts.

**The fix.** Nak *with a delay*, and **term** when the code can tell no attempt will succeed. Pick one
retry mechanism per consumer — a `backoff` for `ack_wait` timeouts, or delayed naks with no backoff
configured — because the two do not compose (source: [[s-gh-6350-exponential-backoff]]). Set
`max_deliver`, and capture `$JS.EVENT.ADVISORY.CONSUMER.MAX_DELIVERIES.>` into a stream, or the
drop is invisible: [[dead-letter-queue]]. When the retry delay is long, the retry is a scheduled
publish, not an ack answer: [[message-scheduling]].

### 5 · A server version with a known redelivery defect

Redelivery of *acknowledged* messages has been a server bug in the public release notes several
times, always with a shape:

| server | shape | fixed in | source |
|---|---|---|---|
| 2.11.0 – 2.11.4 | a `last_per_subject` consumer with explicit acks on a stream whose per-subject limit leaves interior deletes (`max_msgs_per_subject` above 1): after the first acks the floor freezes, `Outstanding Acks` sits at the cap, redeliveries follow and their acks do not take either; `ack_policy: none` or `deliver_policy: all` clears it. Reproduced in .NET and Rust; Go "worked" only while it omitted `max_ack_pending: 1` | **2.11.5** (#7005) | [[s-issue-6921-last-per-subject-acks]] · [[s-relnotes-2.11.5]] |
| 2.11 before 2.11.2 | replicated consumers: "acknowledged messages could be redelivered after a consumer leader change" | **2.11.3** — 2.11.2 carries the fix but is withdrawn for a regression | [[s-relnotes-2.11.2]] |
| 2.10 before 2.10.16 / 2.10.17 | "redelivery of acked messages during server restarts" (#5419); "redelivery after successful ack during rollout restarts" (#5482); followers inheriting a redelivered sequence that "could break ack gap fill" (#5533) | **2.10.17** | [[s-relnotes-2.11.2]] |
| 2.14.0 | "consumer redelivered in a drifted state" on workqueue or interest streams with `max_deliver`, after single removals, purges or compactions (#8102); a consumer file store not flushing "when deleting a single redelivery, avoiding unexpected further redeliveries" (#8168) | **2.14.1** | [[s-relnotes-2.14.1]] |

Issue #6921's own recipe — `FIVE` with `max_msgs_per_subject: 5`, two messages per subject, a
`last_per_subject` + explicit + `max_ack_pending: 1` consumer — delivers once each with the floor
following every ack on **2.14.6** (source: [[s-nats-server-redelivery-observed]], run G); the wiki
states the range from the reporters, not from a run of an old binary.

**How to confirm.** The server version (`_nats.ver` in the consumer's metadata, `nats server list`,
`nats server info`) inside a range above, and the shape: the deliver policy, the stream's per-subject
limit, a rollout or leader move just before. The same handler behaving on a `deliver_policy: all`
consumer was the #6921 reporters' proof.

**The fix.** Upgrade — 2.10.17, 2.11.5 (never 2.11.2), 2.14.1 are the floors. The 2.11.2 consumer
fix has a stated cost: replicated consumers wait for delivered state to reach quorum before delivering
more, and the note names R1 consumers, `ack_policy: none` and ordered consumers as the shapes that are
not slowed (source: [[s-relnotes-2.11.2]]).

## The 2.10 patch trail

Beyond 2.10.16 and 2.10.17 in the table, the line kept fixing redelivery accounting (source:
[[s-relnotes-2.10]]): 2.10.10 — "acking a redelivered msg with more pending should move the ack
floor" (#5008); 2.10.14 — "multiple deliveries of the same message that cause the delivery count
decreasing" (#5305); 2.10.22 — pull consumers "recalculate max delivered when expiring messages,
such that the redelivered status does not report incorrectly and cause a stall with a max deliver
limit" (#5995); 2.10.23 — backoff "correctly respected with multiple in-flight deliveries" (#6104)
and checked against `max_deliver` (#6154), replicated consumers wait for quorum before updating
delivered state (#6139); 2.10.25 — AckAll retries no longer time out after a restart (#6392),
replicated consumers no longer stuck after leader changes (#6387); 2.10.26 — `max_deliver` state
preserved on interest streams so a new consumer does not remove the message (#6575); 2.10.28 —
AckAll on interest streams removes messages (#6587) and uses the right floor on R1 (#6790). A 2.10
cluster below **2.10.26** has at least one of these open.


## The 2.11 patch trail

Beyond 2.11.2 and 2.11.5 in the table (source: [[s-relnotes-2.11]]): **2.11.0** — replicated
consumers "should no longer skip redeliveries of unacknowledged messages after a leader change"
(#6566); **2.11.4** — redeliveries no longer reported for a consumer with `max_deliver: 1` (#6877);
**2.11.7** — a pull consumer with an inactive threshold counts pending acks before it is deleted
(#7052), so a slow handler no longer loses its consumer mid-batch; **2.11.9** — an infinite
`max_deliver` (`-1`) no longer underflows (#7216).


## The 2.12 patch trail

The 2.12 line has the 2.14.1 fixes under another number — **2.12.9** (2026-05-20): "a number of
paths that could leave consumer redelivered in a drifted state have been fixed, e.g. with workqueue
or interest-based streams with `max_deliver`, on single message removal or after purges/compactions"
(#8102); "pending state no longer leaks when reaching max deliveries" (#8156); "consumer file stores
will now correctly flush when deleting a single redelivery, avoiding unexpected further redeliveries"
(#8168) — and, earlier, **2.12.5**'s "messages that have reached the max deliver state are preserved
with the WorkQueue retention policy" (#7845) and **2.12.7**'s `max_ack_pending` no longer stuck on
deleted messages left in the pending state (#7984) (source: [[s-relnotes-2.12]]).


## Prevention

- `ack_wait` longer than the slow case, with **in-progress** from long handlers; the first `backoff`
  entry chosen knowing it *is* the deadline, and typed in the client's unit.
- Batches that fit inside `ack_wait × workers`; `max_ack_pending` at or above the batch.
- `max_deliver` set and `MAX_DELIVERIES` advisories captured — never `-1` on a consumer whose handler
  can fail.
- One retry mechanism per consumer: a `backoff`, or delayed naks, not both.
- Idempotent handlers, or the double ack where they cannot be: at-least-once means a redelivery is
  always possible, whatever the cause.
- Version floors for replicated consumers and `last_per_subject`: 2.10.17, 2.11.5, 2.14.1.

## Explained by

[[ack-and-redelivery]] — the loop, the four answers, `backoff` replacing `ack_wait`, what a delayed
nak actually waits, why a nak never reports a failure.
[[consumer]] — the batch is on the clock, and what `nats consumer info` shows.

## Version notes: the 2.14 line

The version table above stops at 2.14.1. The rest of the line, from the seven bodies (source:
[[s-relnotes-2.14]]): **2.14.2** fixed "potential protocol-level corruption from rewriting `$JS.ACK`
subjects" (#8242) — an ack whose subject was mangled in flight is an ack the server never counted;
**2.14.6** fixed "a flow control problem where replicated consumers could get stuck after a leader
change" (#8488), "various consumer create issues that could destroy the state of an existing
consumer with the same name" (#8491) — a re-create by a client with the same durable name could reset
the floor to the start policy and replay — and delivery counts that underflowed below zero (#8512).
A consumer on 2.14.2–2.14.5 that replays from the beginning after a leader change or after its
client reconnected and re-created it is one of those two.


## Related

[[worker-pool]] · [[dead-letter-queue]] · [[nats-timeout]] · [[duplicate-messages-across-a-leafnode]]
· [[advisories]] · [[message-scheduling]] · [[nats-server-2.11]] · [[nats-server-2.14]] ·
[[nats-server-2.10]] · [[nats-net]]

## Sources

[[s-issue-6921-last-per-subject-acks]] · [[s-so-78603662-acked-but-redelivered]] ·
[[s-nats-server-redelivery-observed]] · [[s-gh-6628-ackwait-vs-dupe-window]] ·
[[s-gh-6350-exponential-backoff]] · [[s-gh-4972-nak-with-delay-blocks]] ·
[[s-gh-5631-nak-not-immediate]] · [[s-nats-server-nak-backoff-observed]] ·
[[s-docs-delivery-and-acknowledgment]] · [[s-docs-acknowledgment]] · [[s-relnotes-2.11.5]] ·
[[s-relnotes-2.11.2]] · [[s-relnotes-2.14.1]] · [[s-relnotes-2.10]] · [[s-relnotes-2.11]] · [[s-relnotes-2.12]] · [[s-relnotes-2.14]]
