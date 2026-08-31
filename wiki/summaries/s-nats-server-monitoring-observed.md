---
title: "nats-server v2.14.6 — what `/varz` CPU and `/connz` RTT actually measure"
type: summary
area: [monitoring, core, jetstream]
source-url: https://github.com/nats-io/nats-server/tree/v2.14.6/server
source-path: raw/nats-server-src/monitoring-observed-v2.14.6.md
author: nats-io/nats-server contributors (the source and the binary); this wiki (the runs)
article: "server/monitor.go, pse/pse_linux.go, client.go, const.go, jetstream_api.go at v2.14.6, plus runs on the binary"
date: 2026-09-01
version: "2.14.6"
tags: [varz, cpu, cores, gomaxprocs, rtt, connz, routez, DEFAULT_RTT_MEASUREMENT_INTERVAL, advisories, MSG_NAKED]
aliases: []
sources: []
created: 2026-09-01
updated: 2026-09-01
---

# nats-server v2.14.6 — what `/varz` CPU and `/connz` RTT actually measure

Read and run to settle question-bank rows **Q60** and **Q61**, neither of which any page of
`learn/monitoring` states, and to cross-check docs issues **#1–#3** against something stronger than a
source constant.

## Key claims

### Q60 — `cpu` is a percentage of one core, and of nothing else

`Varz.CPU` comes from `pse.ProcUsage` (`monitor.go:1609–1618`). On Linux the value is **sampled once
a second by a background timer**, not computed at request time (`pse/pse_linux.go:49–86`): it reads
`utime + stime` from `/proc/<pid>/stat`, takes the delta since the previous sample, divides by elapsed
seconds, and stores `(total*1000/ticks)/seconds`; `ProcUsage` then returns that `/10.0`
(`pse_linux.go:104`).

One full second of CPU per second of wall clock gives `(100*1000/100)/1 = 1000`, and `/10.0` =
**100.0**. So:

> **`cpu: 100.0` means one core fully consumed. `cpu: 250.0` means two and a half cores.** It is
> relative to **neither** the host's core count **nor** any container CPU allocation.

That is the exact question asked in [[s-gh-7483-varz-cpu-in-containers]] and never answered there. For
the reporter's Fargate task at 0.25 vCPU, `cpu: 10` is 0.1 of a core — **40 % of the container's
allocation**, not 10 % of anything.

**Two caveats in the same function.** `ticks` is **hardcoded to 100** rather than read from the
system — `ticks = 100 // int64(C.sysconf(C._SC_CLK_TCK))`, commented "Avoiding to generate docker image
without CGO" (`pse_linux.go:42–43`) — so a kernel with a different `CLK_TCK` is scaled wrong. And
`seconds` derives from `syscall.Sysinfo().Uptime`, the **host's** uptime.

**`cores` is `runtime.NumCPU()` and `gomaxprocs` is `runtime.GOMAXPROCS(0)`**
(`monitor.go:1727–1728`; json tags at `:1260–1261`). Nothing in `monitor.go` or `server/pse/`
consults a cgroup CPU quota, which is consistent with the reporter seeing `"cores": 2` on a 0.25 vCPU
task.

### Q61 — RTT is a PING/PONG, but a client's refreshes at most hourly

`c.rtt` is set in exactly two places (`client.go`):

- **At connect, from the connection setup time — not a ping**: `c.rtt = computeRTT(c.start)` (`:2289`),
  for `c.kind == CLIENT`.
- **On every PONG**: `sendPing()` stamps `c.rttStart` (`:2690`) and `processPong()` does
  `c.rtt = computeRTT(c.rttStart)` (`:2801`).

`computeRTT` is `time.Since(start)` **floored at 1 nanosecond** (`:2262–2267`), so `rtt` is never
reported as zero once set.

