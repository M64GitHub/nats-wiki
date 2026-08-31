---
title: Consumer
type: concept
area: [jetstream]
verified-against: nats-server 2.14.6
verified-on: 2026-08-31
tags: [consumer, pull, durable, max_ack_pending, deliver_policy]
aliases: [consumers, ConsumerConfig, durable, pull consumer]
sources: [s-docs-delivery-and-acknowledgment, s-docs-pull-consumers, s-docs-policies, s-docs-consumer-config, s-docs-acknowledgment, s-docs-surviving-node-loss, s-relnotes-2.14.0, s-docs-upgrade-to-2.14, s-synadia-jetstream-anti-patterns, s-nats-server-constants-2.14.6, s-adr-60-reliable-sourcing, s-nats-server-filestore-layout, s-docs-retention-policies, s-docs-reading-back, s-docs-filtering, s-docs-monitoring-jetstream-health]
created: 2026-08-31
updated: 2026-08-31
---

# Consumer

A consumer is a stateful cursor over a [[stream]]: it remembers how far a reader has got, which
messages are still waiting for an acknowledgement, and which subjects the reader cares about. A
stream can carry many consumers, each with an independent position over **one shared copy** of the
data — one consumer catching up never moves another's (source:
[[s-docs-delivery-and-acknowledgment]]).

## How it behaves

- The consumer hands a message to a reader, holds it **in flight** until the reader answers, and
  redelivers it if no answer arrives within `ack_wait`. That loop is [[ack-and-redelivery]].
- The **acknowledgment floor** is the highest *contiguous* acknowledged message
  (source: [[s-docs-consumer-config]]) — which is why acking out of order does not advance it, and
  why the gap between "last delivered" and "ack floor" is the in-flight set.
- A **durable** consumer keeps its position under a fixed name, so a reader can disconnect and pick
  up where it left off. Recreating a durable **loses the saved position**: the new consumer starts
  wherever its deliver policy says, not where the old one stopped (source: [[s-docs-policies]]).
- On a replicated stream a consumer has **its own RAFT group and its own leader**, which can sit on
  any of the stream's replicas — so delivery spreads across the replica servers instead of piling
  on the stream leader (source: [[s-docs-surviving-node-loss]]). See [[raft-in-nats]].

## Pull consumers: fetch and consume

A pull consumer delivers a message when a reader asks for one. Client libraries expose two
patterns over the same underlying pull request (source: [[s-docs-pull-consumers]]):

- **Fetch** — ask for a batch of up to *N* messages; the call returns when the batch is full or the
  timeout expires, whichever comes first. Fetch again to keep going.
- **Consume** — a continuous flow: the library keeps pull requests in flight in the background and
  calls a handler per message until you stop it. Most services use this.

Two fields bound a single pull:

| field | what it does |
|---|---|
| `batch` | maximum messages this pull may return. Bigger = fewer round trips, higher throughput. Smaller = lower per-message latency, less work lost if the worker dies mid-batch. |
| `expires` | how long the server holds the pull open before returning what it has. Bounds latency on a quiet stream. **`0` never times out**; client libraries default to about 30 seconds. |

`batch` counts **messages, not bytes**. Most clients also accept a `max_bytes` option; whichever
limit is hit first ends the pull.

An **empty fetch is normal**: with nothing queued and `expires` elapsed the server replies
`408 Request Timeout`; a *no-wait* fetch with no messages gets `404 No Messages`. Since **2.14** the
server also returns `404 No Messages` for a `no_wait` pull that sets **no expiry at all** when
nothing is pending (source: [[s-relnotes-2.14.0]]). Clients report
both as an empty batch and the CLI exits non-zero. Code that treats that as a failure fails on a
quiet stream.

## What configures it

Consumer defaults below are **not readable from the docs' consumer reference at all** — it renders
the `config` object as a collapsed schema node (source: [[s-docs-consumer-config]]; recorded as
issue 4 in `inbox/docs-issues.md`). They come from the learn pages, confirmed against the server at
**v2.14.6** (source: [[s-nats-server-constants-2.14.6]]).

| setting | CLI flag | default | source |
|---|---|---|---|
| `ack_policy` | `--ack` | `explicit` in the docs' walkthrough | [[s-docs-acknowledgment]] |
| `ack_wait` | `--wait` | `30s` — `consumer.go:573` | [[s-nats-server-constants-2.14.6]] |
| `max_deliver` | `--max-deliver` | `-1` (unlimited) — `consumer.go:589` | [[s-nats-server-constants-2.14.6]] |
| `max_ack_pending` | `--max-pending` | `1000` — `consumer.go:580` | [[s-nats-server-constants-2.14.6]] |
| `inactive_threshold` (ephemerals) | — | `5s` — `consumer.go:576` | [[s-nats-server-constants-2.14.6]] |
| `backoff` | `--backoff`, `--backoff-steps`, `--backoff-min`, `--backoff-max` | unset | [[s-docs-acknowledgment]] |
| `deliver_policy` | `--deliver` | `all` | [[s-docs-policies]] |
| `replay_policy` | — | `instant` | [[s-docs-policies]] |
| `filter_subject` | `--filter` | unset | [[s-docs-retention-policies]] |

