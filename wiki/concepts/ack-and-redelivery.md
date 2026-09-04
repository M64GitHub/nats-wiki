---
title: Ack and redelivery
type: concept
area: [jetstream]
since: [2.10]   # present at 2.10, the oldest line this wiki covers; not the arrival
verified-against: nats-server 2.14.6
verified-on: 2026-09-03
tags: [ack, nak, term, ack_wait, max_deliver, max_ack_pending, backoff, advisories]
aliases: [acknowledgement, acknowledgment, ack, nak, term, at-least-once, AckWait, MaxDeliver]
sources: [s-docs-delivery-and-acknowledgment, s-docs-acknowledgment, s-docs-pull-consumers, s-docs-consumer-config, s-nats-server-constants-2.14.6, s-docs-policies, s-docs-mqtt-qos-sessions-and-retained, s-docs-monitoring-advisories-and-events, s-docs-worker-pool, s-gh-6350-exponential-backoff, s-gh-4972-nak-with-delay-blocks, s-gh-6628-ackwait-vs-dupe-window, s-nats-server-nak-backoff-observed, s-synadia-reliable-delivery-dlq, s-gh-5631-nak-not-immediate, s-gh-4994-scale-to-zero-dlq, s-gh-7590-dlq-payload-loss, s-so-78603662-acked-but-redelivered, s-nats-server-redelivery-observed, s-issue-6921-last-per-subject-acks, s-relnotes-2.11.2, s-relnotes-2.14.1, s-relnotes-2.10, s-relnotes-2.14, s-nats-server-client-lifecycle-observed]
created: 2026-08-31
updated: 2026-09-04
---

# Ack and redelivery

JetStream's **at-least-once** delivery is two halves: the durable [[stream]] holds the message, and
the [[consumer]]'s ack/redeliver loop keeps handing it out until a reader confirms it. A reader can
crash, a handler can throw, a process can be killed — the message comes back instead of vanishing.
This page is the loop: what a client can answer, and what the server does when the answer is late
or never comes.

## How it behaves

A message on a consumer moves through three states (source:
[[s-docs-delivery-and-acknowledgment]]):

1. **Delivered, in flight** — the consumer has handed the message to a reader. The message stays in
   the stream and the consumer's **acknowledgment floor** has not moved past it.
2. **Acked** — the reader answers; the floor advances past the message.
3. **Redelivered** — no answer arrived within `ack_wait`, so the server assumes the reader failed
   and delivers the message again, to the same reader or another one on the same consumer.

The gap between the last delivered sequence and the acknowledgment floor is the **in-flight set**,
and `max_ack_pending` is the cap on its size.

The **delivery count rides on the message** — the CLI prints `tries: 1` on a first delivery,
`tries: 2` on a redelivery — so a reader always knows how many times it has seen one without
calling `nats consumer info`.

### Redelivery is in delivery order, not stream order

A consumer normally has several messages in flight, so while one waits to be redelivered the
consumer keeps handing out later ones. **A redelivered message can arrive after messages with
higher stream sequences.** Setting `max_ack_pending` to `1` is the only way to get strict in-order
processing: the consumer delivers one message at a time and will not move past it until it is
acked, so a redelivery always comes back before anything new. That costs throughput — no overlap
between handlers — so use it only when order actually matters (source:
[[s-docs-delivery-and-acknowledgment]]).

## The four answers

A client answers a delivered message in **exactly one of four ways**
(source: [[s-docs-acknowledgment]]):

| answer | effect |
|---|---|
| **ack** | the work succeeded; the server clears the pending entry and never delivers the message again |
| **nak** | redeliver. A plain nak asks for redelivery **immediately**; a delay the client attaches is honoured only if the consumer has no `backoff` — see *What a delayed nak actually waits* |
| **term** | give up — this message can never be handled. Clears the pending entry and moves the ack floor exactly as an ack does, but records that the work never happened |
| **in-progress** | *not* a final answer — it **resets the `ack_wait` timer** so a long job does not trip redelivery |

**A delayed nak is a client-library call.** The CLI's `--nak` only asks for immediate redelivery;
to space out redeliveries from the CLI, set a consumer `backoff` instead.

