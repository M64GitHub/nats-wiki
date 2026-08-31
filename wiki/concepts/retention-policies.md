---
title: Retention policies
type: concept
area: [jetstream]
verified-against: nats-server 2.14
verified-on: 2026-08-31
tags: [retention, limits, interest, workqueue]
aliases: [retention, WorkQueue, Interest, Limits, retention policy]
sources: [s-docs-retention-policies, s-docs-policies, s-docs-stream-config, s-adr-60-reliable-sourcing, s-adr-59-sourcing-and-mirroring]
created: 2026-08-31
updated: 2026-08-31
---

# Retention policies

A [[stream]]'s `retention` field decides **who gets to say a message is finished**. Limits say it
when the stream runs out of room; Interest says it when every interested [[consumer]] has acked;
WorkQueue says it when the first consumer acks. There are exactly three values and, for practical
purposes, the choice is permanent.

## How it behaves

| value | a message leaves when… | fits |
|---|---|---|
| **`limits`** (default) | `max_msgs`, `max_bytes` or `max_age` removes it, whichever comes first. Consumers reading and acking has **no effect** on what the stream keeps | an audit log or event history you want to replay from any point |
| **`interest`** | **every** consumer whose filter covers it has acked it. A message published on a subject **no consumer is interested in is dropped immediately** | a fan-out where every consumer must process each message, without an ever-growing log |
| **`workqueue`** | **one** consumer acks it — the first ack removes it for everyone | a job queue where each message is work for exactly one worker |

**Limits still apply under all three.** Retention removes a message when consumers are done with
it; the stream's limits remove it when the stream grows too old or too large. On an `interest` or
`workqueue` stream the limits are the **backstop** that keeps the stream bounded when consumers fall
behind — retention does not replace limits, it adds a second way a message can leave
(source: [[s-docs-retention-policies]]).

## What configures it

`retention` on the stream, default `limits` (source: [[s-docs-stream-config]]). The `nats` CLI
takes `--retention`, and `natscli` accepts both `work` and `workq` as aliases for `workqueue`:

```
nats stream add FULFILLMENT --subjects "fulfill.>" --retention work --defaults
```

`nats stream info` reports it in the `Options` block as `Retention: WorkQueue` / `Retention: Limits`.

## What you cannot change later

Treat retention as **fixed at creation**. The server allows exactly one live change — `limits` ↔
`interest`, in either direction — and refuses anything involving `workqueue`:

```
stream configuration update can not change retention policy to/from workqueue
```

A stream that is not WorkQueue at creation can never become one, and a WorkQueue stream can never
change to another policy (source: [[s-docs-retention-policies]]).

**Even the allowed swap rewrites history.** Switch a `limits` stream to `interest` and from that
moment the server removes any message every consumer has already acked, and any message on a
subject no consumer is interested in — including history you meant to keep.

The migration path is a **new stream with the right policy**, then move the data — not an edit.

## Limits and failure modes

**Interest can fill the disk.** A message is removed only when every consumer whose filter covers it
has acked it, so a single stalled consumer (a stuck worker, a service that is down) holds up cleanup
for every message it still owes an ack on. The stream grows until it hits its limits or runs out of
room. Interest retention **still needs limits set**, and it makes consumer-health monitoring more
important than on a `limits` stream (source: [[s-docs-retention-policies]]). See
[[jetstream-out-of-disk]].

**WorkQueue rejects consumers that overlap.** Because the first ack removes a message for everyone,
the server will not let two consumers claim the same message, and it refuses the create rather than
letting it happen at runtime:

| attempt | error |
|---|---|
| a second **unfiltered** consumer | `multiple non-filtered consumers not allowed on workqueue stream` (**10099**) |
| two consumers whose **filters overlap** | `filtered consumer not unique on workqueue stream` (**10100**) |

A wildcard filter such as `fulfill.>` overlaps `fulfill.us` and `fulfill.eu` and is rejected. Two
valid shapes exist (source: [[s-docs-retention-policies]]):

