---
title: "JetStream stream ... has high message lag"
type: gotcha
area: [jetstream, monitoring]
verified-against: nats-server 2.14.6
verified-on: 2026-08-31
tags: [message-lag, log-warnings, publish, backpressure, puback, replicas, raft]
aliases: ["has high message lag", "high message lag", "JetStream warnings in the log", "streamLagWarnThreshold"]
sources: [s-gh-6490-high-message-lag, s-nats-server-jetstream-log-warnings, s-nats-server-jetstream-resources, s-docs-replication-and-r3, s-docs-monitoring-jetstream-health, s-gh-5859-unexpected-nats-timeout, s-gh-6005-sourcing-memory-stream-restart, s-relnotes-2.10]
created: 2026-08-31
updated: 2026-09-03
---

# "JetStream stream … has high message lag"

The stream leader is accepting publishes faster than the Raft group can commit and apply them. The
warning is a backlog gauge on the write path, and the client-side partner symptom is a publish that
times out.

## Symptom

```
[61] 2025/02/08 15:25:27.467719 [WRN] JetStream stream '$G > DEFAULT_STREAM' has high message lag
[61] 2025/02/08 15:25:41.480542 [WRN] JetStream stream '$G > DEFAULT_STREAM' has high message lag
[61] 2025/02/08 15:25:47.005060 [WRN] JetStream stream '$G > DEFAULT_STREAM' has high message lag
```

repeating every few seconds, usually alongside an application publish failing with `timeout`, and
sometimes a consumer leader election in between (source: [[s-gh-6490-high-message-lag]]).

**Do not go looking for the timeout half in the server log — it is not there.** `nats: timeout` is a
**client-side** error: the reply never arrived inside the client's deadline, and "the server does not
send it and does not log it", which is why reporters chasing it hunt server logs and find nothing
(source: [[s-gh-5859-unexpected-nats-timeout]]). The warning above is the server's side of the same
event; the two have to be correlated by time, not by grep. See [[nats-timeout]].

## What it measures — exactly

```go
if mset.clseq-(lseq+mset.clfs) > streamLagWarnThreshold {
	lerr := fmt.Errorf("JetStream stream '%s > %s' has high message lag", jsa.acc().Name, name)
	s.RateLimitWarnf("%s", lerr.Error())
}
```

`stream.go:7651–7653`, with `streamLagWarnThreshold = 10_000` at `jetstream_cluster.go:10213`
(source: [[s-nats-server-jetstream-log-warnings]], v2.14.6).

The quantity is the stream leader's **clustered sequence** minus what it has actually applied
locally: more than **10,000** proposals accepted from publishers that the group has not committed and
applied yet.

Three consequences follow directly:

- It is about the **replication and store** path, not consumers. Nothing about delivery, acks or
  redelivery is involved.
- The threshold is a **compile-time constant**. There is no config key; the `TODO` next to it says as
  much: "Make this a limit where we drop messages to protect ourselves, but allow to be configured."
- It goes through `RateLimitWarnf`, so **the frequency of the line is capped and means nothing**.
  Ten lines a minute is not ten times worse than one. Do not alert on line count.

## Quick triage

```
nats stream info <stream>
nats server report jetstream
curl -s localhost:8222/jsz?acc=<ACCOUNT>&streams=1 | jq '.account_details[].stream_detail[] | {name, cluster}'
```

Then answer one question before anything else: **is anything publishing without waiting for a
`PubAck`?**

## Causes, ranked

### 1. Publishing with no backpressure

The maintainer's answer, and the only one the thread got:

> "This means you are sending faster then the system can process and store messages into the stream.
> This can happen if you use a core publish into a stream or if you use async Jetstream publishes with
> many publishers." — @derekcollison, 2025-05-22 (source: [[s-gh-6490-high-message-lag]])

Two distinct mistakes, both of which remove the throttle that a synchronous `PubAck` provides:

- **A core NATS publish into a stream's subject.** Fire-and-forget: the publisher never learns the
  stream is behind, so it never slows down. The stream still ingests every message.
- **Async JetStream publishes from many publishers.** Each publisher's in-flight window is bounded on
  its own; the *sum* across publishers is not.

**How to confirm.** Audit the publishing path for `publish` vs `publishAsync`/`PublishAsync` and for
plain core publishes onto a subject a stream captures. `nats stream info` growing far faster than
consumers drain is corroboration, not proof.

