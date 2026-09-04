---
title: Retention policies
type: concept
area: [jetstream]
since: [2.10]   # present at 2.10, the oldest line this wiki covers; not the arrival
verified-against: nats-server 2.14
verified-on: 2026-08-31
tags: [retention, limits, interest, workqueue]
aliases: [retention, WorkQueue, Interest, Limits, retention policy]
sources: [s-docs-retention-policies, s-docs-policies, s-docs-stream-config, s-adr-60-reliable-sourcing, s-adr-59-sourcing-and-mirroring, s-adr-10-extended-purge, s-docs-acknowledgment, s-docs-filtering, s-docs-shaping-the-stream, s-docs-altering-stream-state, s-docs-worker-pool, s-adr-7-server-error-codes, s-synadia-reliable-delivery-dlq, s-adr-51-message-scheduler, s-gh-7590-dlq-payload-loss, s-gh-7032-max-msgs-known-good, s-relnotes-2.10, s-relnotes-2.11, s-relnotes-2.12, s-relnotes-2.14, s-nats-server-stream-consumer-config, s-nats-server-config-mutability-observed, s-gh-4499-workqueue-fanout-retention, s-gh-6571-source-mirror-or-one-stream, s-gh-6100-stream-per-subject-or-one]
created: 2026-08-31
updated: 2026-09-04
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

**On `limits` and `interest`, an ack advances a position; it does not remove a message.** This is the
sentence that makes the table above make sense, and the docs state it while explaining a worker pool:
"the workers share a *position*, not the messages" — the acknowledgment floor advances the same
whether one process pulls or three, "so `billing` and `analytics` still see every order"
(source: [[s-docs-worker-pool]]). `workqueue` is the exception that inverts it: there the first ack
removes the message for everyone, which is why the server refuses overlapping consumers rather than
letting two of them race for the same work (below). Splitting work across a *stream* rather than a
core NATS queue group is what survives a worker dying — a queue-group subscriber that is offline when
a message arrives "misses it for good", where a worker on a consumer "just leaves its share for the
others": "**only the stream-backed split survives a worker dropping out or a restart**". See
[[worker-pool]] and [[ack-and-redelivery]].

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
important than on a `limits` stream (source: [[s-docs-retention-policies]]). The limits themselves —
the three ceilings, which one wins, and why `discard` does not govern `max_age` — are on [[stream]]
(source: [[s-docs-shaping-the-stream]]). See
[[jetstream-out-of-disk]].

**WorkQueue rejects consumers that overlap.** Because the first ack removes a message for everyone,
the server will not let two consumers claim the same message, and it refuses the create rather than
letting it happen at runtime:

| attempt | error |
|---|---|
| a second **unfiltered** consumer | `multiple non-filtered consumers not allowed on workqueue stream` (**10099**) |
| two consumers whose **filters overlap** | `filtered consumer not unique on workqueue stream` (**10100**) |

The `learn` chapter states the same rule from the consumer's side, and draws the contrast that makes
it memorable: overlap *between* consumers is not merely allowed on `limits` and `interest` streams,
it is the point — "two separate consumers whose filters match the same subject each get their own
full copy of those messages". **Work-queue retention is the one exception**
(source: [[s-docs-filtering]]).

**Match on the numbers, not on those strings.** `10099` and `10100` are the contract; the
`description` beside them is not, and the canonical list is generated from `server/errors.json`
rather than written by hand (source: [[s-adr-7-server-error-codes]]; the mechanics are on
[[js-api]] and every code is in [[error-codes]]).

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

**`discard: new` stops the world when a limit is reached.** Every publish is refused with
`10077 maximum messages exceeded` (or `... bytes`, or `... messages per subject`) until something
removes messages, and **the server logs nothing about it** at the default level — the refusal reaches
only the publisher, in its `PubAck`. This is the intended behaviour of the policy, and it is the
most common way a healthy-looking cluster stops accepting writes: see
[[maximum-messages-exceeded]] for the triage and the four ways out.

The immediate way out is a purge, which takes three shapes — keep the newest *N*, drop one subject,
or drop everything below a sequence (source: [[s-adr-10-extended-purge]]):

```
nats stream purge ORDERS --keep=1000
nats stream purge ORDERS --subject='orders.eu.>'
nats stream purge ORDERS --seq=45000
```

