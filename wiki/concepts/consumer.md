---
title: Consumer
type: concept
area: [jetstream]
verified-against: nats-server 2.14.6
verified-on: 2026-09-03
tags: [consumer, pull, durable, max_ack_pending, deliver_policy]
aliases: [consumers, ConsumerConfig, durable, pull consumer]
sources: [s-docs-delivery-and-acknowledgment, s-docs-pull-consumers, s-docs-policies, s-docs-consumer-config, s-docs-acknowledgment, s-docs-surviving-node-loss, s-relnotes-2.14.0, s-docs-upgrade-to-2.14, s-synadia-jetstream-anti-patterns, s-nats-server-constants-2.14.6, s-adr-60-reliable-sourcing, s-nats-server-filestore-layout, s-docs-retention-policies, s-docs-reading-back, s-docs-filtering, s-docs-monitoring-jetstream-health, s-adr-17-ordered-consumer, s-adr-42-priority-groups, s-adr-8-key-value-store, s-docs-worker-pool, s-gh-5044-restrict-durable-consumers, s-gh-6605-which-consumer-is-slow, s-gh-6628-ackwait-vs-dupe-window, s-gh-6350-exponential-backoff, s-gh-4972-nak-with-delay-blocks, s-nats-server-nak-backoff-observed, s-gh-5631-nak-not-immediate, s-synadia-reliable-delivery-dlq, s-gh-4994-scale-to-zero-dlq, s-gh-8417-kv-mirror-file-vs-memory, s-nats-server-mirror, s-nats-server-redelivery-observed, s-so-78603662-acked-but-redelivered, s-issue-6921-last-per-subject-acks, s-relnotes-2.11.5, s-relnotes-2.11.2, s-relnotes-2.10, s-relnotes-2.11, s-relnotes-2.12]
created: 2026-08-31
updated: 2026-09-03
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
`--config` (source: [[s-docs-policies]]). **ADR-42 says the opposite** — "you cannot switch between
policies", only `PriorityTimeout` is updatable — and the server sides with the docs: at 2.14.6
`overflow` → `pinned_client`, removing groups and adding them back are all accepted with no error
(observed 2026-09-01, `raw/nats-server-src/priority-groups-observed-v2.14.6.md`; recorded as
`inbox/docs-issues.md` #37, source: [[s-adr-42-priority-groups]]). So priority policy is **not** one
of the fixed policies below. The rest of the feature — the three policies, the pull fields, the
`Nats-Pin-Id` handshake and the group-name rules — is [[priority-groups]].

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

### The ordered consumer is a client construct, not a server one

An [[ordered-consumer]] is not a consumer type the server offers; it is an **ephemeral push
subscription the client rebuilds**. When the client sees a gap in the consumer sequence it "closes
the subscription, releases its consumer, and creates a new one starting at the proper stream
sequence", and it does the same when heartbeats stop, because the consumer may have been deleted or
lost to a restart (source: [[s-adr-17-ordered-consumer]]).

It is therefore **deliberately restricted** — it cannot be a pull consumer, a durable, a bound or
"direct" subscription, or used with queue/deliver groups — and the client **forces** the config
rather than accepting yours: `durable_name` and `deliver_subject` must not be given, `ack_policy` is
`none`, `max_deliver` is `1`, `flow_control` is `true`, `mem_storage` is `true`, `num_replicas` is
`1`, `idle_heartbeat` defaults to **5 seconds** and `ack_wait` to "something large like **22
hours**". A supplied config that conflicts must be **rejected**, not silently adjusted.

That is why an ordered consumer disappearing and reappearing in `nats consumer ls` is normal, and
why its settings never match what your code asked for.

**Every KV read pattern is one of these consumers**, which is why a bucket with many watchers is a
bucket with many consumers (source: [[s-adr-8-key-value-store]]; [[key-value]],
[[jetstream-slows-as-consumers-grow]]):

| KV operation | the consumer underneath |
|---|---|
| **watch** | an ephemeral **ordered** consumer starting at `last_per_subject`, so it opens with the latest value for every matching key; watching several keys is several **filter subjects** on one consumer |
| **history** | an ephemeral consumer filtered by subject, reading with `deliver_all` |
| **keys** | a **headers-only** consumer set to deliver `last_per_subject` — the way to count keys without moving values |

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

### A filter that matches everything is not free on a mirror

`filter_subject` on a stream's own subject — `$KV.DNS.>` on the bucket `DNS` — costs nothing: the
file store sees that the filter *is* the stream's subject and scans linearly. The same filter on a
**mirror** of that bucket, which has no subjects of its own, sends every lookup through the block's
per-subject state once the sequence space is mostly interior deletes, and a KV bucket with a hot key
space always is. Measured: 267,866 against 1,740,462 msg/s on nats-server 2.14.6; the public report
saw 65× (sources: [[s-gh-8417-kv-mirror-file-vs-memory]], [[s-nats-server-mirror]]). Leave the
filter empty when you mean "everything"; see [[consumer-slow-on-a-sparse-stream]].


## Limits and failure modes

- **`max_ack_pending` below the batch size silently caps throughput.** With a limit of 10 against a
  batch of 100 the server delivers 10 and stops until the worker acks, however large a batch is
  asked for. Keep it at or above the batch size (source: [[s-docs-pull-consumers]]).
- **A worker pool shares one `max_ack_pending`** across every worker on the consumer, so the limit
  matters more, not less, as the pool grows (sources: [[s-docs-pull-consumers]],
  [[s-docs-worker-pool]] — "five workers get 1000 between them, not 1000 each"). See
  [[worker-pool]], and note the two things a pool does **not** change: the server serves pull
  requests in arrival order so "a faster worker pulls more often and ships more", and the read
  position "belongs to the consumer, not to each worker", advancing identically whether one process
  pulls or three.
- **You cannot tell a durable from an ephemeral at the subject level.** Modern clients create both
  on `$JS.API.CONSUMER.CREATE.<stream>.<name>` and the difference lives in the request *body*, so a
  permission rule written against the legacy `$JS.API.CONSUMER.DURABLE.CREATE.>` subject catches only
  clients that still send it. The enforceable control is the account's `max_consumers`, not a
  subject grant (source: [[s-gh-5044-restrict-durable-consumers]]; [[subject-permissions]],
  [[account]]).
- **"Slow Consumer Detected" is usually not about a JetStream consumer at all.** The line reports a
  *client connection* that failed to accept data within `write_deadline` —
  `Slow Consumer Detected: WriteDeadline of 10s exceeded with 2 chunks of 645 total bytes` — and it
  names neither a connection nor a stream. Whether the two senses of "consumer" are being conflated
  is the open half of the thread that asked; [[slow-consumer-detected]] carries what is established
  and what is not (source: [[s-gh-6605-which-consumer-is-slow]]).
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

## The batch is on the clock, all of it

`ack_wait` starts when a message is **delivered**, and a fetch delivers the whole batch at once — so
every message in a batch of *N* is on the clock from the moment the batch lands, not from the moment
the worker reaches it. With `ack_wait: 8m` and a few seconds of work per message, the tail of a
100-message batch is already past its deadline when its turn comes, and the consumer redelivers
messages a healthy worker is about to handle (source: [[s-gh-6628-ackwait-vs-dupe-window]]).

That was the real cause behind a thread that started out as a question about the duplicate window:
the reporter's `nats consumer info` showed nothing wrong — `Outstanding Acks: 0`, `Redelivered
Messages: 0` — because the evidence was in the fetch loop, not on the server. Fetching one message at
a time ended it: *"I removed this parameter and there were no more message were redelivered."*

**Size the batch to fit inside `ack_wait × workers`**, and remember it interacts with the cap from
both directions: `max_ack_pending` below the batch size caps throughput (above), and a batch larger
than `ack_wait` can absorb causes redelivery. Neither is visible in consumer state until it has
already happened.

**`max_ack_pending` is one number per consumer, not per pull loop.** Ten `Consume` callbacks against
one durable consumer share the one cap, as do ten processes: a maintainer had to correct exactly that
assumption in gh#4972, where the extra throughput the reporter saw came from dropping the setting out
of the config (restoring the default of **1000**), not from the extra loops
(source: [[s-gh-4972-nak-with-delay-blocks]]). The same thread is why a **delayed nak** counts against
the cap for the whole delay — see [[ack-and-redelivery]].

**Both retry mechanisms are consumer-shaped, but only one is consumer *configuration*.** A consumer
`backoff` shapes redeliveries the server starts when `ack_wait` expires; a delayed nak is a
per-message client call that no `nats consumer` command can set (source:
[[s-gh-6350-exponential-backoff]]). The distinction and its consequences are on
[[ack-and-redelivery]].

### The redelivery rides the next pull

An expired message is redelivered when a pull is waiting at the moment its deadline passes. A consume
loop keeps one open, so the tail of an over-sized batch comes back the instant it expires; a fetch
sized exactly to the messages and acked one by one saw no redelivery at a 10 µs deadline — the acks
cleared the queue before the next pull arrived (source: [[s-nats-server-redelivery-observed]], run
H.3). The symptom page is [[consumer-keeps-redelivering]].


## A `backoff` silently rewrites `ack_wait`

Two consumer settings that look independent are not: **if a consumer has a `backoff`, its first entry
becomes `ack_wait`**, overwriting whatever was asked for. The rewrite happens in the **server**
(`consumer.go:658` at v2.14.6, under *"If BackOff was specified that will override the AckWait and
the MaxDeliver"*), not in a client or the CLI — a config sent straight to
`$JS.API.CONSUMER.CREATE` with `ack_wait: 30s` and `backoff: [1s, 5s, 30s, 2m]` comes back stored as
**`ack_wait: 1s`** (source: [[s-nats-server-nak-backoff-observed]]). In **pedantic** mode the server
refuses the config instead, with `first backoff value has to equal batch AckWait`.

So read `nats consumer info` rather than the config you submitted:

```
nats consumer info ORDERS shipping --json | jq '.config | {ack_wait, backoff, max_deliver}'
```

The consequence for timing — including the fact that a nak carrying a delay does **not** wait the
delay it asked for on such a consumer — is on [[ack-and-redelivery]].

**A nak is answered by nobody.** Unlike a stream request, a nak is published to the message's
`$JS.ACK.…` subject and nothing replies; the server drops one whose delivery is out of range or whose
message is no longer pending, with no error and no log line
(source: [[s-gh-5631-nak-not-immediate]]). A consumer that appears to ignore naks cannot be diagnosed
from the client — read the delivery counts here instead.

**Replay is this page's `deliver_policy` aimed backwards.** A consumer started by start sequence or
start time, with `replay_policy: original` rather than `instant`, reproduces the intervals at which
the messages first arrived — the source calls it "useful for realistic load reproduction"
(source: [[s-synadia-reliable-delivery-dlq]]).

### The entries are nanoseconds on the API

`backoff` values reach the server as signed 64-bit nanosecond counts, whatever the client's type. A
client whose `Backoff` takes plain integers sends `[10000]` as ten microseconds: stored as
`ack_wait: 10000`, printed by the CLI as `Ack Wait: 10µs`, and every message is then processed
`max_deliver` times however promptly it is acked (source: [[s-nats-server-redelivery-observed]]; the
public case is [[s-so-78603662-acked-but-redelivered]]).


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

## A consumer nobody pulls from does not time out

`ack_wait` is not a background reaper. On a pull consumer, **the delivery count advances when a client
asks for messages**; with nothing fetching, a delivered message stays in `num_ack_pending` past its
`ack_wait` and `max_deliver` is never reached — so no redelivery, and no max-deliveries advisory
(source: [[s-gh-4994-scale-to-zero-dlq]], confirmed as by design by a maintainer). A push consumer
whose queue group is empty behaves the same way.

This matters for two designs in particular:

- **A worker pool that scales to zero** leaves messages pending indefinitely, and every advisory-based
  alarm stays quiet ([[worker-pool]], [[dead-letter-queue]]).
- **A monitoring check built on advisories** cannot detect "nobody is consuming"; `num_ack_pending`
  and `num_pending` on this page can.


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

### The reply subject carries the delivery count

Every delivered message's reply subject is
`$JS.ACK.<stream>.<consumer>.<delivered>.<stream seq>.<consumer seq>.<timestamp>.<pending>`. The
CLI's `tries:` is the `<delivered>` token, and at `-DV` the server's trace shows the whole subject on
each `->> [MSG …]` line — delivery 2 of stream sequence 1, as consumer sequence 4, reads
`$JS.ACK.LOOP.worker.2.1.4.…`. Nothing at the default log level records a redelivery (source:
[[s-nats-server-redelivery-observed]]).


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

## Version notes: when the consumer was not at fault

- **2.11.0–2.11.4**: a `last_per_subject` consumer with explicit acks on a stream whose per-subject
  limit leaves interior deletes (`max_msgs_per_subject` above 1) stops registering acks — the floor
  freezes, `Outstanding Acks` sits at the cap, redeliveries follow. Fixed in **2.11.5** (#7005);
  `deliver_policy: all` or `ack_policy: none` clears it meanwhile (source:
  [[s-issue-6921-last-per-subject-acks]], [[s-relnotes-2.11.5]]). Not reproducible on 2.14.6.
- **Before 2.11.3**, replicated consumers: acknowledged messages redelivered after a consumer leader
  change. The 2.11.2 fix waits for delivered state to reach quorum before delivering more, at a
  throughput cost that R1, `ack_policy: none` and ordered consumers do not pay — and 2.11.2 itself is
  withdrawn for a regression (source: [[s-relnotes-2.11.2]]).
- **2.10.16 / 2.10.17**: redelivery of acked messages during server restarts and rolling restarts
  fixed (#5419, #5482), and followers no longer inherit a redelivered sequence that "could break ack
  gap fill" (#5533) (source: [[s-relnotes-2.11.2]]).

The symptom page for all three is [[consumer-keeps-redelivering]].


### The 2.10 line

- **Since 2.10.0** a consumer may filter on **several subjects** (`filter_subjects`; #3500, #3865,
  #4008, #4129, #4188) and carry `metadata` (#3797); pull consumers report a batch-completed status
  (#3822) (source: [[s-relnotes-2.10]]).
- **2.10.4** sped up a `last_per_subject` start (#4712, #4713) and gave the AckTerm advisory a
  `reason` (#4697); **2.10.18** stopped filtered consumers acking messages that were not theirs
  (#5639); **2.10.22** made pull consumers recalculate `max_deliver` when expiring (#5995);
  **2.10.23** made backoff honour multiple in-flight deliveries and `max_deliver` (#6104, #6154) and
  had consumers ignore acks past the stream's last sequence (#6109); **2.10.25** started fewer
  clean-up goroutines for `inactive_threshold` (#6344); **2.10.26** signals consumers by filter
  (#6499 — [[jetstream-slows-as-consumers-grow]]) and improved the error when a consumer's type is
  changed (#6408).
- **Start-sequence clipping**: 2.10.19 stopped clipping `opt_start_seq` into the stream (#5785);
  2.10.22 restored it (#6014) — see [[mirrors-and-sources]].


### The 2.11 line

- **2.11.0** (source: [[s-relnotes-2.11]]): **consumer pause** — "The `PauseUntil` consumer
  configuration option and `$JS.API.CONSUMER.PAUSE` endpoint suspends message delivery to the consumer
  until the time specified is reached" (#5066); **the starting sequence is always respected**,
  "except for consumers used for sources/mirrors" (#6253) — the 2.11 resolution of the 2.10.19
  clipping story; **pedantic mode** fails a create or update "if the resulting configuration would
  differ due to defaults" (#5245); replicated consumers no longer skip redeliveries after a leader
  change (#6566).
- **2.11.2** (withdrawn; effectively 2.11.3): delivered state waits for quorum — throughput caveat on
  replicated consumers; priority groups no longer spin (#6749). **2.11.4**: redeliveries no longer
  misreported with `max_deliver: 1` (#6877). **2.11.5**: `NoWait` pulls answer correctly from
  replicated consumers (#6960); at `MaxWaiting` a request with a heartbeat gets no reply, "to avoid
  client tightloops" (#7011).
- **2.11.6**: the filtered-consumer throughput regression of 2.11.0 fixed (#7015); pending
  calculation cheaper (#7022). **2.11.7**: a pull consumer with an `inactive_threshold` counts
  pending acks before it is deleted (#7052) and does not age out while processing acks (#7107);
  `no_wait` and `expires` fixed on replicated consumers (#7046). **2.11.8**: ephemeral consumers pick
  an online server (#7165).
- **2.11.9**: a consumer cannot be created with more replicas than its stream (#7202); an infinite
  `max_deliver` (`-1`) no longer underflows (#7216). **2.11.11**: `no_wait` on an empty stream answers
  `404 No Messages` (#7466 — the body prints 400). **2.11.12**: updating filter subjects recalculates
  pending only when they change (#7753) and no longer loses interest on replicated interest or
  WorkQueue streams (#7773); a non-replicated file-backed consumer whose state file is corrupt is
  **deleted automatically** (#7691).


### The 2.12 line

- **2.12.4**: consumer info no longer recalculates pending (#7758). **2.12.5**: overlapping filter
  subjects allowed where neither is a subset (#7810); a message at `max_deliver` preserved on
  WorkQueue streams (#7845); consumer naming consistent between the current and legacy create
  endpoints (#7848); scaling a replicated consumer down to R1 uses the right name when there is no
  durable (#7891) (source: [[s-relnotes-2.12]]).
- **2.12.7**: `max_ack_pending` no longer sticks "due to deleted messages being left in the consumer
  pending state" (#7984). **2.12.8**: the start-sequence scan is asynchronous and "no longer pauses
  the metalayer" (#8051); the pause endpoint no longer panics on a concurrent map write (#8061).
- **2.12.9**: pending is calculated only on consumer leaders (#8172); the delivery policy on
  clustered WorkQueue streams enforced (#8126); a consumer with an `inactive_threshold` no longer
  loses local state when the clean-up proposal fails (#8198); the drifted-redelivered-state fixes of
  2.14.1 (#8102, #8156, #8168 — [[consumer-keeps-redelivering]]). **2.12.12**: the inactive-delete
  grace period and pull `max_bytes` budgeting fixed (#8314); ack subscriptions match consumer names
  containing `%` (#8301). **2.12.14**: changing a consumer's storage type returns an error (#8382); a
  consumer created immediately after its clustered stream no longer gets `stream not found` (#8410).


## Related

[[stream]] · [[ack-and-redelivery]] · [[retention-policies]] · [[replicas]] · [[raft-in-nats]] ·
[[worker-pool]] · [[ordered-consumer]] · [[priority-groups]] · [[key-value]] ·
[[jetstream-slows-as-consumers-grow]] · [[slow-consumer-detected]] · [[subject-permissions]] ·
[[account]] · [[mirrors-and-sources]]

## Sources

[[s-docs-delivery-and-acknowledgment]] · [[s-docs-pull-consumers]] · [[s-docs-policies]] ·
[[s-docs-consumer-config]] · [[s-docs-acknowledgment]] · [[s-docs-surviving-node-loss]] ·
[[s-docs-retention-policies]] · [[s-relnotes-2.14.0]] · [[s-docs-upgrade-to-2.14]] ·
[[s-synadia-jetstream-anti-patterns]] · [[s-nats-server-constants-2.14.6]] · [[s-nats-server-filestore-layout]] ·
[[s-adr-60-reliable-sourcing]] · [[s-docs-reading-back]] · [[s-docs-filtering]] ·
[[s-docs-monitoring-jetstream-health]] · [[s-adr-8-key-value-store]] ·
[[s-adr-17-ordered-consumer]] · [[s-adr-42-priority-groups]] · [[s-docs-worker-pool]] ·
[[s-gh-5044-restrict-durable-consumers]] · [[s-gh-6605-which-consumer-is-slow]] ·
[[s-gh-6628-ackwait-vs-dupe-window]] · [[s-gh-6350-exponential-backoff]] ·
[[s-gh-4972-nak-with-delay-blocks]]

Run directly, not read: `raw/nats-server-src/priority-groups-observed-v2.14.6.md` — nats-server
v2.14.6 with nats CLI 0.4.0, 2026-09-01, behind `inbox/docs-issues.md` #37. · [[s-nats-server-nak-backoff-observed]] · [[s-gh-5631-nak-not-immediate]] · [[s-synadia-reliable-delivery-dlq]] · [[s-gh-4994-scale-to-zero-dlq]] · [[s-gh-8417-kv-mirror-file-vs-memory]] · [[s-nats-server-mirror]] · [[s-nats-server-redelivery-observed]] · [[s-so-78603662-acked-but-redelivered]] · [[s-issue-6921-last-per-subject-acks]] · [[s-relnotes-2.11.5]] · [[s-relnotes-2.11.2]] · [[s-relnotes-2.10]] · [[s-relnotes-2.11]] · [[s-relnotes-2.12]]
