---
title: "nats: timeout"
type: gotcha
area: [core, jetstream, deploy, topology]
verified-against: nats-server 2.14.6
verified-on: 2026-08-31
tags: [timeout, request-reply, no-responders, gomaxprocs, request_queue_limit, routes, kubernetes]
aliases: ["nats: timeout", "Future cancelled, response not registered in time", "request timeout", "no responders available for request", "publish timeout"]
sources: [s-gh-5859-unexpected-nats-timeout, s-nats-server-jetstream-log-warnings, s-gh-7190-asymmetric-cluster, s-docs-monitoring-endpoints, s-docs-forming-a-cluster, s-gh-6490-high-message-lag, s-nats-server-jetstream-cluster]
created: 2026-08-31
updated: 2026-09-01
---

# "nats: timeout"

A request went out and no reply came back inside the client's deadline. That is all the error says,
and the server neither sends it nor logs it — which is why the usual first move, grepping the server
log, finds nothing.

## Symptom

From a Go client:

```
nats: timeout
```

From Java, the same thing wearing different words:

```
java.util.concurrent.CancellationException: Future cancelled, response not registered in time, check connection status.
	at io.nats.client.support.NatsRequestCompletableFuture.cancelTimedOut(NatsRequestCompletableFuture.java:42)
```

(source: [[s-gh-5859-unexpected-nats-timeout]])

## First: which of the two errors is it?

| error | who produces it | what it means |
|---|---|---|
| `nats: timeout` | the **client**, on its own deadline | a subscriber existed (or the client could not tell), and no reply arrived in time |
| `nats: no responders available for request` | the **server**, immediately | nothing was subscribed to the subject at all |

The strings are `ErrTimeout = errors.New("nats: timeout")` and
`ErrNoResponders = errors.New("nats: no responders available for request")` in `nats.go` v1.53.1
(`nats.go:113` and `nats.go:151`). Other clients word them differently; the distinction is the same
everywhere, and it is the first fork in the diagnosis. **No responders is a routing or permissions
problem. A timeout is a slowness or delivery problem.**

For JetStream specifically there is a third: `no response from stream`
(`jetstream/errors.go:264`), which is a publish whose `PubAck` never arrived.

## Rule out first: this line is not a symptom

```
[DBG] 10.0.6.146:45496 - cid:14 - Client Ping Timer
[DBG] 10.0.6.146:45496 - cid:14 - Delaying PING due to remote client data or ping 48s ago
```

> "The Delaying PING message is just part of the periodic ping interval from the server which happens
> every 2 minutes unless there is some recent data being sent (if there was data in the past 2m then it
> will not send the ping thus logging `Delaying PING due to remote client`...)."
> — @wallyqs, 2024-09-27 (source: [[s-gh-5859-unexpected-nats-timeout]])

Two people in one thread went hunting on the strength of these lines. They are normal.

## Quick triage

```
nats --context <ctx> rtt
nats server list                        # do all nodes report the same route count?
nats server report jetstream
curl -s localhost:8222/varz | jq '.slow_consumers, .gomaxprocs, .cores, .routes, .leafnodes'
curl -s 'localhost:8222/connz?sort=pending&limit=10' | jq '.connections[] | {cid, name, pending_bytes}'
```

Then, if the timeout is on a JetStream call, grep the server log for the one line that proves the
server threw the request away:

```
JetStream API queue limit reached, dropping 10000 requests
```

## Causes, ranked

### 1. The JetStream API queue filled and the server dropped every pending request

The sharpest server-side cause, and it produces exactly this symptom with no error reply of any kind:

```go
pending, _ := queue.push(&jsAPIRoutedReq{…})
if pending >= int(limit) {
	s.rateLimitFormatWarnf("%s limit reached, dropping %d requests", queue.name, pending)
	drained := int64(queue.drain())
	…
	s.publishAdvisory(nil, JSAdvisoryAPILimitReached, JSAPILimitReachedAdvisory{…})
}
```

`jetstream_api.go:876–890` (source: [[s-nats-server-jetstream-log-warnings]], v2.14.6). When the queue
reaches its limit the server **drains it entirely** — every queued request is discarded, not answered
with an error. There are two queues with two names, `JetStream API queue` and
`JetStream API info queue`, so the log lines read

```
JetStream API queue limit reached, dropping 10000 requests
JetStream API info queue limit reached, dropping 10000 requests
```

The limits are `request_queue_limit` (default **10,000**) and `info_queue_limit`, which defaults to
`request_queue_limit` rather than to its own value.

**How to confirm.** Subscribe to the advisory, which carries the count:

```
nats --context sys subscribe '$JS.EVENT.ADVISORY.API.LIMIT_REACHED'
```

**The fix.** Reduce JetStream API traffic before raising the limit — `consumer info` polling and
`stream info` in a loop are the usual sources ([[jetstream-slows-as-consumers-grow]]).
`$JS.API.STREAM.INFO`-shaped requests use the *second* queue, so a monitoring loop can saturate one
without touching the other.

### 2. The cluster is not fully formed, so requests reach a server that cannot answer

The one concrete defect found in the thread, and it was in the config:

> "the following configuration will not work ok on k8s, you need to add all the A records from the
> statefulset to the config or use the nats-io/k8s helm chart" — @wallyqs, 2024-08-28

against

```
  routes = [
    nats://nats_cluster:paass@nats:6222
  ]
```

