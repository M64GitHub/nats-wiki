---
title: Core NATS or JetStream, per flow
type: operation
kind: pattern
area: [core, jetstream, deploy]
since: [2.10]
verified-against: nats-server 2.14.6, nats CLI 0.4.0, nats.go v1.53.1, natscli v0.4.0
verified-on: 2026-09-04
tags: [core-nats, jetstream, at-most-once, at-least-once, puback, no-responders, "503", mixed-design, stream-capture, no_ack, "10052"]
aliases: [core vs jetstream, "core or jetstream", when do I need a stream, "do I need JetStream", mixed design, "core and jetstream together", at-most-once or at-least-once]
sources: [s-gh-3507-no-external-store, s-docs-concepts-jetstream, s-docs-core-nats-chapter, s-docs-jetstream-where-next, s-gh-2961-js-and-core-one-cluster, s-adr-22-publish-retries, s-nats-server-core-or-jetstream-observed, s-docs-publishing, s-gh-4984-micro-with-jetstream, s-docs-core-nats-request-reply]
created: 2026-09-04
updated: 2026-09-04
---

# Core NATS or JetStream, per flow

The decision is **per subject, not per system**. One cluster carries both, the publisher's code is the
same either way, and a stream can be added under a flow that is already running. This page is how to
decide, what the mixed design looks like, and the two ways of getting it wrong that the server will
not stop you from making.

The mechanics are on [[core-nats-delivery]], [[stream]], [[consumer]] and [[publishing]]; this page is
the choice.

## The problem

You have a subject space — say `orders.>` — and several flows through it: an order is created, a
warehouse is asked whether an item is in stock, a dashboard wants the current total, an audit trail
must survive a restart. "Do we use JetStream?" is the wrong shape of question, because the answer is
different for each of those four and they can share one cluster and one subject tree.

The docs put the rule as a property of the **message**, not of the deployment: at-most-once is
"exactly right when each message is superseded by the next one, such as a live price, a current
temperature, or a cache invalidation", and "when you need messages to wait for a subscriber, survive a
restart, or be replayed later, you add a stream" (source: [[s-docs-core-nats-chapter]]). From the
JetStream side the same rule reads "stay on plain pub-sub when the next message supersedes the last;
reach for a stream only when a missed message has consequences" (source:
[[s-docs-jetstream-where-next]]).

## The decision

Take one subject at a time and answer the first row that applies.

| ask | if yes → | why, and where the mechanism is |
|---|---|---|
| Does the **next** message make this one irrelevant? | **core** | A price tick, a temperature, a heartbeat, a cache invalidation. Storing it buys nothing and costs a round trip (source: [[s-docs-core-nats-chapter]]). |
| Is a **caller waiting** for the answer right now? | **core** request/reply | The reply subject is the whole mechanism and it needs no storage; no-responders is the health signal — [[request-reply]], [[services-on-core-nats]]. |
| Would a **missed** message have to be reconciled later — an order, a payment, a ledger entry? | **JetStream** | The `PubAck` is the only proof it was stored (source: [[s-docs-jetstream-where-next]]) — [[publishing]]. |
| Must a reader **catch up** after being away, or replay history? | **JetStream** | "JetStream extends that decoupling to time - the two no longer need to be online at the same moment" (source: [[s-docs-concepts-jetstream]]) — [[consumer]]. |
| Do several readers need the **same** messages at **different speeds**? | **JetStream** | Independent cursors over one stored copy; one consumer catching up never moves another's (source: [[s-docs-concepts-jetstream]]) — [[consumer]]. |
| Does failed work need to be **retried, backed off, or dead-lettered**? | **JetStream** | Core NATS has no acknowledgement to build any of that on — [[ack-and-redelivery]], [[dead-letter-queue]], [[worker-pool]]. |
| Do you need **ordering across publishers**, or exactly-once semantics? | **JetStream** | Core NATS orders per publishing connection and subject only — [[core-nats-delivery]]. Stream sequence numbers and `Nats-Msg-Id` are the tools — [[publishing]]. |
| Is the flow a **fan-in you must not drop** under a burst? | **JetStream** | A core subscriber that falls behind is cut off — [[slow-consumer-detected]], [[slow-consumer-in-the-client]]. A stream absorbs the burst to disk. |
| Is it **request/reply that must survive the handler dying**? | **neither, as-is** | Put the work in a stream and answer from a consumer; the services framework will not grow acks (source: [[s-gh-4984-micro-with-jetstream]]) — [[worker-pool]]. |