**A nak returns the message to the consumer, not to the worker that nak'd it** — with a
[[worker-pool|worker pool]] sharing one consumer, the redelivery can land on a different worker. If
*which* worker gets a message matters, that is what [[priority-groups]] are for, not what a nak is
(source: [[s-docs-worker-pool]]).

**`max_ack_pending` is shared by the whole consumer, not held per reader.** "Five workers get 1000
between them, not 1000 each" — so it doubles as a concurrency ceiling on the pool, and set below the
worker count it starves them: "set it to 3 and only three messages are ever in progress, so ten
workers leave seven of them idle no matter how much is stored. Set the cap to at least your worker
count, with room to spare" (source: [[s-docs-worker-pool]]). The two settings pull against each
other — `max_ack_pending` bounds how much is in flight, `ack_wait` bounds how long a failure stays
invisible — and a large cap plus a correlated failure means everything in flight redelivers at once.

**After a term** the message is gone from *this* consumer but stays in the stream under the default
`limits` retention: other consumers still see it and it ages out with the stream's limits. On a
`workqueue` or `interest` stream a term removes it just as an ack would — see
[[retention-policies]].

### Plain ack vs double ack

A plain ack is **fire-and-forget**: the client sends it and moves on. If the ack is lost in flight,
the server never advances the floor, `ack_wait` elapses, and the message is redelivered to a reader
that already handled it.

A **double ack** sends the ack as a request and waits for the server to confirm it landed. It costs
a round trip per message, so it is a deliberate choice for work where reprocessing is harmful and
the handler cannot be made idempotent. There is no CLI flag — it is a client-library call, named
`DoubleAck` (Go), `ackAck` (JavaScript), `ack_sync` (Python), `ackSync` (Java), `AckAsync` with the
double-ack option (.NET) and `double_ack` (Rust) (source: [[s-docs-delivery-and-acknowledgment]]).

## What configures it

Values below are as the 2.14 docs state them (source: [[s-docs-acknowledgment]],
[[s-docs-pull-consumers]]) and, where a line reference is given, confirmed against the server at
**v2.14.6** (source: [[s-nats-server-constants-2.14.6]]) — the docs' consumer reference does not
expose these at all, which is issue 4 in `inbox/docs-issues.md`.

| setting | CLI flag | default | what it does |
|---|---|---|---|
| `ack_wait` | `--wait` | **`30s`** (`consumer.go:573`) | how long the server waits for an answer before redelivering |
| `max_deliver` | `--max-deliver` | **`-1` (unlimited)** (`consumer.go:589`) | how many times one message may be delivered before the server gives up |
| `max_ack_pending` | `--max-pending` | **`1000`** (`consumer.go:580`) | how many messages the consumer delivers before they are acked |
| `backoff` | `--backoff=linear --backoff-steps=N --backoff-min=… --backoff-max=…` | unset | a growing wait between redeliveries |
| `ack_policy` | `--ack` | `explicit` in the docs' walkthrough | see below |

### Backoff

`backoff` is a list of delays, one per attempt. Three rules matter
(source: [[s-docs-acknowledgment]]):

- It **shapes redeliveries that fire when the `ack_wait` timer runs out** — and, at v2.14.6, it also
  changes the timing of a nak that **carries a delay**, which the docs deny. A **bare** nak is
  unaffected. See *What a delayed nak actually waits* below; the docs' flat "it doesn't slow a nak"
  is `inbox/docs-issues.md` **#38**.
- If the list has fewer entries than `max_deliver` allows, the server **reuses the last entry** for
  the remaining attempts.
- **Setting a backoff replaces `ack_wait`**: the first entry becomes the wait before the first
  redelivery, and therefore the ack deadline for the first delivery too. A `--backoff-min=1s` drops
  the effective ack deadline to 1 second, overriding any `--wait` set earlier. Pick a
  `--backoff-min` at least as long as normal processing takes. Confirmed in the server, not just the
  CLI — `consumer.go:658` at v2.14.6, and observed through the raw API
  (source: [[s-nats-server-nak-backoff-observed]]).