**The fix.** Use a synchronous publish, or bound the async in-flight window per publisher and cap the
number of publishers. A `PubAck` is the backpressure signal — see [[replicas]] for what it actually
promises.

### 2. The store cannot keep up

The same warning appears when apply is slow rather than ingest fast: slow disks, a network-attached
volume with poor latency, `sync_always`, or a node under CPU pressure. The first reporter was on EBS
and observed it with "no high load or anything extraordinary" — that half of the thread is
**unanswered**.

**How to confirm.** Compare the three replicas: if one is behind and the others are not, it is that
node's storage. `nats stream info` shows each peer's `current` state and lag.

**The fix.** [[jetstream-sizing]] on what runs out first; [[rebalance-streams]] to move the replica off
a bad node.

### 3. The Raft group cannot commit

R3 commits on a majority. A peer that is slow, unreachable or flapping stretches the commit path, and
the leader's accepted-but-unapplied backlog grows. Look for the group's own warnings alongside:
`has NO quorum, stalled`, `Failed to install snapshot`.

**How to confirm.** `nats stream cluster step-down <stream>` and watch whether the lag follows the
leader (a node problem) or stays with the stream (a workload problem).

### 4. Restart cleared it and nobody knows why

The first reporter's experience — "Only restart helped to resolve that" — with no follow-up from a
maintainer. Recorded honestly: this page cannot tell you why a restart fixed a case with no load
behind it.

## The neighbouring warnings, and what each one means

Q62 asks how to read JetStream warnings generally, so here are the ones an operator actually meets,
each read from the v2.14.6 source (source: [[s-nats-server-jetstream-log-warnings]]).

| log line | file:line | what it means |
|---|---|---|
| `JetStream stream '<acc> > <s>' has high message lag` | `stream.go:7652` | >10,000 accepted-but-unapplied proposals on the leader. This page. |
| `JetStream cluster stream '<acc> > <s>' has NO quorum, stalled` | `jetstream_cluster.go:4811` | the stream's Raft group has no majority. Writes stop. |
| `JetStream cluster consumer '<acc> > <s> > <c>' has NO quorum, stalled.` | `jetstream_cluster.go:7308` | the same, for a consumer group. |
| `Failed to install snapshot for '<acc> > <s>' [<group>]: <err>` | `jetstream_cluster.go:3257` | the Raft log could not be compacted. If `<err>` is `malformed or corrupt message`, go to [[malformed-or-corrupt-message]]. |
| `JetStream account limits exceeded for '<acc>': <err>` | `jetstream_cluster.go:10291` | the account tier, not the server, is the binding limit — [[jetstream-out-of-disk]]. |
| `JetStream cluster could not replace peer for stream '<acc> > <s>'` | `jetstream_cluster.go:2608` | no eligible peer to take over — [[no-suitable-peers-for-placement]]. |
| `Stream assignment for '<acc> > <s>' rejected by assigned member: <err>` | `jetstream_cluster.go:7461` | the meta layer placed it, the target refused. Usually resources or placement. |
| `Consumer assignment for '<acc> > <s> > <c>' not cleaned up, retrying` | `consumer.go:2322` | a consumer *deletion* the meta layer cannot land — churn, see [[kv-watchers-stall-the-cluster]]. |
| `JetStream cluster detected stream remapping for '<acc> > <s>' from "<a>" to "<b>"` | `jetstream_cluster.go:5238` | the Raft group changed identity; normal during a peer change. |
| `Stream assignment corrupt for stream '<acc> > <s>'` | `jetstream_cluster.go:7666` | meta-layer state for the stream is unreadable. |
| `JetStream consumer '<acc> > <s> > <c>' ACK sequence <n> past last stream sequence of <m>` | `consumer.go:3695` | an ack for a message the stream does not have — usually after a reset or restore. |
| `JetStream cluster metalayer log size has exceeded async threshold (<n>), will fall back to blocking snapshot` | `jetstream_cluster.go:1707` | meta-layer compaction is going synchronous; the meta layer is busy. |
| `JetStream out of <File\|Memory> resources, will be DISABLED` | `jetstream.go:657` | an actual write failure — **or** a Raft critical write error. Both go through the same handler; see [[jetstream-out-of-disk]]. |

Everything in the table above is rate-limited or one-shot at the server's discretion. **Alert on the
`$JS.EVENT.ADVISORY` events instead** — [[advisories]] names the four worth waking up for.

## Prevention