**Deliver policy** decides where the consumer starts reading, **once, at creation**:
`all` (default, the stream's first message), `last` (the newest message, then live), `new` (only
messages that arrive after creation), `by_start_sequence` (`--deliver 1000`), `by_start_time`
(`--deliver 1h`), and `last_per_subject` (the newest message *for each subject* the consumer
matches — the basis of KV watches) (source: [[s-docs-policies]]).

**Replay policy**: `instant` (default) delivers as fast as the reader takes them; `original` spaces
deliveries to match the gaps between the original timestamps, so a long quiet stretch replays as a
long quiet wait (source: [[s-docs-policies]]).

**Priority policy**: `none` (default), `overflow`, `pinned_client`, `prioritized`. It *can* be
changed on a live consumer, but `nats consumer edit` has no flag for it — pass a config file with
`--config` (source: [[s-docs-policies]]).

**Ack policy**: `explicit`, `none`, `all`, `flow_control` — see [[ack-and-redelivery]].

### Resetting a consumer (2.14)

Since 2.14, **`$JS.API.CONSUMER.RESET.<stream>.<consumer>`** resets delivery state back to the
acknowledgement floor, or to an arbitrary sequence while still respecting start sequences —
**without deleting and recreating the consumer**. The state after a reset equals what a delete and
recreate at that sequence would produce (source: [[s-relnotes-2.14.0]]). That matters because
recreating a durable is otherwise the only way to move its position, and it loses the saved one.

The payload decides how far it goes: **empty** resets the delivery state but leaves the ack floor's
stream sequence alone, `{"seq":<n>}` moves that floor to one below `<n>`. It is allowed only on
`deliver_policy` `all`, `by_start_sequence` and `by_start_time` — and for the last two only forward
of what the start policy already allowed, so a reset cannot smuggle a consumer back past its own
start. The reply looks like a consumer-create response with the `ResetSeq` actually used, and a
client must tolerate its delivery sequence restarting at 1, because the caller may be the CLI or the
server rather than the client itself (source: [[s-adr-60-reliable-sourcing]] · [[s-docs-reading-back]] · [[s-docs-filtering]]).

Related: since 2.14, **invalid or divergent consumer state is reset to match the stream on
startup**, after an unclean shutdown.

### `AckFlowControl`, and consumers you did not create (2.14)

A fourth ack policy exists that no application sets: **`AckFlowControl`**, used by the durable
consumers the server creates to mirror or source a WorkQueue or Interest stream. It behaves like
`AckAll`, but the acknowledgement is carried by flow-control replies (headers `Nats-Last-Stream` and
`Nats-Last-Consumer`) rather than by ack messages, so the upstream only removes a message once the
destination has stored it. Such a consumer must have `ack_wait` and `backoff` **unset** and
`max_deliver: -1`, and the server enforces that.

The practical consequence is in `nats consumer ls`: a stream that is being mirrored or sourced grows
consumers named **`JS_MIRROR_<suffix>`** or **`JS_SRC_<suffix>`**, carrying metadata
`_nats.mirror.stream` / `_nats.src.stream` that names the stream which created them. They are not
yours to delete while the replication exists — and are yours to delete if it no longer does, because
their removal is best-effort ([[mirrors-and-sources]], source: [[s-adr-60-reliable-sourcing]] · [[s-docs-reading-back]] · [[s-docs-filtering]]).

### Fixed at creation

`deliver_policy`, `ack_policy` and `replay_policy` are **fixed at creation**. The server refuses
the update — for the start position, verbatim: `deliver policy can not be updated`. Recreating the
consumer is the only way to change them, and it loses the saved position
(source: [[s-docs-policies]]).

### Replicas

By default a durable consumer takes its stream's replica count. On a `limits` stream a consumer may
be given **fewer** replicas than its stream when its state is cheap to rebuild, but **never more**.
On `interest` and `workqueue` streams the consumer's replica count **must match** the stream's
(source: [[s-docs-surviving-node-loss]]). Consumer replicas buy failover, not throughput: one
consumer leader does all the work and the followers only stand by.

## Limits and failure modes

- **`max_ack_pending` below the batch size silently caps throughput.** With a limit of 10 against a
  batch of 100 the server delivers 10 and stops until the worker acks, however large a batch is
  asked for. Keep it at or above the batch size (source: [[s-docs-pull-consumers]]).