Rows above the middle are cheap and forgetful; rows below are durable and cost a round trip. Nothing
stops one account, one subject tree and one application from having both.

## What actually differs, on the wire

There is less between them than the two names suggest. A JetStream publish **is** a core publish with
a reply subject. A raw client subscribed to `orders.>` while both went past:

```
>> SUB orders.> 1
<< MSG orders.created 1 4 | payload: core
<< MSG orders.created 1 _INBOX.1txK6pvF28KZIqM5DTYvDe.jqAH1uoV 4 | payload: jets
```

Same verb, same subject, same payload; one of them asked for an answer (run A1, source:
[[s-nats-server-core-or-jetstream-observed]]). Once stored, the two messages are **indistinguishable** —
`nats stream get` returns no header and no marker saying which one wanted an ack. The difference is
entirely on the publisher's side: one of them knows.

That single fact explains everything else:

- **The `PubAck` is a reply**, so it costs a round trip, and it is the only proof of storage — "a plain
  `nats pub` line isn't proof the message was stored" (source: [[s-docs-jetstream-where-next]]).
- **A publish to a subject no stream captures is a request nobody answers**: 503 no-responders, in
  24 ms, non-zero exit (run B2). The docs say the same: "a subject that no stream captures fails
  immediately (a 'no responders' error), and nothing was stored" (source: [[s-docs-publishing]]).
- **A leader election is a transient version of the same 503** — which is why [[s-adr-22-publish-retries]]
  exists and why clients retry it. Measured: on an R3 stream, a stream-leader step-down cost the
  JetStream publisher **exactly one publish out of 312**, while the core publisher beside it, on the
  same server through the same seconds, saw nothing at all (run G). A **meta**-leader step-down in the
  same run cost nothing: publishes are served by the stream's leader.
- **A timeout is not a failure to store.** No answer means no confirmation, not no write — retry with a
  stable `Nats-Msg-Id` (source: [[s-docs-publishing]], [[publishing]]).

## What it costs

One laptop, one client, 128-byte messages, one server, 200,000 messages each. Read these as **ratios,
not capacities** (source: [[s-nats-server-core-or-jetstream-observed]], run B3):

| publish | rate | avg latency |
|---|---:|---:|
| core | 2,882,347 msgs/s | 0.29 µs |
| JetStream, **synchronous** (a round trip per message) | 30,876 msgs/s | 32.33 µs |
| JetStream, **asynchronous** (a window of acks in flight) | 366,110 msgs/s | 1,364.92 µs |
| JetStream, asynchronous, **memory** stream | 591,419 msgs/s | 844.53 µs |
| core, into a subject a stream **does** capture | 2,885,763 msgs/s | 0.30 µs |

The shape to remember: a synchronous JetStream publish is roughly **two orders of magnitude** slower
than a core one because it waits, an asynchronous one about **eight times** slower, and a core publish
into a captured subject costs the publisher **nothing at all** — it waits for nothing, so the stream is
free to it, and it is told nothing in exchange. Sizing the durable side is [[jetstream-sizing]];
these numbers size nothing, they only rank the options.

The other cost is memory on the server, and the maintainers' answer is the only public figure-free
statement of it: "enabling jetstream will increase memory use on the server - and using it again also
will increase memory use. But core nats performance will remain the same essentially" (source:
[[s-gh-2961-js-and-core-one-cluster]]).

## The mixed design

### One cluster, not two

Asked in public whether the two need separate clusters, a maintainer's whole answer was "you can use
both at the same time with the same cluster" (source: [[s-gh-2961-js-and-core-one-cluster]]). Enable
JetStream on the cluster, create streams for the flows that need them, and leave the rest alone.
Placement of the JetStream half — which servers hold streams, and whether some run without it — is
[[stream-placement]] and [[choosing-a-topology]].

### The same subject tree