### Ack policies

| value | behaviour |
|---|---|
| `explicit` | each message is answered on its own — the right default for work that must not be lost, and what everything on this page assumes |
| `none` | no answer required; the server treats a message as done the moment it is delivered. No pending list, no ack wait, no redelivery |
| `all` | one ack retires every earlier message too — cheaper, but only fits a consumer that processes strictly in order |
| `flow_control` | used by the push consumers the server creates for durable mirrors and sources; acks ride the flow-control responses and behave like `all` |

`ack_policy` is **fixed at creation** (source: [[s-docs-policies]]).

## Retry: two mechanisms, one shared budget

Everything above describes *one* delivery. A retry policy is built out of two mechanisms that are
chosen by **who noticed the failure**, and they are not interchangeable
(source: [[s-gh-6350-exponential-backoff]], a maintainer's marked answer):

| the failure was | noticed by | the mechanism | where it is set |
|---|---|---|---|
| implicit — the handler hung, or the worker died, and no answer came | the server, when `ack_wait` expires | consumer **`backoff`** | consumer configuration, server-side |
| explicit — the handler caught an error and gave up on this attempt | the client, at once | **nak with a delay** (`nakWithDelay`) | a per-message client-library call |

> "If you do not ack the message (before the consumer's AckWait timeout happens) then you can specify
> a series of backoff times in the consumer's configuration… If you explicitly give up on processing
> the message using the 'nack' (negative ack) then you can specify the backoff period using
> `nakWithDelay`." — @jnmoyne, 2025-01-10

A policy that wants both needs both: a `backoff` does nothing for a handler that naks, and a delayed
nak does nothing for a worker that dies. Neither is an exponential-backoff *algorithm* — `backoff` is
a list of durations you supply (the CLI's generator is `linear`), and a nak's delay is whatever the
handler passes.

### A delayed nak keeps its `max_ack_pending` slot for the whole delay

**A message that has been delivered once and is waiting to come back counts as pending, delay or no
delay** (source: [[s-gh-4972-nak-with-delay-blocks]]). This is deliberate:

> "Any messages that was once delivered and had to be retried is pending, its an important constraint
> as max pending is used to manage ordering to name but one case. So this is working as designed,
> there's no alternative today." — @ripienaar, 2024-01-18

The reporter had `max_ack_pending: 10`, nak'd ten messages with a one-minute delay, and the consumer
stopped: 10 messages handled out of 100 published. **The failure mode is a total stall, not a
slowdown** — `Outstanding Acks` sits at its maximum with every worker idle until the first delay
expires. Confirmed on the v2.14.6 binary (source: [[s-nats-server-nak-backoff-observed]]); the
maintainers' answer is from 2024 and describes the behaviour as current *"today"*, with
@derekcollison arguing in the same thread that it should change and **no fix version named
anywhere**.

Three consequences:

- **Retry capacity and concurrency come out of one budget.** The cap must cover the work in flight
  *and* everything asleep in retry — at a nak rate of *R* per second with a delay of *D* seconds,
  roughly *R × D* slots are asleep at steady state (arithmetic from the constraint; no source states
  a number). See [[jetstream-sizing]].
- **Raising the cap is the only lever**: "The only real option today is to increase the maxackpending."
- **More consume loops do not help.** The same thread's reporter tried ten `Consume` callbacks
  instead of one and thought that gave ten workers' worth of slots; the extra throughput came only
  from dropping `MaxAckPending` out of the config, which put it back to the default of 1000. The cap
  is **one number per consumer**, whatever is pulling against it — across goroutines and across
  processes alike.

When the delay is long enough that this hurts, the retry is really a *scheduled publish* and belongs
on [[message-scheduling]] rather than on the ack loop — which is what a maintainer recommends for
work at scale ([[s-gh-7628-scheduler-vs-nak]]).

### The duplicate window has nothing to do with redelivery

A recurring confusion, and worth stating flatly: **no stream setting suppresses a redelivery**
(source: [[s-gh-6628-ackwait-vs-dupe-window]]).

> "AckWait and DupeWindow are two different settings that are not related to each other."
> — @MauriceVanVeen, 2025-03-10

`duplicate_window` bounds re-**publication** of the same `Nats-Msg-Id` into the [[stream]]
([[publishing]]); `ack_wait` bounds re-**delivery** of a message already stored. The dedup window is
consulted on publish and never on delivery, so setting it longer than `ack_wait` — the asker had
`10m` against `8m` — changes nothing. To be delivered once, bound the deliveries: "set the MaxDeliver
value to 1, or always Ack or Term the message once you get it."

**A batch fetch is the usual real cause.** That thread's redeliveries came from a pull batch of 100:
the `ack_wait` clock starts on **every message in the batch**, not on the one being worked, so with
`ack_wait: 8m` and a few seconds of work per message the tail of a 100-message batch is past its
deadline before the worker reaches it. Fetching one at a time ended it. Size the batch so it fits
inside `ack_wait × workers` — the same arithmetic [[consumer]] states from the other end.


### What a delayed nak actually waits

Three public sources disagree about whether a consumer `backoff` affects a nak, so it was **run on
the v2.14.6 binary** rather than decided from a page (source:
[[s-nats-server-nak-backoff-observed]], thirteen experiments, 2026-09-01). **Both published answers
are wrong**, and the rule neither states is:

```
effective wait  =  the delay the client asked for
                +  ( backoff[delivery count] − backoff[0] )
```

| what the client sends | consumer has a `backoff` | what happens |
|---|---|---|
| bare `-NAK` | no | immediate — **0.00s** |
| bare `-NAK` | yes (`5s, 10s, 15s`) | immediate — **0.00s**. The backoff does not touch it |
| `-NAK {"delay":2s}` | no | **1.95s**, every attempt. The delay is honoured |
| `-NAK {"delay":2s}` | yes (`5s, 10s, 15s`) | **2.000 · 7.000 · 12.000 · 12.001** seconds |
| `-NAK {"delay":0}` | yes (`5s, 10s, 15s`) | **0.00 · 4.94 · 9.94** — a delay nobody asked for |
| no answer at all | yes (`5s, 10s, 15s`) | **5.00 · 10.00 · 15.00** — the schedule, as documented |

The last row is the control: the schedule works exactly as the docs describe for `ack_wait` timeouts,
so rows 1–2 are a real negative rather than a broken setup.

**Why.** `processNak` backdates the message's pending timestamp by `ack_wait` —
`p.Timestamp = time.Now().Add(-o.cfg.AckWait).Add(d)`, under the comment *"now - ackWait is expired
now, so offset from there"* (`consumer.go:3231`) — but `checkPending` then measures that timestamp
against **the attempt's backoff entry**, not against `ack_wait` (`consumer.go:6066`). The comment is
exact only on a consumer with no backoff. Recorded as `inbox/server-issues.md` **SI-2**; the
documentation half is `inbox/docs-issues.md` **#38**.

**`-NAK {}` is not a bare nak.** The server branches on whether there is *anything* after the four
bytes `-NAK`, and an empty options object parses to a zero delay — so it takes the delayed path and
picks up the backoff term. Two client libraries implementing the same "plain nak" call can therefore
produce different timing, depending only on whether they serialise an empty options object.

**What the sources say, and why the page does not follow them.** The docs state three times that a
backoff "doesn't slow a nak" (source: [[s-docs-acknowledgment]]) — true of a bare nak, false of a
delayed one. A Synadia post answers "how do I retry a failed message with a backoff?" with
"Negatively acknowledge it" (source: [[s-synadia-reliable-delivery-dlq]]) — which is the one case the
backoff does not shape. **Prefer the server**: pick one mechanism per consumer, a `backoff` for
timeouts *or* delayed naks with no backoff configured, and do not expect a delay you asked for to
survive the combination.

### `ack_wait` beside a `backoff` is silently discarded

**Setting a `backoff` overwrites `ack_wait` with the first entry, in the server, not the client**
(`consumer.go:658`, under *"If BackOff was specified that will override the AckWait and the
MaxDeliver"*). Sent straight to `$JS.API.CONSUMER.CREATE`, `ack_wait: 30s` with
`backoff: [1s, 5s, 30s, 2m]` stores **`ack_wait: 1s`** (source:
[[s-nats-server-nak-backoff-observed]]).

So **the first backoff entry *is* your ack deadline**, and a `--backoff-min=1s` gives every handler
one second before the server decides it failed. In **pedantic** mode the server refuses instead —
`first backoff value has to equal batch AckWait` — but nats CLI 0.4.0 exposes no flag for it.

A published Go snippet with `AckWait: 30 * time.Second` next to `BackOff: [1s, …]` is doing this
silently to whoever copies it (source: [[s-synadia-reliable-delivery-dlq]]; `inbox/docs-issues.md`
**#39**).

### Why a nak never reports a failure

A nak is **fire-and-forget**: the client publishes it to the message's `$JS.ACK.…` subject and waits
for nothing. The server discards one whose delivery is out of range (`dseq <= o.adflr ||
dseq > o.dseq`) or whose message is no longer in the pending list, with no reply and no log line
(`consumer.go:3182–3190`). **The absence of an error is not evidence the nak was acted on** — which
is exactly what the reporter of an unanswered 2024 thread observed: "I do not have any error when
calling the Nak client method in problematic cases" (source: [[s-gh-5631-nak-not-immediate]], server
2.10.14, never answered by anyone).


## Limits and failure modes

Ranked by how often they are the answer.

1. **A handler that processes but never acks looks exactly like a crashed reader.** The message
   stays in flight, `ack_wait` elapses, and with the default `max_deliver: -1` that repeats
   **forever**. Always ack on the success path.
2. **`ack_wait` shorter than real processing time causes double work.** The server decides the
   worker stopped and redelivers a message that is still being handled, so two workers run the same
   job. Either raise `ack_wait` to cover the slow case, or send **in-progress** to reset the timer
   while a long job runs.
3. **A plain nak retries with no delay.** A transient failure then retries in the same instant,
   fails again, and pins one worker on one message. Nak *with a delay* — and do not reach for a
   consumer `backoff` to fix a nak loop: it leaves a bare nak untouched, and on a nak that carries a
   delay it changes the wait to something neither you nor the docs chose
   (*What a delayed nak actually waits*).
4. **A poison message with no term path burns every delivery attempt** and holds up the messages
   behind it. When the code can tell no future attempt will succeed, answer **term** so the message
   leaves the pending list at once. Use term only when that is genuinely knowable; when in doubt,
   nak with a delay and let `max_deliver` decide.
5. **`max_deliver` drops a message with no dead-letter.** **JetStream has no built-in dead-letter
   queue.** When a message hits the limit the server removes it from the consumer's pending list
   and never delivers it again; the message stays in the stream but the consumer's normal output
   says nothing. Watch the max-deliveries advisory (below) or the drop is invisible.
6. **`ack_policy: all` on a consumer with `max_ack_pending` above 1 is silent data loss.** Acking
   message 10 also retires a message 7 that failed and was waiting to come back. Strict order is a
   thing you have to create with `max_ack_pending: 1`, not something a consumer does by default.
7. **Acking twice does nothing useful.** Go and Python reject the second ack locally with
   *"message was already acknowledged"*; other clients ignore or resend it, and the server ignores
   the duplicate either way. Ack each delivery exactly once, in one place in the handler.

## Acked, and redelivered anyway — the three ways

The symptom page is [[consumer-keeps-redelivering]]; the mechanisms belong here.

### The `backoff`'s unit is nanoseconds, and its first entry is the deadline

On the JetStream API a duration is a signed 64-bit count of nanoseconds. A client whose `backoff`
field takes plain integers hands them over unchanged, so `backoff: [10000]` is stored as
`ack_wait: 10000` — **ten microseconds** — and `nats consumer info` prints `Ack Wait: 10µs` (source:
[[s-nats-server-redelivery-observed]], run H.1). That is the Stack Overflow question this wiki's row
14 was mined from: `MaxDeliver = 2`, `Backoff = [10000]`, every message processed twice despite
`AckAsync`, more times with a higher `MaxDeliver` (source: [[s-so-78603662-acked-but-redelivered]]).
Measured on 2.14.6 with the same numbers and a handler that takes 5 ms before acking: exactly twice
with `max_deliver: 2`, ten times each with it unlimited until the pull's batch ran out, once with
`ack_wait: 30s`. Acked on arrival on localhost the ack usually wins the race (six pulls of seven); the
seventh redelivered the same ten messages ninety times in six milliseconds. **The ack's arrival is
what stops a redelivery; the timer does not wait for it.**

### A redelivery needs a pull waiting when the deadline passes

An expired message goes on the consumer's redelivery queue; it is *sent* when a pull is there to take
it. A consume loop's standing pull is why the tail of an over-sized batch comes straight back; a pull
sized exactly to the messages, acked one by one, saw no redelivery at all at the same 10 µs deadline —
the acks cleared the queue before the next pull arrived (source:
[[s-nats-server-redelivery-observed]], run H.3). An explicit ack clears the pending entry whichever
delivery it names (`processAckMsgLocked`, `consumer.go:3717–3731` at 2.14.6), so the second ack of a
doubled message is a no-op and the floor ends correct.

### When it was the server

Redelivery of acknowledged messages has been a server defect several times, each with a shape and a
fix release: a `last_per_subject` consumer with explicit acks on a stream with `max_msgs_per_subject`
above 1 on 2.11.0–2.11.4, fixed in 2.11.5 (source: [[s-issue-6921-last-per-subject-acks]]);
replicated consumers after a leader change, fixed in 2.11.2 — withdrawn, so 2.11.3 — at a stated
throughput cost that R1, `ack_policy: none` and ordered consumers do not pay, and restarts and
rollouts on 2.10 before 2.10.16 / 2.10.17 (source: [[s-relnotes-2.11.2]]); drifted redelivered state
on workqueue and interest streams with `max_deliver` on 2.14.0, fixed in 2.14.1 (source:
[[s-relnotes-2.14.1]]). The table with the release lines is on [[consumer-keeps-redelivering]].


## What you can observe

Three advisories make the loop visible (source: [[s-docs-acknowledgment]]):

| event | subject |
|---|---|
| nak | `$JS.EVENT.ADVISORY.CONSUMER.MSG_NAKED.<stream>.<consumer>` |
| term | `$JS.EVENT.ADVISORY.CONSUMER.MSG_TERMINATED.<stream>.<consumer>` |
| delivery-limit drop | `$JS.EVENT.ADVISORY.CONSUMER.MAX_DELIVERIES.<stream>.<consumer>` |

**`MSG_NAKED`, not `MSG_NAK`.** The docs' advisory reference page gives the shorter form and it is
wrong — the server publishes `MSG_NAKED` (`jetstream_api.go:244` at v2.14.6, used at
`consumer.go:1244`). A subscription to `MSG_NAK` receives nothing, silently. See [[advisories]] and
issue 1 in `inbox/docs-issues.md`.

The terminated advisory carries the stream and consumer sequence, the delivery count, and an
optional reason attached to the term. The full set will live in [[advisories]].

`nats consumer info` prints the controls and the state:

```
Configuration:
           Ack Policy: Explicit
             Ack Wait: 10.00s
        Replay Policy: Instant
   Maximum Deliveries: 5
      Max Ack Pending: 1,000
```

and `num_ack_pending`, `num_redelivered`, `num_pending` and `ack_floor` in the JSON
(source: [[s-docs-consumer-config]]).

## Cheat sheet

```
nats consumer edit ORDERS shipping --ack=explicit --wait=10s --max-deliver=5
nats consumer edit ORDERS shipping --backoff=linear --backoff-steps=5 --backoff-min=1s --backoff-max=30s
nats consumer next ORDERS shipping --ack
nats consumer next ORDERS shipping --no-ack
nats consumer next ORDERS shipping --term
nats sub '$JS.EVENT.ADVISORY.CONSUMER.MAX_DELIVERIES.ORDERS.shipping'
nats events --js-advisory --no-srv-advisory
```

## Version notes: the 2.10 line

**Since.** `since: [2.10]` in the frontmatter means *present at 2.10, the oldest line this wiki covers*:
the 2.10 release bodies patch acks and redelivery from v2.10.1 on and none records the arrival, which is
older than the archive (source: [[s-relnotes-2.10]]).

The redelivery accounting fixes of 2.10 are listed release by release on
[[consumer-keeps-redelivering]] (*The 2.10 patch trail*) and in [[s-relnotes-2.10]]; the ones that
change what this page describes: **2.10.10** — acking a redelivered message with more pending moves
the ack floor (#5008); **2.10.23** — replicated consumers do not update delivered state until quorum
(#6139), and backoff is checked against `max_deliver` (#6154); **2.10.26** — `max_deliver` state is
preserved on interest streams so a new consumer does not remove the message (#6575); **2.10.28** —
AckAll removes messages from interest streams (#6587) and acks work for subjects containing `@`
(#6777).


## Version notes: the 2.14 line

- **2.14.0**: the ack subject gains a **v2 form** — `$JS.ACK.<domain>.<account hash>.<stream>.<consumer>.…`
  — behind `feature_flags { js_ack_fc_v2 }`, off by default; the body says it "will be enabled by
  default in v2.15", and at the 2.15 preview tag it is still off. Permissions or imports written
  against `$JS.ACK.<stream>.>` must be rewritten before that flips ([[js-api]]). Also 2.14.0: a new
  policy, **`AckFlowControl`**, used only by the server's own sourcing consumers (source:
  [[s-relnotes-2.14]]).
- **2.14.1**: redelivered state no longer drifts on WorkQueue or Interest streams with `max_deliver`,
  after single removals or purges (#8102); a consumer file store flushes when a single redelivery is
  deleted, "avoiding unexpected further redeliveries" (#8168); pending no longer leaks at
  `max_deliver` (#8156). **2.14.2**: "potential protocol-level corruption from rewriting `$JS.ACK`
  subjects" fixed (#8242). **2.14.6**: delivery counts no longer underflow below zero (#8512);
  replicated consumers stuck after a leader change (#8488).


## To verify

- No source ingested so far gives **metrics** (as opposed to advisories) for acked / naked /
  terminated / redelivered counts (question-bank Q59).

## What happens after the last redelivery: an advisory, and nothing else

When a message exhausts `max_deliver` the server stops delivering it and publishes **one** advisory on
`$JS.EVENT.ADVISORY.CONSUMER.MAX_DELIVERIES.<stream>.<consumer>` (confirmed on the wire at 2.14.6,
[[advisories]]). The message itself stays in the stream under its retention policy; what stops is
delivery to that consumer.

**There is no dead-letter queue.** The docs say it plainly: that advisory "is the only built-in signal
that this happened… If no one is subscribed when it fires, you never learn that order `987` stopped
being delivered" (source: [[s-docs-monitoring-advisories-and-events]]). Advisories are published once
and stored nowhere, so a design that depends on noticing exhausted messages needs a stream capturing
`$JS.EVENT.ADVISORY.>`, not a subscriber someone remembers to run.

### With nobody fetching, `ack_wait` does not advance the delivery count

**A pull consumer's redelivery needs a client asking for messages.** `ack_wait` expiring is not by
itself enough: with no client fetching, the message stays in `AckPending` and the delivery count does
not move, so `max_deliver` is never reached and the max-deliveries advisory never fires. Confirmed as
**by design** (source: [[s-gh-4994-scale-to-zero-dlq]]):

> "There appears to be no way to configure JetStream to eagerly move messages from pending to the dead
> letter queue upon `AckWait` timeout, without clients issuing fetches. The behavior of a push
> consumer + queue group setup appears to exhibit the same effect — if there are no subscribers in the
> queue group, messages remain in `AckPending` after the `AckWait`."

The asker tried "dummy fetch requests… to activate the message redirection" and "did not find a way
to trigger this manually."

**This is a trap for any pool that scales to zero.** Messages sit pending indefinitely, no advisory is
published, and every consumer number looks calm — the queue is not stuck, it is simply unobserved. If
something downstream depends on noticing failures, keep one puller alive or drive the check from
`num_ack_pending` rather than from advisories. See [[dead-letter-queue]].

### A message that exhausts `max_deliver` stays in the stream

The advisory is not a removal. Measured at v2.14.6 on **both** `workqueue` and `limits` streams: the
advisory fires with `stream_seq` and `deliveries`, the message is still stored, and the sequence the
advisory names fetches it with its payload (source: [[s-nats-server-nak-backoff-observed]]). That is
what makes [[dead-letter-queue]] possible at all.

**If a fetch by that sequence returns nothing, suspect the version.** `nats-server` 2.12.3 and 2.12.4
**lost** max-delivered messages on R3 WorkQueue streams — issue #7817, fixed by PR #7845 and shipped
in **2.12.5** (source: [[s-gh-7590-dlq-payload-loss]]).

## MQTT has its own `ack_wait` and `max_ack_pending`

They are unrelated to a [[consumer]]'s, live in the `mqtt {}` block, and govern MQTT QoS 1 and 2
redelivery rather than JetStream acks (source: [[s-docs-mqtt-qos-sessions-and-retained]]). The shape
is familiar and the numbers are not: `ack_wait` defaults to **30s**, `max_ack_pending` to **1024** with
`0` meaning "use the default", and a redelivered MQTT message is flagged as a duplicate.

The one that has no JetStream analogue is the **per-session ceiling**: 65535 in flight across all of a
session's subscriptions, so at the default a session holds 63 subscriptions — or 31 if they end in
`#`, which cost two apiece. Over it, the subscription is refused with `0x80` in the SUBACK rather than
failing later. See [[mqtt]].

A change to either applies only to subscriptions created **after** it, which is the same
create-time-only rule a consumer's `ack_wait` follows.

## What a leader move does to un-acked messages

A connection-level reconnect or drain does **not** ack anything: a consumer's position is this page's
bookkeeping, not the connection's. Measured on 2.14.6 (source:
[[s-nats-server-client-lifecycle-observed]], run E9): ten messages were fetched with `--no-ack`, then
the consumer leader's node was stopped.

- 35 seconds later — past the 30 s `ack_wait` — the **new** leader still reported `ack_pending 10`,
  `ack_floor` unmoved, and `num_redelivered 0`.
- The next fetch returned those same ten **stream** sequences with **`tries: 2`**, under new
  *consumer* sequences, and then continued at `tries: 1`.

Nothing was lost, the un-acked work came back as an ordinary redelivery, and `num_redelivered` had
not yet counted it — so a dashboard reading that field just after a leader move under-reports.
The client's side of the same event is on [[client-connection-lifecycle]].


## Related

[[consumer]] · [[stream]] · [[retention-policies]] · [[worker-pool]] · [[advisories]] ·
[[consumer-keeps-redelivering]]

## Sources

[[s-docs-delivery-and-acknowledgment]] · [[s-docs-acknowledgment]] · [[s-docs-pull-consumers]] ·
[[s-docs-consumer-config]] · [[s-docs-policies]] · [[s-nats-server-constants-2.14.6]] ·
[[s-docs-mqtt-qos-sessions-and-retained]] ·
[[s-docs-monitoring-advisories-and-events]] ·
[[s-docs-worker-pool]] · [[s-gh-6350-exponential-backoff]] · [[s-gh-4972-nak-with-delay-blocks]] · [[s-gh-6628-ackwait-vs-dupe-window]] · [[s-nats-server-nak-backoff-observed]] · [[s-synadia-reliable-delivery-dlq]] · [[s-gh-5631-nak-not-immediate]] · [[s-docs-acknowledgment]] · [[s-gh-4994-scale-to-zero-dlq]] · [[s-gh-7590-dlq-payload-loss]] · [[s-so-78603662-acked-but-redelivered]] · [[s-nats-server-redelivery-observed]] · [[s-issue-6921-last-per-subject-acks]] · [[s-relnotes-2.11.2]] · [[s-relnotes-2.14.1]] · [[s-relnotes-2.10]] · [[s-relnotes-2.14]] · [[s-nats-server-client-lifecycle-observed]]
