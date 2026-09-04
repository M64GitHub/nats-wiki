---
title: "observed: core NATS or JetStream on nats-server 2.14.6 — the wire, the cost, and the stream that answers your requests"
type: summary
area: [core, jetstream, clients]
source-url: ""
source-path: raw/nats-server-src/core-or-jetstream-observed-v2.14.6.md
author: maintainer
date: 2026-09-04
version: "nats-server 2.14.6; nats CLI 0.4.0; nats.go v1.53.1; natscli v0.4.0"
article: "runs A–H, eight passes, with core-or-jetstream-runA.sh … -runH.sh, core-or-jetstream-server.conf and core-or-jetstream-coj-raw.py"
tags: [observed, puback, no-responders, "503", bench, no_ack, "10052", stream-capture, step-down, mixed-design]
aliases: []
sources: []
created: 2026-09-04
updated: 2026-09-04
---

# observed: core NATS or JetStream on nats-server 2.14.6

Eight passes on one machine settling the mechanics behind [[core-or-jetstream]]: what the two publishes
look like on the wire, what each costs, what happens when a stream is laid over a subject somebody is
already using for request/reply, and what a leader election does to each publisher. Runs A–F and H on a
single server with JetStream; run G on the repo's lab (`tools/lab/cluster.sh up 3`, R3).

## Key claims

### A · a JetStream publish is a core publish with a reply subject

A raw client subscribed to `orders.>` while `nats pub orders.created 'core'` and
`nats pub orders.created 'jets' -J` went past:

```
<< MSG orders.created 1 4 | payload: core
<< MSG orders.created 1 _INBOX.1txK6pvF28KZIqM5DTYvDe.jqAH1uoV 4 | payload: jets
```

Same verb, same subject, same length. **Once stored the two are indistinguishable** — `nats stream get
… --json` returns `{"subject":"orders.created","seq":3,"data":"Y29yZS0y",…}` and
`{… "seq":4,"data":"amV0cy0y" …}` with no header and no marker on either. The difference is entirely on
the publisher's side.

### B · what the publisher learns

- A core publish nobody hears: `Published 4 bytes`, `real 0.01`, exit 0. `/varz` shows
  `in_msgs 3 out_msgs 2` — counted in, never counted out, and the publisher told nothing.
- A JetStream publish to a subject no stream captures: `nats: error: nats: no responders available for
  request`, **24 ms**, exit 1. The CLI prints its `Published …` line *before* it has an answer.

### B3 · the cost, as ratios on one laptop

200,000 messages, 128 B, one client, same server:

| publish | rate | avg |
|---|---:|---:|
| core | **2,882,347 msgs/s** | 0.29 µs |
| JetStream synchronous | **30,876 msgs/s** | 32.33 µs |
| JetStream asynchronous | **366,110 msgs/s** | 1,364.92 µs |
| JetStream asynchronous, memory stream | **591,419 msgs/s** | 844.53 µs |
| core into a subject a stream captures | **2,885,763 msgs/s** | 0.30 µs |

~93× for the synchronous round trip, ~7.9× for the asynchronous window, and **nothing at all** for a
core publisher whose subject a stream happens to capture.

### C · the core publisher does not lose messages, it just is not told

100,000 core publishes at 2.7 M msgs/s into a file stream: 100,000 stored, stable from the first
sample, `slow_consumers 0`, no log line. A second run with `nats pub --count 5000`: 5000 stored.

### D · a stream over a request/reply subject answers the requests

With a responder on `svc.echo` and no stream, `nats request svc.echo ping` → `pong` (rtt 407 µs). Add
`nats stream add SVC --subjects 'svc.>'` and the same request →

```
05:56:38 Received with rtt 276.917µs
{"stream":"SVC","seq":1}
```

`--replies=0` shows both, stream first: `{"stream":"SVC","seq":2}` at 335 µs, `pong` at 451 µs. On the
wire, two ordinary `MSG` frames on one inbox — 24 bytes of `PubAck`, then 4 bytes of `pong` — with
nothing to distinguish them. The stream also stored all three requests (`svc.echo  3`).

**The server refuses exactly three cases of this**, `server/stream.go:2170–2196` at v2.14.6: a stream
on `>` needs `no_ack` (`capturing all subjects requires no-ack to be true (10052)`) **and** R1
(`capturing all subjects requires replicas of 1`); one overlapping `$JS.>` / `$JSC.>` / `$NRG.>` needs
`no_ack` (`subjects that overlap with jetstream api require no-ack to be true`, with an exception for
`$JS.EVENT.>`); one overlapping `$SYS.>` likewise (exception `$SYS.ACCOUNT.>`). `svc.>` is not one of
them, so D is allowed silently. `10052` is `JSStreamInvalidConfigF`, description `{err}`.