- **A worker pool shares one `max_ack_pending`** across every worker on the consumer, so the limit
  matters more, not less, as the pool grows (source: [[s-docs-pull-consumers]]). See
  [[worker-pool]].
- **Deliver policy `new` does not skip the backlog on every restart.** It applies once, at
  creation; a client that re-attaches to the durable resumes from its saved position, backlog
  included (source: [[s-docs-policies]]).
- **On a `workqueue` stream the server refuses overlapping consumers** — see
  [[retention-policies]]. Overlap *between* consumers is otherwise fine: on `limits` and `interest`
  streams "two separate consumers whose filters match the same subject each get their own full copy
  of those messages" (source: [[s-docs-filtering]]).
- **Overlap *inside* one consumer is an error with a quotable string.** A consumer may carry several
  filter subjects, but if one covers another — `orders.>` beside `orders.shipped` — the create call
  fails with `consumer subject filters cannot overlap`. Filters that only *partly* overlap, where
  neither covers the other, are accepted (source: [[s-docs-filtering]]).
- **A filter that matches nothing is accepted silently.** "There's no error and no warning, just an
  empty pull" — a typo like `orders.shiped` creates a perfectly valid consumer that never receives
  anything. When a pull comes back empty, check the `Filter Subject` line in `nats consumer info`
  against the stream's subjects before concluding the stream is empty. **No `Filter Subject` line at
  all means no filter**, i.e. every subject in the stream (source: [[s-docs-filtering]]).
- **A filter is a view, never a retention mechanism.** What a consumer skips is still stored and
  still readable by every other consumer (source: [[s-docs-filtering]]).
- **Reusing a durable name with a different config is refused**, not silently applied: the server
  returns `consumer already exists`. Use `nats consumer edit`, or a new name
  (source: [[s-docs-reading-back]]).
- **A pause with a deadline in the past does nothing.** Pause stores a fixed moment; if it has
  already passed "the server leaves the consumer running", and the CLI says so rather than acting as
  if the pause took. Pause with a duration (`1h`), which is always measured from now.
- **Pausing a consumer does not stop publishers.** Pause is a consumer setting and does not touch the
  stream: "new messages keep arriving… and they count toward the stream's storage limits. A long
  pause on a stream with a tight `MaxMsgs` or `MaxBytes` can drop the oldest orders before the
  consumer reads them" ([[stream]]). Size the stream for the longest pause you expect. (Both from
  `learn/jetstream/pausing.md`, spot-checked 2026-08-31; that page has not been ingested.)
- **Delivery policy sets where a consumer starts; `replay_policy` sets the pace once it is reading.**
  The default `instant` hands messages over as fast as the client takes them; `original` "spaces
  deliveries out to match the gaps between the messages' original timestamps", replaying recorded
  traffic at roughly its real speed — rarely what production wants
  (source: [[s-docs-reading-back]]).
- Two different features answer to "last per subject": the deliver policy `last_per_subject`
  (a standing view) and the Direct Get `--last-per-subject` flag (a one-shot read with no
  consumer). They are not the same feature (source: [[s-docs-policies]]).

## `consumer info` is a debugging tool, not a control-loop primitive

The call routes to the **meta leader** before it can return "does not exist", and when the consumer
does exist it **calculates state** — so it is expensive by construction, and expensive in a place
that is shared cluster-wide (source: [[s-synadia-jetstream-anti-patterns]]).

Two habits to avoid:

- **Checking whether a consumer exists before creating it.** Just call create: if a consumer of that
  name already exists on the stream, the server verifies the request against the existing config and
  the call is **idempotent**; if the config differs it **updates** the consumer, except where the
  change targets a non-editable field (a start sequence, say), which errors.
- **Polling for pending messages.** `NumPending` already rides on **every message the consumer
  delivers**, alongside `Sequence`, `NumDelivered`, `Timestamp`, `Stream`, `Consumer` and `Domain`.
  No API call is needed.

Both are cheap at prototype scale and expensive across tens of thousands of clients — see
[[jetstream-slows-as-consumers-grow]].

## What you can observe

`nats consumer info <stream> <consumer>` and the `ConsumerInfo` response of
`$JS.API.CONSUMER.CREATE.<stream>.<consumer>` expose (source: [[s-docs-consumer-config]]):

| field | meaning |
|---|---|
| `delivered` | the last message delivered from this consumer |
| `ack_floor` | the highest **contiguous** acknowledged message |
| `num_ack_pending` | messages pending acknowledgement (in flight) |
| `num_redelivered` | redeliveries performed |
| `num_waiting` | pull requests currently waiting for messages |
| `num_pending` | messages left unconsumed by this consumer |
| `cluster` | the consumer's RAFT group — leader and replicas |
| `push_bound` | whether a client is attached to a push consumer |
| `paused` / `pause_remaining` | whether the consumer is paused, and for how long |
| `priority_groups` | priority-group state |