The docs' own worked example runs the *identical* Acme `orders.>` world through both chapters: the core
chapter builds it "before it adds any persistence", and the JetStream chapter picks up the same
subjects and adds `nats stream add ORDERS --subjects "orders.>"` (source:
[[s-docs-core-nats-chapter]], [[s-docs-concepts-jetstream]]). Design the subject space once —
[[subjects-and-wildcards]] — and decide durability per subject afterwards.

### The publisher does not change

A stream can be added under a flow that is already running, and removed again, with no publisher
change at all. Observed end to end (run F): with no stream, a core publisher's messages reached the
live subscriber and nothing else — two of four were published to nobody and are gone. Then a stream was
created and the **byte-identical** `nats pub orders.created 'E'` was run again; with nobody subscribed,
the messages were stored. A live core subscriber and a pull consumer then took the same publish two
different ways:

```
--- the core subscriber saw ---                      G
--- the consumer replayed what the stream held ---   E F G
```

One publish, two readers, two guarantees. Removing the stream afterwards left the core path working
and made `nats pub -J` fail with no-responders again.

**What this does not give you** is a retrofit of the past: a stream created today captures from today.
And the core publisher still learns nothing — it gets no `PubAck`, so it cannot tell a stored message
from a lost one. Use the plain publish for the flows where that is acceptable and `-J` (or the client's
JetStream publish) for the flows where it is not, on the same subject if you like.

### Where each half belongs

| flow | side | shape |
|---|---|---|
| commands with a waiting caller | core | request/reply, a queue group per service — [[services-on-core-nats]] |
| events that others react to later | JetStream | one stream per event family, `--subjects 'orders.>'` — [[stream]] |
| work that must complete once | JetStream | a work-queue stream and a shared durable consumer — [[worker-pool]], [[retention-policies]] |
| live state, current value | either | core for the tick; [[key-value]] when a late reader needs the current value |
| large payloads | JetStream | [[object-store]]; core is bounded by `max_payload` — [[defaults-and-limits]] |
| discovery, health, stats | core | `$SRV` — [[services-framework]] |

## The configuration that implements it

```
# one stream per event family, on the subjects that family owns
nats stream add ORDERS --subjects 'orders.created,orders.shipped,orders.canceled' \
  --storage file --retention limits --replicas 3 --max-age 720h

# the synchronous side keeps its own subjects, with no stream over them
#   orders.inventory.check      request/reply
#   $SRV.>                      service discovery
#   _INBOX.>                    replies
```

Three rules for the subject list, all of them load-bearing:

1. **Name the subjects, do not sweep them.** `--subjects 'orders.>'` captures `orders.inventory.check`
   too, and the next section is what that does.
2. **Never capture `_INBOX.>`, `$SRV.>` or `>`.** Reply subjects and discovery are not events.
3. **One stream per subject.** Overlapping streams are refused with `subjects overlap with an existing
   stream (10065)`; use a mirror or a source instead — [[mirrors-and-sources]].

Every field of the stream config, with its default and the version it arrived, is in
[[stream-and-consumer-config]].

## Trade-offs and costs

- **A round trip per message**, unless you publish asynchronously and accept a window of unconfirmed
  writes — see the table above.
- **Memory and disk on the server** for every stream and consumer, and RAM even for streams you are not
  using — [[jetstream-sizing]], [[filestore-layout]].
- **Retention becomes a decision you cannot take back cheaply**: a live switch to or from `WorkQueue`
  is rejected outright — [[retention-policies]].
- **A stream is not an audit log.** Messages leave when a limit or the retention policy says so, not
  when you have finished with them; "once the msg are processed in jetstream they are vanished" is a
  regular public surprise. If you need the full history, that is a stream with limits chosen to keep
  it, and a plan for what happens when the disk fills — [[jetstream-out-of-disk]].
- **There is no third storage option.** Asked whether JetStream could persist to Postgres the way NATS
  Streaming did, the chosen answer was "no, we will support memory and file based for the store level.
  We can replicate in either store and each store can also have digital twins or source mux/demux
  streams" (source: [[s-gh-3507-no-external-store]]). Durability is bought inside NATS — [[replicas]],
  [[mirrors-and-sources]] — or not at all.
