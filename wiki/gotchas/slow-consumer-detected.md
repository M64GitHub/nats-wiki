---
title: "Slow Consumer Detected in the server log"
type: gotcha
area: [monitoring, core]
verified-against: nats-server 2.14
verified-on: 2026-08-31
tags: [slow-consumer, write_deadline, nats-top, unresolved]
aliases: ["Slow Consumer Detected", "WriteDeadline exceeded", "slow consumer"]
sources: [s-gh-6605-which-consumer-is-slow, s-docs-connection-limits-config, s-docs-monitoring-endpoints, s-nats-server-constants-2.14.6]
created: 2026-08-31
updated: 2026-08-31
---

# "Slow Consumer Detected" in the server log

The server logs a slow consumer and you cannot tell **which connection** it means.

> **The public thread behind this page is unanswered.** What follows is not a confirmed fix: it is
> the two monitoring endpoints that carry the relevant numbers, plus an honest account of what the
> log line does *not* tell you. The endpoints came from the docs, not from the thread.

## Symptom

```
Slow Consumer Detected: WriteDeadline of 10s exceeded with 2 chunks of 645 total bytes.
```

Read the numbers carefully: **2 chunks, 645 total bytes**
(source: [[s-gh-6605-which-consumer-is-slow]]). This connection did not fail under a large backlog.
It failed to accept **645 bytes within 10 seconds** — which points at a stalled or wedged reader,
or a network path that is not draining, rather than at throughput.

**The log line does not name the connection, the client, the account or the subject.** That is the
entire problem.

## First: it is probably not a JetStream consumer

The word *consumer* collides here. This log line is about a **core NATS client connection** that
did not accept data before its **`write_deadline`** expired. A JetStream [[consumer]] is a different
object entirely, and a slow-consumer log line says nothing about one.

Confusing the two sends you reading `nats consumer info` output that cannot contain the answer.

## What `write_deadline` is

`write_deadline` is the server-side ceiling on how long the server will block writing to a
connection; once exceeded, **the connection is closed**. The `10s` in the message is that
configured value.

Related tuning knobs, and their reload behaviour
(source: [[s-docs-connection-limits-config]]):

| key | reload | note |
|---|---|---|
| `write_deadline` | **reloadable** | "Maximum number of seconds the server will block when writing. Once this threshold is exceeded the connection will be closed." **Default `10s`** — `DEFAULT_FLUSH_DEADLINE`, `server/const.go:132` at v2.14.6 |
| `max_pending` | **requires restart** | maximum bytes buffered for a connection. **Default 64 MB** — `const.go:102` |

The `10s` in the log line is therefore **the default**, not something someone configured — which
also means the message will say `10s` on almost every deployment
(source: [[s-nats-server-constants-2.14.6]]).

## Quick triage

**Start with the monitoring port, not with `nats-top`.** Two endpoints carry the relevant numbers
(source: [[s-docs-monitoring-endpoints]]):

```
# 1. how many the server has dropped, and whether this is flapping rather than load
curl -s http://localhost:8222/varz \
  | jq '{live: .connections, lifetime: .total_connections, dropped: .slow_consumers}'

# 2. the connections with the most data queued — the ones most likely to be responsible
curl -s 'http://localhost:8222/connz?sort=pending&limit=10&auth=true' | jq
```

**`/varz` has a `slow_consumers` field**: "the number of clients the server has disconnected for not
keeping up; on a healthy node it stays at `0`". It is a **count**, not an identity — but it tells you
whether the problem is ongoing and how bad it is.

**`/connz?sort=pending` is the closest thing to naming the offender.** The docs describe
`?sort=pending&limit=10` as returning "the ten connections with the most data queued: **the clients
most likely to fall behind**". Add `?auth=true` and each entry carries the `account` and
`authorized_user` it connected as, plus `cid`, `rtt` and `pending_bytes`.

A useful cross-check from the same source: **a large gap between `connections` and
`total_connections`, with `slow_consumers` above zero, is connection flapping rather than load** —
a client being dropped and reconnecting in a loop.

### The `nats-top` route, and why it may disappoint

The only suggestion the public thread offers is
(source: [[s-gh-6605-which-consumer-is-slow]]):

```
nats-top -sort pending
```

then correlating the connection's **port** back to the client. **It was reported not to work.**
Eleven months after the question was asked, a second person replied on the same thread:

> "I have the same question. `nats top` reports 2 slow consumers but all the connections show
> 'Pending: 0'."

So a zero pending count across every connection **does not** mean there is no slow consumer. That
observation is consistent with what the counters actually are: **`slow_consumers` is cumulative —
it counts clients the server has already disconnected** — while `pending_bytes` is instantaneous.
A connection that was dropped is no longer in the list to have pending bytes. *(unverified — this
reading fits both sources but no source states it, and it would explain the reported
`Pending: 0`.)*

The practical consequence either way: **`pending` sorting finds a client that is falling behind
right now; it will not find one that already fell over.** Poll `/connz?sort=pending` continuously
rather than after the fact.

## Causes

Ranked by plausibility, and **explicitly not confirmed by a source** — the thread behind this page
was never answered:

1. **A wedged or paused client** that is not reading its socket. The tiny byte count in the log line
   fits this better than anything else *(unverified — inferred from the 645-byte figure, not stated
   by a source)*.
2. **A network path that is not draining** — a proxy, a load balancer, or an idle-timeout device
   between client and server *(unverified)*.
3. **A genuinely slow subscriber** falling behind a high-rate subject. This is the textbook cause
   and the one the term was coined for, but it does not fit a 645-byte failure.

Each of these is a hypothesis. None is sourced.

## What would still close this page

- **Whether `/connz` exposes a per-connection slow-consumer counter** — the endpoint's response
  schema has not been read field by field, only its query parameters. See [[monitoring-endpoints]].
- Whether the Prometheus exporter emits a per-connection or per-account slow-consumer metric.
- Whether the server logs the connection id or client name at a higher debug level, as it does for
  [[no-suitable-peers-for-placement|peer selection]] — `debug` is reloadable
  ([[config-keys]]), so this is cheap to test on a running server.
- Confirmation of the cumulative-vs-instantaneous reading above.

## Prevention

- **Name your connections**, and connect as a distinct user per service. `/connz?auth=true` reports
  `account` and `authorized_user`, so identity in the connection is what makes the endpoint useful
  when it matters.
- **Poll `/connz?sort=pending` continuously**, not after an incident — a dropped connection is gone
  from the list.
- **Alert on `/varz`'s `slow_consumers`**, and on the `connections` / `total_connections` gap that
  distinguishes flapping from load ([[monitoring-endpoints]]).
- **Know your `write_deadline`.** The default is `10s` and it is reloadable, so it can be raised to
  buy diagnosis time without a restart — but raising it hides the symptom rather than fixing the
  reader.

## Explained by

Nothing yet. When a source explains what the server counts as a slow consumer and where it records
the connection, that becomes an internals page and this page should link it.

## Related

[[consumer]] · [[monitoring-endpoints]] · [[nats-cli]] · [[jetstream-sizing]] ·
[[config-keys]] · [[defaults-and-limits]] · [[advisories]]

## Sources

[[s-gh-6605-which-consumer-is-slow]] · [[s-docs-connection-limits-config]] ·
[[s-docs-monitoring-endpoints]] · [[s-nats-server-constants-2.14.6]]
