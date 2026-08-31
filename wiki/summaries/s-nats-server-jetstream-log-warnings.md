---
title: "nats-server v2.14.6 — the JetStream log warnings, read from source"
type: summary
area: [jetstream, monitoring, topology]
source-url: https://github.com/nats-io/nats-server/tree/v2.14.6/server
source-path: raw/nats-server-src/jetstream-log-warnings-v2.14.6.md
author: nats-io/nats-server contributors
article: "server/stream.go, jetstream_cluster.go, consumer.go, filestore.go, raft.go, jetstream_api.go at v2.14.6"
date: 2026-08-31
version: "2.14.6"
tags: [log-warnings, message-lag, corrupt-message, resetClusteredState, request_queue_limit, readloop]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# nats-server v2.14.6 — what each JetStream warning is actually measuring

Read because four gotcha pages needed the same thing: the exact format string, the threshold behind
it, and what the server does *next*. Every claim is a line of `nats-server` at tag **v2.14.6**; the
quoted ranges are in `raw/nats-server-src/jetstream-log-warnings-v2.14.6.md`.

## Key claims

### `has high message lag` — 10,000 uncommitted proposals on the stream leader

```go
if mset.clseq-(lseq+mset.clfs) > streamLagWarnThreshold {
    lerr := fmt.Errorf("JetStream stream '%s > %s' has high message lag", jsa.acc().Name, name)
    s.RateLimitWarnf("%s", lerr.Error())
}
```

`stream.go:7651–7653`, with `streamLagWarnThreshold = 10_000` at `jetstream_cluster.go:10213`. The
quantity is the stream leader's **clustered sequence** minus what has actually been applied locally
(plus the clustered-failure offset) — i.e. proposals accepted from publishers that the Raft group has
not committed and applied yet. It is emitted through `RateLimitWarnf`, so its frequency is capped and
tells you nothing about magnitude. The `TODO` beside it is honest about the state of things: "Make
this a limit where we drop messages to protect ourselves, but allow to be configured."

### `malformed or corrupt message` — and since 2.12 it names the file

```go
func (e errBadMsg) Error() string {
    if e.detail != _EMPTY_ {
        return fmt.Sprintf("malformed or corrupt message in %s: %s", filepath.Base(e.fn), e.detail)
    }
    return fmt.Sprintf("malformed or corrupt message in %s", filepath.Base(e.fn))
}
```

`filestore.go:8857–8862`. In **2.9, 2.10 and 2.11** this was a bare sentinel —
`errBadMsg = errors.New("malformed or corrupt message")` — carrying no file name; the struct form
first appears in **2.12**. On an older server the log line cannot tell you which block failed; on 2.12
and later it can.

`fs.error("Critical write error: %v", err)` is `filestore.go:5301`; the Raft counterpart is
`n.error("Critical write error: %v", err)` at `raft.go:5167`, immediately followed by `n.werr = err`
and `n.shutdown()` — the Raft node stops. Two conditions are filtered out **before** that point and
only warn: a permission error and `os.IsNotExist`, which logs `Resource not found: %v` and returns.

### `Resetting stream cluster state` — the server's own repair, and when it refuses

`resetClusteredState` (`jetstream_cluster.go:3912`) is called from the apply loop when an entry cannot
be applied (`jetstream_cluster.go:3524`). It steps the node down, then **declines** in four cases,
each with its own warning:

- `Will not reset stream '%s > %s', stream is closed`
- `Will not reset stream '%s > %s', raft group %q was replaced by %q`
- `Will not reset stream '%s > %s', server resources exceeded`
- `Stream '%s > %s' errored, account resources exceeded`

Otherwise it either `node.Stop()`s (for `errCatchupAbortedNoLeader` / `errCatchupTooManyRetries` —
"could've just been temporarily unable to reach the leader") or `node.Delete()`s the Raft state and
rebuilds. **Messages are preserved** unless the error is `errFirstSequenceMismatch`:

```go
shouldDelete := err == errFirstSequenceMismatch   // jetstream_cluster.go:3974
```

then logs `Resetting stream cluster state for '%s > %s'`. Seeing that line is the server healing
itself; seeing one of the four "will not reset" lines is the server telling you it cannot.

### `Consumer assignment … not cleaned up, retrying` — a deletion that will not land

```go
s.Warnf("Consumer assignment for '%s > %s > %s' not cleaned up, retrying", acc, stream, name)
```

`consumer.go:2322`. It is about removing an assignment from the meta layer, so a flood of it means
**consumer churn** the meta group cannot keep up with — not consumer count.

### The JetStream API queue drops **every** pending request when it fills

```go
pending, _ := queue.push(&jsAPIRoutedReq{…})
if pending >= int(limit) {
    s.rateLimitFormatWarnf("%s limit reached, dropping %d requests", queue.name, pending)
    drained := int64(queue.drain())
    …
    s.publishAdvisory(nil, JSAdvisoryAPILimitReached, JSAPILimitReachedAdvisory{…})
}
```

`jetstream_api.go:876–890`. The two queue names are `JetStream API queue` and
`JetStream API info queue` (`jetstream_api.go:955–956`), so the log lines read

```
JetStream API queue limit reached, dropping 10000 requests
JetStream API info queue limit reached, dropping 10000 requests
```

The limits are `request_queue_limit` (default **10,000**) and `info_queue_limit` (which defaults to
`request_queue_limit`); `$JS.API.STREAM.INFO`-style requests use the second queue.

**This is the sharpest server-side cause of a client-side `nats: timeout`**: `drain()` discards the
requests entirely, so no reply of any kind is sent — not even an error. The only traces are the
rate-limited log line and `$JS.EVENT.ADVISORY.API.LIMIT_REACHED`, which carries the `Dropped` count.

## Practical takeaways

- Two of these warnings name a **threshold** you can reason about (10,000 in-flight proposals, 10,000
  queued API requests) and both are rate-limited in the log, so alert on the advisory or on the
  metric, never on log-line frequency.
- `Critical write error` is terminal for the node that logs it. `Resetting stream cluster state` is
  not — it is the recovery. A log with the first and not the second is a stream that did not heal.
- Nothing in this set means "the disk is full"; the one that sounds like it,
  `JetStream out of resources, will be DISABLED`, is documented in
  [[s-nats-server-jetstream-resources]] and is reached from the Raft write-error path too.

## Relevance to the wiki

The authority behind [[stream-has-high-message-lag]], [[malformed-or-corrupt-message]],
[[kv-watchers-stall-the-cluster]] and the server half of [[nats-timeout]].

## Questions it answers

- **Q62** — how do I read and act on JetStream warnings in the server log.
- **Q39** and **Q77** in part.

## Pages touched

[[stream-has-high-message-lag]] · [[malformed-or-corrupt-message]] ·
[[kv-watchers-stall-the-cluster]] · [[nats-timeout]] · [[advisories]] · [[raft-in-nats]] ·
[[js-api]]