The CLI renders the same three numbers as `Last Delivered`, `Acknowledgment Floor` and
`Outstanding Acks` (source: [[s-docs-delivery-and-acknowledgment]]).

### Two sequences, and why they drift

`Last Delivered Message` prints two numbers side by side, and they answer different questions
(source: [[s-docs-reading-back]]):

- **stream sequence** — the message's fixed position in the log, assigned at publish and never
  changed ([[stream]]);
- **consumer sequence** — this consumer's own counter, incremented on **every delivery, redeliveries
  included**. It counts deliveries, not distinct messages.

They agree only for a consumer that started at sequence 1, has no filter, and has never redelivered.
They drift for the three ordinary reasons: a consumer that starts partway through, one that filters
to a subset of subjects, and one that has had a message redelivered. **A consumer sequence running
ahead of the stream sequence is redelivery, not corruption.**

And the same rule as above applies to reading them: the state rides on every delivered message —
stream and consumer sequence, pending count, delivery count — "while `nats consumer info` is a
separate request to the server: fine for a one-off check, too costly to call for every message"
(source: [[s-docs-reading-back]]).

## Cheat sheet

```
nats consumer add ORDERS shipping --pull --ack explicit --defaults
nats consumer add FULFILLMENT us-shippers --pull --ack explicit --filter "fulfill.us" --defaults
nats consumer next ORDERS shipping --count 10 --wait 2s
nats consumer edit ORDERS shipping --ack=explicit --wait=10s --max-deliver=5
nats consumer info ORDERS shipping
nats consumer rm FULFILLMENT shippers --force
```

## What a consumer costs on disk

A durable consumer on a file-storage stream gets its own directory,
`streams/<stream>/obs/<consumer>/`, holding `meta.inf` (its config, ~330 B), `meta.sum` (16 B) and
`o.dat` — its position (source: [[s-nats-server-filestore-layout]], `nats-server 2.14.6`).

`o.dat` holds the delivered sequence, the ack floor, the pending set and redelivery counts, so its
size follows **`max_ack_pending`, not the size of the stream**. Measured on a 70,000-message stream:

| state | `o.dat` |
|---|---|
| freshly created | 8 B |
| 50 delivered, unacked | 213 B |
| 500 delivered, unacked | 2,762 B |

Roughly 5–6 bytes per outstanding message, varint-encoded, so the real figure depends on how the
pending sequences are spread. The practical point is that consumer state is *small* and bounded:
raising `max_ack_pending` costs kilobytes of disk, not megabytes. What consumers actually cost is
RAFT traffic and meta-leader load — see [[jetstream-sizing]] and
[[jetstream-slows-as-consumers-grow]].

See [[filestore-layout]] for the rest of the directory.


## Reading a consumer's state

Four fields describe where a reader has got to, and three of them are routinely confused (source:
[[s-docs-monitoring-jetstream-health]]):

| field | CLI label | meaning |
|---|---|---|
| `delivered.stream_seq` | Last Delivered Message | stream sequence of the last message handed out |
| `ack_floor.stream_seq` | Acknowledgment Floor | the sequence below which **everything** is acked |
| `num_ack_pending` | Outstanding Acks | delivered but not yet acked — **in-flight** |
| `num_redelivered` | Redelivered Messages | currently tracked as delivered more than once |
| `num_pending` | Unprocessed Messages | **lag** — waiting, never delivered |
| `num_waiting` | Waiting Pulls | outstanding pull requests |

`num_redelivered` is not a lifetime tally: when one of those messages is finally acked the server
stops tracking it and the count falls. And `num_pending` on a **filtered** consumer counts only its
own subjects, so it can be zero on a stream that is far from empty.

Which number moved tells you which problem you have: rising `num_ack_pending` is a **stuck handler**,
rising `num_pending` is **not enough handlers**. [[stream-has-high-message-lag]] has the diagnostic
that separates them from a crashed pool.

## Related

[[stream]] · [[ack-and-redelivery]] · [[retention-policies]] · [[replicas]] · [[raft-in-nats]] ·
[[worker-pool]]

## Sources

[[s-docs-delivery-and-acknowledgment]] · [[s-docs-pull-consumers]] · [[s-docs-policies]] ·
[[s-docs-consumer-config]] · [[s-docs-acknowledgment]] · [[s-docs-surviving-node-loss]] ·
[[s-docs-retention-policies]] · [[s-relnotes-2.14.0]] · [[s-docs-upgrade-to-2.14]] ·
[[s-synadia-jetstream-anti-patterns]] · [[s-nats-server-constants-2.14.6]] · [[s-nats-server-filestore-layout]] ·
[[s-adr-60-reliable-sourcing]] · [[s-docs-reading-back]] · [[s-docs-filtering]] ·
[[s-docs-monitoring-jetstream-health]]
