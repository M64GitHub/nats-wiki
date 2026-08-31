---
title: "maximum messages exceeded (10077) on publish"
type: gotcha
area: [jetstream]
verified-against: nats-server 2.14.6
verified-on: 2026-08-31
tags: [10077, discard, DiscardNew, max_msgs, max_bytes, max_msgs_per_subject, purge, workqueue]
aliases: ["maximum messages exceeded", "maximum bytes exceeded", "maximum messages per subject exceeded", "10077", "stream is full", "DiscardNew full", "stream full discard new"]
sources: [s-adr-10-extended-purge, s-docs-policies, s-docs-stream-config, s-docs-retention-policies, s-docs-shaping-the-stream]
created: 2026-08-31
updated: 2026-08-31
---

# "maximum messages exceeded (10077)" on publish

A stream with `discard: new` that has reached a limit **refuses every further publish** until
something removes messages. The refusal is correct, deliberate behaviour — the trouble is that it is
reported only to the publisher, and the server log says nothing at all.

## Symptom

The `PubAck` carries an error instead of a sequence (observed on nats-server 2.14.6):

```json
{"error":{"code":503,"err_code":10077,"description":"maximum messages exceeded"},"stream":"FULL","seq":0}
```

Through the CLI:

```
$ nats pub -J full.a "msg"
nats: error: maximum messages exceeded (10077)
```

Three limits produce the same code with different text (`server/store.go:48-53`):

| text | the limit that was hit |
|---|---|
| `maximum messages exceeded` | `max_msgs` |
| `maximum bytes exceeded` | `max_bytes` |
| `maximum messages per subject exceeded` | `max_msgs_per_subject` with `discard_new_per_subject` |

**The server log is silent.** The refusal exists only as a rate-limited *debug* line
(`server/stream.go:7063`), so at the default log level nothing appears — verified by running it:
`grep -ic 'failed to store' server.log` → `0`. An operator watching the server sees a healthy node
while every publisher is failing.

**A core publish reports success either way.** `nats pub` without `--jetstream` does not wait for the
`PubAck`, so it prints `Published 4 bytes` against a stream that stored nothing. If a producer
"works" but the stream is not growing, this is the first thing to check.

## Quick triage

```
nats stream info <stream>
```

Compare `Messages` / `Bytes` against `Maximum Messages` / `Maximum Bytes`, and read
`Discard Policy`. `Old` cannot produce this error; `New` at the limit always does.

```
nats stream report
```

lists `Messages` and `Bytes` for every stream at once — the fastest way to find *which* stream has
grown, though it prints no limits, so the comparison still comes from `nats stream info`.

## Causes

### 1. The stream is at `max_msgs` / `max_bytes` and `discard: new`

The intended behaviour of the policy: "`new` refuses the publish" rather than deleting the oldest
message (source: [[s-docs-policies]]). It is chosen deliberately when losing old data is worse than
losing new data — an audit log, a ledger, a work queue that must not silently drop.

**Confirm:** `Messages` equals `Maximum Messages`, or `Bytes` is at `Maximum Bytes`, with
`Discard Policy: New`.

**Fix — the four options, in the order they are usually right:**

```
# 1. make room, keeping the newest N            (immediate, no config change)
nats stream purge ORDERS --keep=1000

# 2. drop one subject's worth                   (immediate, surgical)
nats stream purge ORDERS --subject='orders.eu.>'

# 3. drop everything below a known checkpoint   (immediate)
nats stream purge ORDERS --seq=45000

# 4. raise the limit, or change the policy      (takes effect at once, both are live edits)
nats stream edit ORDERS --max-msgs=1000000 -f
nats stream edit ORDERS --discard=old -f
```

All four were run against 2.14.6. `--keep` keeps the **newest** messages and **does not reset the
stream's sequence numbers** — a purge to one message left the stream at `First Sequence: 3`,
`Last Sequence: 3` (source: [[s-adr-10-extended-purge]]). `--seq` and `--keep` cannot be combined;
the server returns `10003 bad request` if you send both.