with the fix as one entry per pod:

```
  routes = [
    nats://nats-0.nats_cluster:paass@nats:6222
    nats://nats-1.nats_cluster:paass@nats:6222
    nats://nats-2.nats_cluster:paass@nats:6222
  ]
```

**How to confirm.** `nats server list` and compare the `Routes` column across nodes. Unequal counts
mean a partially formed cluster — the same defect [[s-gh-7190-asymmetric-cluster]] documents from the
other side, where clients ended up partitioned.

**The fix.** [[build-a-3-node-cluster]] has the route block; on Kubernetes the Helm chart already
generates it ([[nats-helm-charts]]).

**The meta-layer form of this cause, read from the source.** Every JetStream API request that changes
something — create, update, delete, consumer create, stepdown, peer-remove, and `STREAM.INFO` on a
work-queue or interest stream — is answered only by the **meta leader**. A server that is not the
leader **returns without replying**; only a server that *knows* the group is leaderless answers
`10008 JetStream system temporarily unavailable`. So during a meta election (4–9 s after a leader
dies, ~10 s more if a survivor still believes it leads) the client sees its own timeout and nothing
else — observed on 2.14.6 ([[meta-layer]]; source: [[s-nats-server-jetstream-cluster]]).


### 3. The server has fewer cores than you think

From the second reporter's own startup log:

```
maxprocs: Updating GOMAXPROCS=1: determined from CPU quota
```

on a host with 8 vCPUs and containers capped at `cpus: '1.50'`. The maintainer's hypothesis:

> "I think in your case what may be blocking or causing delays in the server is the `GOMAXPROCS=1`
> setting reported in the logs, do the machines only have one cpu?" … "I think for now you could try
> to set it to GOMAXPROCS=2"

**Unconfirmed.** The reporter never posted a result, `docker stats` never showed the servers at their
CPU limit, and identical cgroup limits produced *different* `GOMAXPROCS` values across processes.

**How to confirm.** `gomaxprocs` and `cores` in `/varz`, and the `maxprocs:` line at startup.

**The fix.** Give the container a whole number of CPUs, or set `GOMAXPROCS` explicitly. A fractional
CPU limit rounding down to 1 is the shape to look for.

### 4. Something on the write path is slow, and the reply is queued behind it

`slow_consumers` in `/varz` and `pending_bytes` in `/connz?sort=pending` are the two numbers
(source: [[s-docs-monitoring-endpoints]]). A responder that cannot be written to fast enough answers
late or not at all — see [[slow-consumer-detected]], and note that its log line does not name the
connection.

### 5. The stream leader is behind

If the timeout is on a **publish** rather than a request, and the server log carries
`has high message lag`, the ingest path is the problem, not the network — [[stream-has-high-message-lag]].
That pairing — an application publish failing with `timeout` while the leader logged the lag warning
every few seconds — is exactly what the first reporter of that thread saw
(source: [[s-gh-6490-high-message-lag]]). The maintainer's two named causes are both on the publishing
side rather than the server's: **a core NATS publish into a stream's subject**, and **async JetStream
publishes from many publishers at once**. Both remove the backpressure a synchronous `PubAck`
provides, so check the publisher before you check anything else.

### 6. The request never left the domain it needed to

A JetStream call across a leafnode where the domains do not line up gets denied rather than routed,
and the client waits out its deadline. The log line to look for is
`JetStream using domains: local "…", remote "…"` — see
[[streams-not-visible-across-a-leafnode]].

## What this page cannot tell you

Both reports in the source thread are **unresolved**. Neither reporter confirmed a fix, and the thread
ends on an untested suggestion. The causes above are ordered by how checkable they are, not by how
often they are the answer — there is no public evidence for that ordering.

## Prevention

- Set request timeouts deliberately per call site, and log which subject timed out. `nats: timeout`
  with no subject is unactionable.
- Alert on `$JS.EVENT.ADVISORY.API.LIMIT_REACHED` — it is the only signal that requests were silently
  discarded, and [[advisories]] lists it among the four worth alerting on.
- Verify route symmetry after every cluster change: `nats server list`, same `Routes` count
  everywhere.
- Pin `GOMAXPROCS` or use whole-CPU limits on containers.

## Related

[[stream-has-high-message-lag]] · [[slow-consumer-detected]] · [[build-a-3-node-cluster]] ·
[[streams-not-visible-across-a-leafnode]] · [[js-api]] · [[js-api-subjects]] · [[advisories]] ·
[[monitoring-endpoints]] · [[config-keys]] · [[jetstream-slows-as-consumers-grow]] ·
[[nats-helm-charts]] · [[nats-go]]

## Sources

- [[s-gh-5859-unexpected-nats-timeout]] — both reports, the ping-line correction, the routes defect
  and the `GOMAXPROCS` hypothesis.
- [[s-nats-server-jetstream-log-warnings]] — the API queue drain, its two queue names and its limits,
  at v2.14.6.
- [[s-gh-7190-asymmetric-cluster]] — the same single-DNS-name route defect, independently reported.
- [[s-docs-monitoring-endpoints]] — `slow_consumers` and `/connz?sort=pending`.
- [[s-docs-forming-a-cluster]] — what the `Routes` column counts. ·
[[s-gh-6490-high-message-lag]] · [[s-nats-server-jetstream-cluster]]