- Publish with `PubAck` on the hot path, or bound the async window explicitly. This is a design
  decision, not a tuning knob.
- Never publish into a stream's subject with a core NATS publish unless you have accepted losing the
  ack. [[stream]] covers what a stream captures.
- Alert on `$JS.EVENT.ADVISORY.STREAM.QUORUM_LOST` and `$JS.EVENT.ADVISORY.API.LIMIT_REACHED`, not on
  warning lines.

## Explained by

[[raft-in-nats]] for append→commit→apply; [[replicas]] for what a `PubAck` proves and what it does
not.

## Lag as a number, and the two numbers it is not

The server's warning is one thing; the number an operator computes is another, and the docs give it as
arithmetic (source: [[s-docs-monitoring-jetstream-health]]):

```
lag = stream.last_seq − consumer.delivered.stream_seq
```

A pull consumer reports the same value directly as **`num_pending`** (*Unprocessed Messages*), so you
normally read it rather than subtract — but doing the subtraction once is what makes clear exactly
what `num_pending` measures.

Three numbers describe a consumer, and confusing them is the usual reason a dashboard misleads:

| number | field | means | rising means |
|---|---|---|---|
| **lag** | `num_pending` | waiting, never delivered | not enough handlers |
| **in-flight** | `num_ack_pending` | delivered, not yet acked | a **stuck handler** |
| **redelivered** | `num_redelivered` | currently tracked as delivered more than once | handlers taking and not acking |

`num_redelivered` is **not a lifetime tally** — when one of those messages is finally acked the server
stops tracking it and the count drops.

### The crashed-worker signature

A high `num_pending` on its own is ambiguous: the server updates it on every new matching message
whether or not anyone is fetching, so a healthy consumer draining a backlog looks the same for a
moment. The signature that says the pool is **gone** is the combination of three fields:

> `num_pending` large and climbing · `num_waiting` at **0** · `delivered.stream_seq` **not advancing**

```
nats consumer info ORDERS shipping --json |   jq '{num_pending, num_ack_pending, num_redelivered, num_waiting, delivered, ack_floor}'
```

### A filtered consumer's lag is not a stream-wide number

A consumer filtered to `orders.shipped` counts only the shipped messages it has not seen. "An empty
pending on a filtered consumer doesn't mean the stream is empty; it means nothing on *that filter* is
waiting." Compare it against the stream's per-subject counts, not against `last_seq`.

### An upstream that restarted empty (2.10.19–2.10.21)

A source or mirror whose upstream came back at sequence 0 — a memory stream after a restart, a
recreated stream — stalls on 2.10.19, 2.10.20 and 2.10.21 until the upstream overtakes the
remembered sequence, because those releases stopped clipping the source consumer's start sequence
(#5785, reverted in 2.10.22 by #6014). On 2.14 the same shape was reported with the `AckFlowControl`
sourcing consumer; the fix is in the 2.15 preview (#8384). Details on [[mirrors-and-sources]]
(source: [[s-gh-6005-sourcing-memory-stream-restart]], [[s-relnotes-2.10]]).


## To verify

- **`since:` is deliberately absent.** The `has high message lag` warning appears in no release body from v2.10.0 to v2.14.6 (the word *lag* occurs once, in v2.12.5's `/jsz` consistency fix); its threshold is read from the v2.14.6 source, and the release that introduced the warning is not in any source read.

## Related

[[nats-timeout]] · [[malformed-or-corrupt-message]] · [[jetstream-out-of-disk]] ·
[[kv-watchers-stall-the-cluster]] · [[raft-in-nats]] · [[replicas]] · [[jetstream-sizing]] ·
[[rebalance-streams]] · [[advisories]] · [[monitoring-endpoints]] ·
[[no-suitable-peers-for-placement]] · [[stream]]

## Sources

- [[s-gh-6490-high-message-lag]] — the thread and the maintainer's answer.
- [[s-nats-server-jetstream-log-warnings]] — the threshold, the format string, and every line in the
  table above, at v2.14.6 with file and line.
- [[s-nats-server-jetstream-resources]] — the out-of-resources line's two callers.
- [[s-docs-replication-and-r3]] — quorum commit and what a `PubAck` promises.
- [[s-docs-monitoring-jetstream-health]] ·
[[s-gh-5859-unexpected-nats-timeout]] · [[s-gh-6005-sourcing-memory-stream-restart]] · [[s-relnotes-2.10]]