- **Every durable flow adds an election** you did not have before: a leader can move, and publishers
  see it as a transient 503 — [[stream-leader-keeps-moving]], [[s-adr-22-publish-retries]].

## When *not* to use JetStream

- **As a request/reply transport.** A synchronous round trip that exists only to confirm receipt is a
  stream publish with a `PubAck`, not a stream plus a consumer plus a reply. If a caller must wait for
  *work* to finish, it is core request/reply in front of a stream, not a stream in front of a caller —
  [[services-on-core-nats]].
- **For a flow with no retry budget.** If nothing downstream will ever re-read the message, the storage
  is paid for and never used.
- **To make a slow consumer safe.** A stream fixes the *publisher's* problem, not the reader's; a
  consumer that cannot keep up still cannot keep up — [[jetstream-slows-as-consumers-grow]].
- **On a flow whose messages supersede each other.** Prefer [[key-value]] when a late reader needs the
  current value; a bucket has one message per key by design.

## The two ways to get it wrong

### A stream laid over a request/reply subject answers the requests itself

This is the one to remember. A stream that captures a subject somebody is already using for
request/reply **replies to those requests with its own `PubAck`** — and the server allows it silently.

With a responder running on `svc.echo` and no stream, `nats request svc.echo ping` returns `pong`. Add
`nats stream add SVC --subjects 'svc.>'` and the same request returns:

```
05:56:38 Received with rtt 276.917µs
{"stream":"SVC","seq":1}
```

Gathering every reply instead of the first shows both, and the stream is **first**: `{"stream":"SVC",
"seq":2}` at 335 µs, the responder's `pong` at 451 µs. On the wire it is two ordinary `MSG` frames on
one inbox, with nothing to tell them apart:

```
>> PUB svc.echo _INBOX.rawcoj.1 4
<< MSG _INBOX.rawcoj.1 9 24 | payload: {"stream":"SVC","seq":3}
<< MSG _INBOX.rawcoj.1 9 4  | payload: pong
```

A client that takes one reply takes the `PubAck`. Meanwhile the stream is storing every request, with
its payload, as an unasked-for recording of the conversation (runs D1–D4, source:
[[s-nats-server-core-or-jetstream-observed]]).

**The documentation's own tutorial walks into this.** The core chapter builds "an **inventory**
service that answers that question on the subject `orders.inventory.check`", tells the reader that
service is "still as you left [it]", and sends them to the JetStream chapter, whose first command is
`nats stream add ORDERS --subjects "orders.>" --defaults`. Run verbatim, in that order, on 2.14.6:

```
$ nats request orders.inventory.check '{"sku":"ord_8w2k"}'     # before the stream
in stock: 42
$ nats stream add ORDERS --subjects "orders.>" --defaults
$ nats request orders.inventory.check '{"sku":"ord_8w2k"}'     # after
{"stream":"ORDERS","seq":1}
```

