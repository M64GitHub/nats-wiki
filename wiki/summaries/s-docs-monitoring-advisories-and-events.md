---
title: "docs — Monitoring: Advisories & events"
type: summary
area: [monitoring, jetstream]
source-url: https://docs.nats.io/learn/monitoring/advisories-and-events.md
source-path: raw/nats-docs/learn/monitoring/advisories-and-events.md
author: nats-io docs
article: "learn/monitoring/advisories-and-events.md"
date: 2026-09-01
version: ""
tags: [advisories, max_deliver, MAX_DELIVERIES, system-events, STATSZ, leader-elected, dead-letter]
aliases: []
sources: []
created: 2026-09-01
updated: 2026-09-01
---

# docs — Monitoring: Advisories & events

The hand-written chapter on the same subjects the *generated* advisory reference covers — which is
where docs issues **#1–#3** live, so this page was ingested partly as a cross-check on them.

## Key claims

**An advisory is a transient JSON message**, "published once, the moment something noteworthy happens
to a stream or a consumer… It's a normal NATS message on a well-known subject." Everything lands under
`$JS.EVENT.ADVISORY.>`, and "the stream name and consumer name are baked into the subject", so a
wildcard can select exactly the events wanted.

**The worked example is the max-deliveries advisory**, on
`$JS.EVENT.ADVISORY.CONSUMER.MAX_DELIVERIES.ORDERS.shipping`, with the body:

```json
{ "type": "io.nats.jetstream.advisory.v1.max_deliver",
  "stream": "ORDERS", "consumer": "shipping", "stream_seq": 987, "deliveries": 5 }
```

**There is no dead-letter queue.** "The `max_deliver` advisory is the only built-in signal that this
happened. There's no dead-letter queue, and the advisory is published once. If no one is subscribed
when it fires, you never learn that order `987` stopped being delivered." The message itself stays in
the stream under its retention policy; what stops is delivery to that consumer.

**Other types named, without their subjects**: a `consumer_action` advisory on create or delete, a
`nak` advisory "when a handler explicitly negative-acks a message", and a `terminated` advisory. The
page names them as **types** and defers the subjects to the generated reference.

**The leader-elected advisory** is called out separately: "a flapping leader showing up here is worth
watching", but the page is deliberate that it covers *observing* the event and not the election —
"the advisory is a fact you receive, and this page does not explain the process."

**System events** are the second stream: `$SYS.ACCOUNT.<account>.CONNECT` and `.DISCONNECT` per
account, and a `STATSZ` heartbeat on `$SYS.SERVER.<id>.STATSZ` carrying "the same kind of summary
numbers as `/varz`, pushed instead of pulled". They are published into the **system account**, so
subscribing needs a system user.

**The fix for transience is a stream**, and the page gives it:

```
nats stream add ADVISORIES --subjects '$JS.EVENT.ADVISORY.>' \
  --storage file --retention limits --max-age 168h --defaults
```

then `nats stream view ADVISORIES`, or filtered with
`--subject '$JS.EVENT.ADVISORY.CONSUMER.MAX_DELIVERIES.>'`.

## Practical takeaways

- "Capture advisories in a durable destination that is always subscribed" is the whole operational
  point of the page; a `nats subscribe` in a terminal is a demo, not monitoring.
- The absence of a dead-letter queue is stated plainly here and is the kind of thing an operator
  assumes exists.

## Notable quotes

> "There's no dead-letter queue, and the advisory is published once."

> "A leader-elected advisory reports a flap, not its cause."

## Relevance to the wiki

**As a cross-check on docs issues #1–#3, it is a partial result.** The page names the `nak` advisory
as a *type* and never writes its subject, so it neither confirms nor contradicts the generated
reference's `MSG_NAK`. It does not mention pinned or unpinned at all. Those three issues therefore
still rest on the server — which is now stronger than it was, because the nak subject has since been
**observed on the wire** ([[s-nats-server-monitoring-observed]]).

**It did produce a new finding of its own**: the page's prose says
`$JS.EVENT.ADVISORY.CONSUMER.MAX_DELIVERIES.ORDERS.shipping` and its animation caption drops
`.CONSUMER.` three times. The server agrees with the prose. Recorded as docs issue **#36**.

## Questions it answers

None in the bank directly; supports the [[advisories]] reference page.

## Pages touched

[[advisories]] · [[monitoring-endpoints]] · [[ack-and-redelivery]] · [[raft-in-nats]]

## Sources

`raw/nats-docs/learn/monitoring/advisories-and-events.md` · verified against the server in
`raw/nats-server-src/monitoring-observed-v2.14.6.md`