A purge does not renumber the stream — it "sets the stream's first sequence to one past its last",
so the next publish continues from there rather than from `1`
(source: [[s-docs-altering-stream-state]]; see *Sequences are addresses* on [[stream]]) — and
`--seq` and `--keep` cannot be combined (the server answers `10003 bad request`). On a `workqueue` stream a purge throws away unprocessed work — fix the
consumers first.


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


## Retention decides whether a failed message can still be recovered

A message that exhausts `max_deliver` produces an advisory naming its stream sequence, and anything
that wants to recover it — a dead-letter handler, an operator with `nats stream get` — has to fetch
it **while it still exists**. Which retention policy the stream uses decides how long that window is
(source: [[s-synadia-reliable-delivery-dlq]]):

| retention | is the failed message still there? |
|---|---|
| `limits` | **yes**, independently of acks — "the friendliest case", bounded only by the stream's own age/size/count limits |
| `workqueue` | **only briefly.** The message is removed once it is terminally acknowledged, and exhausting `max_deliver` is itself the end of the road |
| `interest` | **only briefly**, and the window "is bounded by consumer behavior" rather than by a limit you set |

The rule the source gives: *"on any retention policy that removes messages once they are terminally
handled, capture the payload while it still exists."* A recovery design built over a `workqueue`
stream must copy the message at capture time rather than store a reference to it — see
[[advisories]] and [[direct-get]] for the two halves of that fetch, and [[ack-and-redelivery]] for
what happens when the delivery budget runs out.


## Retention decides whether a scheduled message ever fires

A [[message-scheduling|message schedule]] is an ordinary message that happens to carry
`Nats-Schedule` headers, so this page's rules govern its survival — and a schedule that is removed
stops firing, silently. "Once a schedule message is removed from storage, by any mechanism, its
schedule stops firing" (source: [[s-adr-51-message-scheduler]]).

| policy | what it does to a schedule |
|---|---|
| **`limits`** | the recommended choice. But `max_age` shorter than the firing interval deletes the schedule *before* it fires — prefer a `Nats-TTL` on the schedule itself — and `discard: old` under `max_msgs`/`max_bytes` can evict it the same way |
| **`workqueue`** | works only while nothing acks the schedule. A consumer filtered on the schedule subject **permanently stops the schedule on ack** — which can be used as a cancel, though it is a race, since "message deletion as a result of acknowledgement isn't immediate" |
| **`interest`** | "if no consumer has interest in the schedule subject, the schedule will not be stored, nor will it trigger scheduled messages" — the schedule never even lands |

**The two-stream composition for `interest` retention** is the ADR's recommended shape and is worth
knowing as a general pattern here: put the schedules in a dedicated **`workqueue`** stream (with
`allow_msg_schedules` and subjects covering both the schedule and target patterns) and have the
`interest` stream **source** the target subjects from it. Schedules never leave the workqueue stream,
where nothing removes them so long as no consumer acks them.

The alternative — a **pinning consumer** on the interest stream whose filter covers the schedule
subjects, with `ack_policy: none`, purely to hold interest — works but is not recommended: "the
pinning consumer becomes load-bearing configuration: if it is deleted or its filter drifts, schedules
silently stop", and it costs overhead when replicated.

Note the asymmetry that makes the two-stream shape legal at all: `allow_msg_schedules` goes on the
**source** stream only, because a stream that has sources configured cannot set it
([[mirrors-and-sources]]).


### A message that exhausts `max_deliver` is not removed by any policy

Reaching the delivery limit is not an acknowledgement, so it does not satisfy `workqueue` or
`interest` retention. Measured at v2.14.6 on both `workqueue` and `limits` streams: the message stays
stored and is fetchable by the sequence the max-deliveries advisory names
(source: [[s-nats-server-nak-backoff-observed]]). What stops is delivery to that consumer, not
storage.