`nats stream subjects ORDERS` then shows `orders.inventory.check  2`. No warning, no error, and the
stream creation succeeds (run H; `inbox/docs-issues.md` #119).

**The server refuses exactly three cases of this and no others** — `stream.go:2170–2196` at 2.14.6
rejects a stream on `>`, on `$JS.>` / `$JSC.>` / `$NRG.>` and on `$SYS.>` unless `no_ack` is set:

```
nats: error: could not create Stream: capturing all subjects requires no-ack to be true (10052)
```

`svc.>` is not one of those cases, so nothing warns you. **Symptom to recognise**: a service that
worked yesterday now answers with `{"stream":"…","seq":…}`, or its callers see the wrong reply type,
right after someone widened a stream's `--subjects`. **Prevention**: list a stream's subjects
explicitly, and keep request/reply verbs out of the event subject tree — `orders.created` in the
stream, `orders.inventory.check` outside it. Confirm with `nats stream subjects <name>`, which will
show the request subject if it has been captured.

### A stream on `>` is a machine for surprising yourself

The server will accept one only with `no_ack` **and** `replicas: 1`, which is the server telling you
what it is for. With `no_ack` set, request/reply works again — the hijack above is a consequence of
acking, not of capturing — but everything else still lands in it. A `>` stream after six ordinary
commands held **twelve subjects and 41 messages**: every `_INBOX.…` reply, `$SRV.PING.DEMO`,
`DEMO.echo`, `svc.echo`, `$JS.EVENT.ADVISORY.API`, and `$JS.API.STREAM.INFO.EVERYTHING` — the
JetStream API requests **about the stream itself**. Looking at it makes it grow: two `nats stream
subjects` calls a moment apart took `$JS.API.STREAM.INFO.EVERYTHING` from 3 to 6.

And because a `no_ack` stream never answers, a JetStream publish into it can never succeed — it waits
out the full deadline and returns `nats: timeout` (3.042 s at `--timeout=3s`). Runs E1–E6.

If what you want is "capture everything for debugging", use a `>` subscription with `nats sub` for as
long as you are watching, or a narrow stream — [[core-nats-delivery]]'s debugging section.

## Verify it

```
nats stream subjects ORDERS                 # every subject the stream has actually stored
nats stream ls                              # which flows are durable at all
nats request orders.inventory.check '{}'    # a service reply, not a {"stream":...} PubAck
nats pub orders.created 'x' -J              # expect: Stored in Stream: ORDERS Sequence: N
nats pub orders.inventory.check 'x' -J      # expect: no responders — nothing captures it, by design
```

The design is right when the second-to-last line prints a sequence number and the last one fails.

## Pitfalls

- **`nats pub -J` is not a resilient publisher.** natscli v0.4.0 issues a plain
  `nc.RequestMsg(msg, opts().Timeout)` (`cli/pub_command.go:279`) with no retry, so it never performs
  ADR-22's back-off; and it prints `Published N bytes …` *before* it has an answer, so a failing
  publish prints a success line and then an error. nats.go's own `Publish` does retry — 250 ms, twice,
  by default at v1.53.1 (source: [[s-adr-22-publish-retries]]) — [[nats-cli]], [[nats-go]].
- **`no responders` at publish has two causes that look identical**: a leadership blip (retry) and *no
  stream captures this subject* (a design error). Both were observed; only one is worth retrying —
  [[nats-timeout]].
- **A core publisher into a captured subject loses nothing but is told nothing.** 100,000 core
  publishes into a file-backed stream stored 100,000, with no drop and no log line (run C1) — but the
  publisher had no way to know that.
- **A `PubAck` means stored, not processed** (source: [[s-docs-jetstream-where-next]]). The consumer's
  ack is the one that means the work happened — [[ack-and-redelivery]].

## Related

[[core-nats-delivery]] · [[stream]] · [[consumer]] · [[publishing]] · [[retention-policies]] ·
[[request-reply]] · [[services-on-core-nats]] · [[worker-pool]] · [[ack-and-redelivery]] ·
[[key-value]] · [[object-store]] · [[jetstream-sizing]] · [[choosing-a-topology]] ·
[[stream-and-consumer-config]] · [[subjects-and-wildcards]] · [[mirrors-and-sources]] ·
[[nats-timeout]] · [[nats-cli]] · [[nats-go]]

## Sources

- [[s-docs-concepts-jetstream]] — the docs' primer statement of the boundary and of temporal decoupling.
- [[s-docs-core-nats-chapter]] — "core NATS is ephemeral", the supersede rule and its examples.
- [[s-docs-jetstream-where-next]] — the reciprocal rule, the two acks, the production checklist.
- [[s-gh-2961-js-and-core-one-cluster]] — one cluster, and what enabling JetStream costs.
- [[s-adr-22-publish-retries]] — a JetStream publish is a core request; the 503 and the retry.
- [[s-nats-server-core-or-jetstream-observed]] — runs A–G on 2.14.6: the wire, the cost, the hijack,
  the `>` stream, the mixed design, the step-down.
- [[s-docs-publishing]] — the `PubAck` as proof, and what a failed publish tells you.
- [[s-gh-4984-micro-with-jetstream]] — where the core request/reply pattern stops.
- [[s-docs-core-nats-request-reply]] — the reply subject and the no-responders signal.
- [[s-gh-3507-no-external-store]] — memory or file, and no third backend planned.