Both `discard` and the limits are editable on a live stream, so options 4 need no downtime — but
switching to `discard: old` changes what the stream is *for*, and should be a decision, not a fix
under pressure.

### 2. A WorkQueue stream whose consumers stopped acking

A `WorkQueue` stream deletes a message when it is acked. If the workers stop — crashed, wedged, or
just slower than the producers — nothing is deleted, the stream fills, and with `discard: new` (the
usual choice for a work queue) publishes start failing. The stream is not the problem; the consumer
is.

**Confirm:** `nats consumer info <stream> <consumer>` — `Unprocessed Messages` large and not
falling, or `Outstanding Acks` pinned at `maximum` (verified labels, nats CLI 0.4.0). See
[[retention-policies]] for what WorkQueue deletes and when.

**Fix:** get the consumers acking again. Purging here throws away unprocessed work — do it only
when the backlog is known to be disposable.

### 3. `max_msgs_per_subject` with `discard_new_per_subject`

The per-subject variant refuses a publish on **one** subject while the rest of the stream is fine.
It is only legal together with `discard: new` (`server/stream.go:1803`), and produces
`maximum messages per subject exceeded`.

**Confirm:** `nats stream subjects <stream>` shows the offending subject at exactly its per-subject
limit while `Messages` is well below `Maximum Messages`.

**Fix:** `nats stream purge <stream> --subject=<that subject> --keep=<n>` — the only purge form that
addresses one subject.

### 4. It is a limit you did not set

An account tier limit or a server-wide one produces a *different* error —
`insufficient storage resources available (10047)` or `10028`. If the code is 10047 and not 10077,
this is not the page: see [[jetstream-out-of-disk]].

## Prevention

**The `learn` chapter confirms all three strings and the `discard_new_per_subject` requirement** from
a second source: a per-subject limit "still rolls, discarding the subject's oldest message rather than
rejecting the publish", and making it reject "takes a second setting, `DiscardNewPerSubject`… on top
of Discard New" (source: [[s-docs-shaping-the-stream]]). It adds one framing worth keeping when
sizing: **`max_age` never rejects a publish** — it expires stored messages on its own timer under
either discard policy, so a stream that is "full" is always full on bytes or count.

- **Alert on fullness, not on the error**, because the error never reaches the server's logs or
  metrics. Compare `state` against `config` per stream on `/jsz?streams=1&config=1` —
  `state.messages` and `state.bytes` against `config.max_msgs` and `config.max_bytes`. **`config=1`
  is required**: `/jsz?streams=1` alone returns `state` with no `config` to compare it to (verified
  on 2.14.6). See [[monitoring-endpoints]].
- **Make publishers surface the `PubAck` error.** A producer that fires and forgets turns a loud,
  correct refusal into silent data loss.
- **Decide `discard` deliberately at creation.** `old` never produces this failure and silently
  drops the oldest data instead; `new` never loses what it accepted and stops the world instead.
  There is no third option — see [[retention-policies]].
- **For a work queue, alarm on consumer lag, not on stream size.** By the time the stream is full the
  queue has been broken for a while.

## Explained by

[[retention-policies]] — what `discard`, the limits and WorkQueue deletion actually do.

## Related

[[stream]] · [[retention-policies]] · [[jetstream-out-of-disk]] · [[stream-has-high-message-lag]] ·
[[monitoring-endpoints]] · [[error-codes]]

## Sources

- [[s-adr-10-extended-purge]] — the three purge options and the `seq`+`keep` rejection
- [[s-docs-policies]] — the `discard` policy and which stream settings can change on a live stream
- [[s-docs-stream-config]] — `max_msgs`, `max_bytes`, `max_msgs_per_subject`, `discard_new_per_subject`
- [[s-docs-retention-policies]] — WorkQueue deletion on ack
- [[s-docs-shaping-the-stream]] — the three rejection strings named together, and `max_age` as the
  one limit that never rejects a publish
- `raw/nats-server-src/compression-purge-discovery-observed-v2.14.6.md` — the `PubAck` above, the
  silent log and the purge behaviour, run on the v2.14.6 binary