### E · the only `>` stream the server accepts

`--no-ack --replicas 1` is accepted. With `no_ack`, request/reply works normally again — the hijack is a
consequence of acking, not of capturing. After six ordinary commands it held **12 subjects, 41
messages**: every `_INBOX.…` reply, `$SRV.PING.DEMO`, `DEMO.echo`, `svc.echo`,
`$JS.EVENT.ADVISORY.API` and **`$JS.API.STREAM.INFO.EVERYTHING`** — the API requests about the stream
itself. Two `nats stream subjects` calls a moment apart took that last one from 3 to 6: **reading the
stream writes to it.** And a JetStream publish into it can never succeed: `nats: timeout` at 3.042 s
with `--timeout=3s`, because a `no_ack` stream never answers.

### F · the mixed design

Core only: publishes `A B C D`; subscriber 1 saw `A`, subscriber 2 saw `D`; `B` and `C` went to nobody.
Then a stream was added and the **byte-identical** `nats pub orders.created 'E'` run again — `E` and
`F` stored with nobody subscribed. With a live core subscriber and a pull consumer both attached:

```
--- the core subscriber saw ---   G
--- the consumer replayed ---     E F G
```

Removing the stream left the core path working (`H` delivered) and made `nats pub -J` return
no-responders again.

### G · a leader step-down, both publishers at once (R3, the lab)

12 s of publishing at ~20 ms intervals, stream leader stepped down at t≈4 s, meta leader at t≈7 s:

```
t+ 4.032s   14.0ms  ERR  nats: error: nats: no responders available for request
-- js publishes: ok=311 err=1
-- core publishes: ok=312 err=0
```

- The stream leader's step-down cost the JetStream publisher **exactly one** publish, as a 503, 32 ms
  after the command — [[s-adr-22-publish-retries]]'s motivation, measured.
- The **meta** leader's step-down cost nothing. Publishes are served by the stream's leader.
- The core publisher saw nothing at all. It cannot: it never asks.
- **The CLI did not retry** — 14.0 ms is the whole subprocess including ~11 ms of process start.
  `natscli` v0.4.0 `cli/pub_command.go:279` is `nc.RequestMsg(msg, opts().Timeout)`, so ADR-22's
  back-off is never reached; the error string is `nats.ErrNoResponders`, not the retried-and-exhausted
  `ErrNoStreamResponse`.

### H · and the docs' own example does exactly this to itself

Run D used invented subjects. Run H uses the documentation's, in the order the documentation teaches
them: `learn/core-nats/request-reply.md`'s inventory service on **`orders.inventory.check`**, then
`learn/jetstream/your-first-stream.md`'s first command, **`nats stream add ORDERS --subjects
"orders.>" --defaults`**, verbatim.

```
$ nats request orders.inventory.check '{"sku":"ord_8w2k"}'     # before the stream
in stock: 42
$ nats stream add ORDERS --subjects "orders.>" --defaults
$ nats request orders.inventory.check '{"sku":"ord_8w2k"}'     # after
{"stream":"ORDERS","seq":1}
```

The responder is alive and simply loses the race (gathering shows `in stock: 42` at 374 µs behind the
ack), and `nats stream subjects ORDERS` then shows `orders.inventory.check  2` — the stream is
recording the requests. No warning, no error, and the two chapters share the example on purpose.
Recorded as `inbox/docs-issues.md` **#119** (★).

## Practical takeaways

- Keep request/reply verbs out of an event stream's subject list; widening `--subjects` is the way this
  breaks in production, and nothing warns you.
- Read `nats stream subjects <name>` after any subject change: an inbox or a service verb in that list
  is the symptom.
- Do not build a `>` stream. The server's own `no_ack` + R1 rule is the argument, and the run is the
  demonstration.
- `nats pub -J` is a diagnostic, not a resilient publisher.

## Relevance to the wiki

The evidence layer under [[core-or-jetstream]], and the observed half of [[s-adr-22-publish-retries]].

## Questions it answers

Rows 133, 194, 195, 196.

## Pages touched

[[core-or-jetstream]] · [[publishing]] · [[core-nats-delivery]] · [[stream]] · [[request-reply]] ·
[[nats-cli]] · [[nats-timeout]] · [[stream-and-consumer-config]] · [[services-on-core-nats]]