**There was a defect that made this look otherwise.** On **2.12.3 and 2.12.4**, R3 `workqueue` streams
**lost** max-delivered messages — `nats-io/nats-server` issue #7817, fixed by PR #7845 and shipped in
**2.12.5** ("Ensure that messages that have reached the max deliver state are preserved with the
WorkQueue retention policy") (source: [[s-gh-7590-dlq-payload-loss]]). A `message not found` when
fetching a dead-lettered sequence on those versions is that bug, not this policy.

What *does* still bound the window is ordinary retention: on `workqueue` and `interest`, any consumer
that acks the message removes it, so a [[dead-letter-queue]] handler is racing whatever else is
attached to the stream.


## Version notes

**Since.** `since: [2.10]` in the frontmatter means *present at 2.10, the oldest line this wiki covers*:
the 2.10 release bodies patch the three retention policies from v2.10.0 on and none records the arrival, which is
older than the archive (source: [[s-relnotes-2.10]]).

- **The `limits` → `interest` swap is since 2.10.0**: "Allow switching between limits and interest
  retention policies" (#4361; the PR is "Allow switching from limits-based to interest-based
  retention in stream update") (source: [[s-relnotes-2.10]]).
- Fixes that changed what `interest` and `workqueue` actually removed: 2.10.14 — interest and
  WorkQueue state tracking "to prevent stranded messages during concurrent consumer acks and stream
  deletes" (#5270); 2.10.16 — messages removed after consumer updates and interest changes on
  interest streams (#5384, #5385); 2.10.19 — WorkQueue messages "incorrectly removed … when consumers
  did not cover the entire subject space" (#5697), and the correct sequence returned for a duplicate
  on an interest stream with no interest (#5818); 2.10.26 — consumers skipping messages on interest
  or WorkQueue streams (#6526); 2.10.28 — sequence numbers lost on interruption, "particularly
  noticeable with WQ or interest retention policies" (#6778).


### The 2.11 line

- **2.11.0**: on clustered `interest` and `workqueue` streams, message removals by ack "are now
  proposed through Raft" — "ensures that the removal ordering across all replicas is consistent, but
  may increase the amount of replication traffic" (#6140) (source: [[s-relnotes-2.11]]).
- **2.11.5**: "Stream retention policy changes are now correctly propagated to running consumers in
  all cases" (#6995).
- **2.11.12** sharpens *Even the allowed swap rewrites history*: "Switching to interest-based
  retention will now remove no-interest messages from the head of the stream" (#7766) — on 2.11.12
  and later the removal is immediate, not deferred to the next ack.


### The 2.12 line

- **2.12.3**: `discard_new_per_subject` enforced by the leader before proposing (#7607) (source:
  [[s-relnotes-2.12]]). **2.12.4**: the interest-switch head removal (#7766, as 2.11.12).
- **2.12.5**: "messages that have reached the max deliver state are preserved with the WorkQueue
  retention policy" (#7845). **2.12.8**: "message roll-ups are now applied on interest-based streams
  where there is no interest over the subjects" (#8019). **2.12.12**: a catch-up is no longer
  skipped when limits are exceeded, "preventing possible stream desync" (#8265).


## To verify

- How `interest` and `workqueue` interact with stream **republish** is referenced by the docs but
  not covered by any source ingested so far.

## A limits stream with no limits: the event-store shape

Asked for the largest safe `max_msgs` on a `limits` stream meant to keep everything forever (~100 B
events, ~5 M a year, R3), a maintainer's answer was that there is none: leave the limits off, expect
disk and the per-subject index in RAM to be what eventually bounds it, and when they do, **shard by
time** — one stream per year or decade — rather than discard; replay from the start with an ordered
consumer (source: [[s-gh-7032-max-msgs-known-good]]; the arithmetic is on [[jetstream-sizing]],
the no-cap statement on [[stream]]).


### The 2.14 line

- **2.14.0**: **sourcing and mirroring from a WorkQueue or Interest stream is supported** — the server
  "automatically upgrades to a durable consumer with `AckFlowControl` policy and uses consumer reset
  where necessary" (#7613); rollups are allowed once a stream hits `discard_new_per_subject` (#7974)
  (source: [[s-relnotes-2.14]]).
- **2.14.1**: on a clustered WorkQueue stream the delivery policy is enforced correctly (#8126); the
  redelivered-state drift "with workqueue or interest-based streams with `max_deliver`" fixed (#8102).
  **2.14.3**: a catch-up is no longer skipped when limits are exceeded (#8265). **2.14.6**:
  `AckFlowControl` consumers sourcing a WorkQueue stream no longer ack messages outside their filter
  (#8431, #8528) — before it, a filtered source could consume messages it never copied.


## Changing `retention` on a live stream

`limits` ↔ `interest` is allowed and was accepted on 2.14.6; **to or from `workqueue` is refused**
with `stream configuration update can not change retention policy to/from workqueue`
(`configUpdateCheck`, `stream.go:2318–2322`), and a counter stream may only be `limits`. A pull
consumer on a workqueue stream must use `ack_policy: explicit` (10084). The field table is
[[stream-and-consumer-config]] (source: [[s-nats-server-stream-consumer-config]],
[[s-nats-server-config-mutability-observed]]).


## The exclusion rule, and how an operator actually meets it

The three policies are usually presented as a choice. In public they are almost never chosen — they
are discovered, on the second consumer, as an error:

```
nats: error: Consumer creation failed: filtered consumer not unique on workqueue stream (10100)
```

That is gh#4499: a fan-out design — several independent applications, each of which must see **every**
message, several instances of each sharing the work — built on a `--retention=work` stream. The first
durable consumer on `EVENTS.*` is created; the second is refused (source:
[[s-gh-4499-workqueue-fanout-retention]]). The maintainer's answer is the rule this section exists for:

> "Then dont use WorkQueue. WorkQueue is designed for any message being processed succesfully once
> only. **Use Interest or limits.** With those messages will distribute within multiple instances of
> teh same App (they would share a consumer) and multiple apps all get all the messages (each app is a
> consumer)." — @ripienaar, 2023-09-07

**So the first question is not "which of three" but "how many independent readers does this message
have".** One reader — WorkQueue is available. More than one — WorkQueue is excluded before anything
else is considered, because there is no legal way to express it. And the two axes are separate:

- **instances of one application share one consumer** — that is how work is distributed
  ([[worker-pool]]);
- **different applications get their own consumer** — that is how a message is seen twice, and it is
  what `interest` and `limits` allow and `workqueue` forbids.

The asker's first diagnosis was that the filter string was wrong. It was not; the *retention* was. Two
weeks later: "I'm now using `limits` policy and it work as expected."

### Do not split a stream to keep it small

The other half of the same mistake is reaching for a second stream to protect the first. gh#6571 asks
exactly that — a WorkQueue stream for a fast consumer plus a Limits **mirror** for a slow analytics
one, against one Limits stream with both consumers on it — and the answer rejects the premise (source:
[[s-gh-6571-source-mirror-or-one-stream]]):

> "It's not because a stream is larger that delivery of messages to consumers takes longer, therefore
> approach 2 is simpler, more efficient and doesn't have the Cons you list." — @jnmoyne, 2025-03-02

Asked what a large stream *does* cost, the same answer names one thing: "Mostly increased memory usage
if you have a lot of different subject being used in the stream (the servers maintain per subject
indexing)" — a **subject cardinality** cost ([[subjects-and-wildcards]]), not a message-count one.

A fast consumer and a slow consumer on one stream is the supported shape: consumers are independent
cursors and the slow one does not hold the fast one back. What a slow consumer *does* hold, under
`interest` or `workqueue`, is the data itself — which is the real reason that design needed `limits`.

### Retention is one of the few honest reasons to split a stream

Since retention is a stream property and cannot be changed for one subject, a subject that needs a
different policy needs its own stream. That is the single exception the maintainers make to "one
stream": "I would stick to one stream, **unless you need different retention policies for some
subjects** for example" (source: [[s-gh-6100-stream-per-subject-or-one]]). The same is true of
replication, storage backend and placement — and of nothing else. See [[stream]], *How many streams,
and what a second one costs*.


## Related

[[stream]] · [[consumer]] · [[ack-and-redelivery]] · [[worker-pool]] · [[jetstream-out-of-disk]] ·
[[error-codes]] · [[maximum-messages-exceeded]]

## Sources

[[s-docs-retention-policies]] · [[s-docs-policies]] · [[s-docs-stream-config]] ·
[[s-docs-acknowledgment]] · [[s-adr-60-reliable-sourcing]] · [[s-adr-59-sourcing-and-mirroring]] · [[s-adr-10-extended-purge]] · [[s-docs-filtering]] ·
[[s-docs-shaping-the-stream]] · [[s-docs-altering-stream-state]] ·
[[s-docs-worker-pool]] · [[s-adr-7-server-error-codes]] · [[s-synadia-reliable-delivery-dlq]] · [[s-adr-51-message-scheduler]] · [[s-gh-7590-dlq-payload-loss]] · [[s-gh-7032-max-msgs-known-good]] · [[s-relnotes-2.10]] · [[s-relnotes-2.11]] · [[s-relnotes-2.12]] · [[s-relnotes-2.14]] · [[s-nats-server-stream-consumer-config]] · [[s-nats-server-config-mutability-observed]] · [[s-gh-4499-workqueue-fanout-retention]] · [[s-gh-6571-source-mirror-or-one-stream]] · [[s-gh-6100-stream-per-subject-or-one]]