- **Partition the subjects** — one consumer per non-overlapping filter. Each then handles only its
  slice; none sees the whole stream.
- **A worker pool sharing one consumer** — the way to scale a single workload. See [[worker-pool]].

For several consumers that each see *every* message, use `interest` or `limits` instead.

```
nats consumer add FULFILLMENT us-shippers --pull --ack explicit --filter "fulfill.us" --defaults
nats consumer add FULFILLMENT eu-shippers --pull --ack explicit --filter "fulfill.eu" --defaults
```

**A term removes the message too.** On a `workqueue` or `interest` stream, a client answering
**term** removes the message exactly as an ack would — the work never happened but the message is
gone. On a `limits` stream it only clears the consumer's pending entry (source:
[[s-docs-acknowledgment]]). See [[ack-and-redelivery]].

## Sourcing and mirroring from a WorkQueue or Interest stream

**Supported since nats-server 2.14** (source: [[s-relnotes-2.14.0]], [[s-docs-upgrade-to-2.14]]).
The server does it by **automatically using a durable consumer rather than an ephemeral one**, with
a new ack policy **`AckFlowControl`** that acknowledges messages after they are persisted, based on
flow control, and by using the consumer reset API where necessary (ADR-60).

Two consequences during a version change:

- **On a rolling upgrade or downgrade** this warning is expected and clears when every server is on
  the same version — an upgraded server tried the new-style sourcing consumer against an older
  peer and retried automatically with the old style:

  ```
  [WRN] Invalid JetStream request '$G > $JS.API.CONSUMER.CREATE.O': json: unknown field "sourcing"
  ```

- **On a downgrade below 2.14**, sourcing or mirroring started on 2.14 "will still seem to function
  but will operate under the less reliable ephemeral consumer mode", and any durable consumers
  created with `AckFlowControl` are **marked "offline" and unusable until upgraded back to 2.14**.

### What the durable replication consumer looks like

ADR-60 is the spec behind that change, and it names things an operator will meet in
`nats consumer ls` (source: [[s-adr-60-reliable-sourcing]]):

- The consumer is **visible**, named `JS_MIRROR_<suffix>` or `JS_SRC_<suffix>`, and carries metadata
  `_nats.mirror.stream` / `_nats.src.stream` (plus `.acc`, and `.domain` when set) naming the stream
  that created it. For a Limits upstream the replication consumer stays hidden instead.
- **Removing the source removes it only on a best-effort basis** — a leftover `JS_SRC_*` after a
  config change is yours to delete.
- `AckFlowControl` behaves like `AckAll`, driven by `Nats-Last-Stream` / `Nats-Last-Consumer`
  headers on the flow-control replies; such a consumer must have `AckWait` and `BackOff` **unset**
  and `MaxDeliver: -1`.
- The upstream server must be at **API level 4** — the request carries
  `Nats-Required-Api-Level: 4` (`stream.go:3679`, 2.14.6).
- On a **WorkQueue** upstream the durable consumer still obeys the overlap rule: it blocks any other
  consumer with an overlapping filter. A queue that must be both worked and replicated should be an
  `interest` stream instead.

Why it was needed at all, from ADR-59: on a WorkQueue the old replication consumer was a `Direct`
consumer that **bypassed the subject-overlap check** and could silently double-consume a partition;
on an `interest` stream its 10s inactive threshold meant a longer outage left nobody holding
interest, and new messages were removed before they could be copied
(source: [[s-adr-59-sourcing-and-mirroring]]).


## To verify

- How `interest` and `workqueue` interact with stream **republish** is referenced by the docs but
  not covered by any source ingested so far.

## Related

[[stream]] · [[consumer]] · [[ack-and-redelivery]] · [[worker-pool]] · [[jetstream-out-of-disk]] ·
[[error-codes]]

## Sources

[[s-docs-retention-policies]] · [[s-docs-policies]] · [[s-docs-stream-config]] ·
[[s-docs-acknowledgment]] · [[s-adr-60-reliable-sourcing]] · [[s-adr-59-sourcing-and-mirroring]]
