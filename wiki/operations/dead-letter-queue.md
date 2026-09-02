---
title: Dead-letter queue
type: operation
kind: pattern
area: [jetstream]
verified-against: nats-server 2.14.6
verified-on: 2026-09-01
tags: [dead-letter, dlq, max_deliver, advisories, term, replay, direct-get]
aliases: [DLQ, dead letter, dead-lettering, poison message queue]
sources: [s-gh-4994-scale-to-zero-dlq, s-gh-7590-dlq-payload-loss, s-synadia-reliable-delivery-dlq, s-nats-server-nak-backoff-observed, s-docs-monitoring-advisories-and-events, s-relnotes-2.14.1]
created: 2026-09-01
updated: 2026-09-03
---

# Dead-letter queue

**JetStream has no dead-letter queue, and that is deliberate.** There is no `dead_letter: true` on a
consumer. What it has instead are the parts you assemble one from — an advisory when a message runs
out of delivery attempts, a point read by sequence, and a stream to put the result in — and what you
end up with is an ordinary [[stream]] with replay, filtering and retention rather than an opaque
holding pen.

A maintainer, asked directly: *"We do not have automated DLQs… **by design since we truly separate
consumers from stream semantics.** … For DLQ, you could term a message and have something that
captures that advisory and moves the message to whichever stream you want"*
(source: [[s-gh-4994-scale-to-zero-dlq]], 2024-01-24).

## The problem

A message fails every time it is handled. `max_deliver` eventually stops the redelivery loop, and
then **nothing happens**: the message stays in the stream, the consumer moves on, and the only trace
is a single advisory published once to a subject nobody is necessarily listening to. An operator
learns that order `987` stopped being processed by noticing it is missing.

You want the failed messages somewhere durable, with their payloads, so they can be inspected, fixed
and replayed.

## The design

Three parts (source: [[s-synadia-reliable-delivery-dlq]]).

**1 · Capture the advisories into a stream.** They are published once and stored nowhere.

```
nats stream add DLQ_ADVISORIES \
  --subjects='$JS.EVENT.ADVISORY.CONSUMER.MAX_DELIVERIES.>' \
  --storage=file --replicas=3 --retention=limits --max-age=720h
```

Each captured message is the index entry for one failure:

```json
{"type":"io.nats.jetstream.advisory.v1.max_deliver","id":"TMbth7XzlJOkyzkRhNWQTR",
 "timestamp":"2026-09-01T02:36:13.790078Z","stream":"WQ","consumer":"w",
 "stream_seq":1,"deliveries":2}
```

**2 · Fetch the original by sequence.** The advisory names the source stream and the `stream_seq`, so
a [[direct-get|direct get]] returns the message itself — payload and headers.

**3 · Republish it to a dead-letter subject held by its own stream**, partitioned by where it came
from:

```
nats stream add DLQ --subjects='dlq.>' --storage=file --replicas=3 --retention=limits
```

Failed messages land on `dlq.<stream>.<consumer>`, "subject-partitioned so you can inspect or replay
a single failing consumer's backlog without touching the rest".

**The handler is itself an ordinary consumer** on `DLQ_ADVISORIES`, and answers like one: if it
cannot reach the source stream it **naks** and retries the advisory later; if the advisory is
malformed it **terms**.

**Add the term advisory too if you use term.** A handler that knows a message can never succeed
should term it rather than burn deliveries; that path publishes
`$JS.EVENT.ADVISORY.CONSUMER.MSG_TERMINATED.<stream>.<consumer>` instead, and a DLQ that only
captures `MAX_DELIVERIES` will miss every one of them ([[ack-and-redelivery]], [[advisories]]).

## The configuration that implements it

```
# 1 · the index
nats stream add DLQ_ADVISORIES --storage=file --replicas=3 --retention=limits --max-age=720h \
  --subjects='$JS.EVENT.ADVISORY.CONSUMER.MAX_DELIVERIES.>,$JS.EVENT.ADVISORY.CONSUMER.MSG_TERMINATED.>'

# 2 · the destination
nats stream add DLQ --subjects='dlq.>' --storage=file --replicas=3 --retention=limits

# 3 · the handler's consumer
nats consumer add DLQ_ADVISORIES mover --pull --ack=explicit --max-deliver=10 --wait=30s \
  --backoff=linear --backoff-steps=5 --backoff-min=1s --backoff-max=60s

# 4 · the source stream must answer a point read
nats stream edit ORDERS --allow-direct
```

The handler loop, in prose because it is four calls: pull an advisory → parse `stream` and
`stream_seq` → direct-get that sequence from that stream → publish the payload and headers to
`dlq.<stream>.<consumer>` → ack the advisory.

**Set `--backoff-min` deliberately on the handler.** The first backoff entry *becomes* the consumer's
`ack_wait` — the server overwrites it — so a small `--backoff-min` silently gives the handler a very
short ack deadline ([[ack-and-redelivery]]).

## Trade-offs and costs

- **The advisory carries no payload, and it never will.** The proposal to add one has been considered
  and resisted: *"quite a lot of user feedback that this is a bad idea due to the payloads potentially
  being sensitive and DLQ advisories going to different locations outside of nats"* — with a per
  consumer opt-in named as the only shape that might work, and no plan
  (source: [[s-gh-7590-dlq-payload-loss]]). Design for the two-step fetch.
