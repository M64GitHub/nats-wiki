---
title: "gh#7362 — how are routez/connz rtt measured?"
type: summary
area: [monitoring, core]
source-url: https://github.com/nats-io/nats-server/discussions/7362
source-path: raw/gh-discussions/gh-7362.md
author: "@debbyglance, with @derekcollison answering"
article: "nats-io/nats-server discussion 7362"
date: 2025-09-28
version: ""
tags: [rtt, connz, routez, ping-pong, answered-partly]
aliases: []
sources: []
created: 2026-09-01
updated: 2026-09-01
---

# gh#7362 — how are routez/connz rtt measured?

The source of question-bank row **Q61**. It has a **chosen answer**, and the answer is correct but
incomplete in exactly the way that left the reporter stuck.

## Key claims

**The chosen answer, from a maintainer:** "Yes it is via periodic PING/PONG response times."

**And for `/connz` specifically:** "It is measured between the connected server and the client. It is
done on initial setup of a connection and periodically as the connection ages."

**The reporter's follow-up observation, which is the useful part of the thread:**

> "Now we are seeing high rtt values in /connz., for example, up to 7 seconds. However, **I don't see
> these values getting updated, even if we wait minutes. The rtt seems to be set when the connection
> opens and then not again thereafter**"

**That question receives no technical reply.** The final maintainer comment is: "Best to reach out to
the folks at Synadia and get a commercial agreement in place."

**One more claim worth keeping**, on interpreting a high route RTT: "We track these over time.
Anomalies should be few since modern version[s] of the server do very little processing inline with
processing the network packets. But if you see an anomaly and it is not an underlying hardware issue
check the logs for the server, many times it will point to the issue."

## Practical takeaways

- The reporter is **right**, and their observation is the correct reading of the implementation:
  `DEFAULT_RTT_MEASUREMENT_INTERVAL` is **one hour**, and a client's first `rtt` is the connection
  setup time rather than a ping round trip ([[s-nats-server-monitoring-observed]]). "Periodically" and
  "waiting minutes" simply do not meet.
- Their diagnostic goal — isolating slow responses to the cluster versus their Python client — was
  the wrong use of `/connz` `rtt` in the first place, because that number is not a live measurement
  for a client connection.

## Notable quotes

> "The rtt seems to be set when the connection opens and then not again thereafter"

## Relevance to the wiki

Q61 is answerable, and half of it is answered publicly. The half that is not — how often it refreshes,
and that a client's first value is not a ping at all — is what makes the number usable or misleading,
and it is on [[monitoring-endpoints]].

## Questions it answers

Q61 (partly; the period comes from the source).

## Pages touched

[[monitoring-endpoints]]

## Sources

`raw/gh-discussions/gh-7362.md`