**The refresh interval is the fact the public thread never got.**
`DEFAULT_RTT_MEASUREMENT_INTERVAL = time.Hour` (`const.go:224`), used as
`needRTT := c.rtt == 0 || now.Sub(c.rttStart) > DEFAULT_RTT_MEASUREMENT_INTERVAL` (`client.go:5844`).
And (`:5846–5852`):

- **Routes, gateways and spoke leafnodes are pinged on every ping-timer tick** (`sendPing = true`
  unconditionally), so their `rtt` refreshes at the ping interval — default `2m`.
- **A client is not.** If it sent anything within the ping interval, the PING is skipped unless
  `needRTT`, which needs **an hour** to elapse. So `/connz` `rtt` on a busy client is the
  connect-time estimate, then refreshed roughly hourly.

That is exactly what the reporter in [[s-gh-7362-routez-connz-rtt]] observed and was never told:
*"I don't see these values getting updated, even if we wait minutes."*

**MQTT connections never get an RTT ping at all** — `sendRTTPingLocked` returns false
`if c.isMqtt()` (`client.go:2671–2673`), which is worth knowing next to [[mqtt]].

**Observed**, three fresh loopback clients: `rtt=314µs`, `286µs`, `177µs` — hundreds of microseconds
where a real loopback ping is tens, consistent with these being connect-time estimates.

### The advisory subjects, on the wire

Two advisories were produced on the binary and their subjects read off `nats sub
'$JS.EVENT.ADVISORY.>'`:

```
$JS.EVENT.ADVISORY.CONSUMER.MAX_DELIVERIES.ORDERS.shipping
$JS.EVENT.ADVISORY.CONSUMER.MSG_NAKED.ORDERS.naktest
```

**Docs issue #1 is now confirmed on the wire**, not only from a constant: the nak advisory really is
published on `…CONSUMER.MSG_NAKED.<stream>.<consumer>` while the generated reference documents
`…CONSUMER.MSG_NAK.{stream}.{consumer}`.

**The max-deliveries subject carries `.CONSUMER.`**, which the chapter's prose gets right and its own
animation caption drops three times — docs issue **#36**.

**The advisory body carries `id` and `timestamp`** beyond the fields the docs' example shows:

```json
{"type":"io.nats.jetstream.advisory.v1.max_deliver","id":"9lWb25w5SokA1gpeK2wgeB",
 "timestamp":"2026-08-31T22:39:02.825838Z","stream":"ORDERS","consumer":"shipping",
 "stream_seq":1,"deliveries":2}
```

**`$JS.EVENT.ADVISORY.API` fires for ordinary API calls** — three arrived here just from creating a
stream and two consumers — so subscribing to the whole tree is noisier than the chapter suggests.

## Practical takeaways

- **A CPU alert threshold should be computed against the container's CPU allocation, not against
  `cores`.** At 0.25 vCPU, `cpu: 25` is the container saturated.
- **Do not treat `/connz` `rtt` as a live latency measurement.** For a client it is up to an hour old,
  and its first value is a connect-time estimate. `/routez` `rtt` is fresher — ping-interval age.
- **A high `rtt` on a long-lived client connection may be a stale number, not a slow network.** The
  way to force a fresh one is a new connection.

## Notable quotes

From the source comment at `pse_linux.go:103`:

> "We track this with periodic sampling, so just load and go."

## Relevance to the wiki

Q60 and Q61 were both open and neither is answered anywhere in `learn/monitoring`. Both are answered
here from the release-tag source, with the two threads' own reporters corroborating the observable
halves. It also upgrades docs issue #1's evidence from a constant to a wire capture, which matters
before that report is sent upstream.

## Questions it answers

Q60, Q61.

## Pages touched

[[monitoring-endpoints]] · [[advisories]] · [[mqtt]] · [[jetstream-sizing]]

## Sources

`raw/nats-server-src/monitoring-observed-v2.14.6.md` · [[s-gh-7362-routez-connz-rtt]] ·
[[s-gh-7483-varz-cpu-in-containers]]