- **Two streams, one consumer and a service to run.** That is the real cost against a broker with a
  config flag.
- **What you get back is a stream.** Reading the dead letters is another consumer, replaying them is
  a publish, and auditing them is `nats stream view` — not a special API.

## Pitfalls

Ranked by how often they are the answer.

1. **With nobody fetching, nothing is ever dead-lettered.** `ack_wait` expiring does **not** by itself
   advance a pull consumer's delivery count — the redelivery, and therefore the max-deliveries
   advisory, requires a client to ask for messages. Scale a worker pool to zero and the messages sit
   in `AckPending` indefinitely: no advisory, no DLQ entry, and a queue that looks healthy. Confirmed
   as by design, and the asker found no way to trigger it manually: *"There appears to be no way to
   configure JetStream to eagerly move messages from pending to the dead letter queue upon `AckWait`
   timeout, without clients issuing fetches"* (source: [[s-gh-4994-scale-to-zero-dlq]]). The same
   holds for a push consumer with an empty queue group.
2. **Retention can delete the message before the handler reads it.** On `workqueue` and `interest`
   streams the window between the advisory and the direct get "is bounded by consumer behavior".
   **Copy the payload into the DLQ stream at capture time**; do not store a reference and fetch later
   (source: [[s-synadia-reliable-delivery-dlq]]). On `limits` retention the message survives
   independently of acks, which is the friendly case.
3. **A max-delivered message *does* survive, at 2.14.6.** Measured on both `workqueue` and `limits`
   streams: the advisory fires, the message stays, and the advisory's `stream_seq` fetches it
   (source: [[s-nats-server-nak-backoff-observed]]). If a fetch returns `message not found`, suspect
   the version before the design — **`nats-server` 2.12.3 and 2.12.4 lost max-delivered messages on
   R3 WorkQueue streams**, fixed by PR #7845 and shipped in **2.12.5**: "Ensure that messages that
   have reached the max deliver state are preserved with the WorkQueue retention policy".
4. **`max_deliver` defaults to `-1`.** A consumer that never bounds its deliveries never produces a
   max-deliveries advisory, so the DLQ stays empty forever while messages retry endlessly
   ([[ack-and-redelivery]]).
5. **The advisory subject is easy to get wrong.** It is
   `$JS.EVENT.ADVISORY.CONSUMER.MAX_DELIVERIES.<stream>.<consumer>` — the docs' own diagram drops the
   `.CONSUMER.` token, and a stream whose subject matches nothing captures nothing, silently
   ([[advisories]], `inbox/docs-issues.md` #36).
6. **The DLQ stream needs its own limits.** It is a stream like any other; without `max_age` or
   `max_bytes` a persistent failure fills a disk with copies of the same bad message
   ([[jetstream-sizing]]).
7. **`allow_direct` must be on the source stream** for step 2, or the handler falls back to creating a
   consumer per fetch ([[direct-get]]).

### A version note: `max_deliver` accounting before 2.14.1

The pattern rests on the server's own count of deliveries. **2.14.1** (2026-05-20) fixed "a number of
paths that could leave consumer redelivered in a drifted state … with workqueue or interest-based
streams with `max_deliver`, on single message removal or after purges/compactions (#8102)" and
"Pending state no longer leaks when reaching max deliveries (#8156)" (source: [[s-relnotes-2.14.1]]).
On 2.14.0 the advisory and the drop happened as designed; the consumer's pending and redelivered
numbers could disagree with them. The measured behaviour on this page is from 2.14.6.


## When *not* to use it

- **When term is the whole answer.** If the handler can recognise a poison message, terming it and
  capturing the term advisory is simpler than a delivery-budget race — and it is the path the
  maintainer named first.
- **When the failure is transient.** A retry policy belongs on the consumer
  ([[ack-and-redelivery]]) or, for anything with a long delay, on [[message-scheduling]] — a dead
  letter is for work that has stopped, not for work that is waiting.
- **When you only need to know.** If nobody will replay the messages, a subscription to the advisory
  subject feeding an alert is the whole requirement, and the two streams are overhead.

## Verify

```
nats stream info DLQ_ADVISORIES          # is the index growing?
nats consumer info DLQ_ADVISORIES mover  # is the handler keeping up? num_pending should sit near 0
nats stream view DLQ                     # the failed messages, with their payloads
nats sub '$JS.EVENT.ADVISORY.CONSUMER.MAX_DELIVERIES.>'
```

To prove the whole path end to end, force a failure: a consumer with `--max-deliver=2 --wait=2s`, one
message, fetched twice with `--no-ack`. The advisory arrives about `2 × ack_wait` later, and the
message must appear on `dlq.<stream>.<consumer>` with its original body.

## Related

[[ack-and-redelivery]] · [[advisories]] · [[retention-policies]] · [[direct-get]] · [[consumer]] ·
[[worker-pool]] · [[message-scheduling]] · [[stream]] · [[jetstream-sizing]]

## Sources

[[s-gh-4994-scale-to-zero-dlq]] · [[s-gh-7590-dlq-payload-loss]] ·
[[s-synadia-reliable-delivery-dlq]] · [[s-nats-server-nak-backoff-observed]] ·
[[s-docs-monitoring-advisories-and-events]] · [[s-relnotes-2.14.1]]
