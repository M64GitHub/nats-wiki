---
title: "docs — MQTT: Topics and subjects"
type: summary
area: [interop, security, core]
source-url: https://docs.nats.io/learn/mqtt/topics-and-subjects.md
source-path: raw/nats-docs/learn/mqtt/topics-and-subjects.md
author: nats-io docs
article: "learn/mqtt/topics-and-subjects.md"
date: 2026-09-01
version: ""
tags: [mqtt, topic-conversion, wildcards, permissions, SUBACK, 0x80]
aliases: []
sources: []
created: 2026-09-01
updated: 2026-09-01
---

# docs — MQTT: Topics and subjects

The complete topic→subject mapping, the characters that have no encoding, and the reason an MQTT
permission set written with `/` never matches anything. Every rule on this page was **checked against
the running server and all ten matched** (`raw/nats-server-src/mqtt-websocket-observed-v2.14.6.md`).

## Key claims

**The conversion table, verbatim:**

| MQTT topic | NATS subject | rule |
|---|---|---|
| `sensors/cold-1/temp` | `sensors.cold-1.temp` | `/` between two levels becomes `.` |
| `/sensors/temp` | `/.sensors.temp` | a leading `/` becomes `/.` |
| `sensors/temp/` | `sensors.temp./` | a trailing `/` becomes `./` |
| `sensors//temp` | `sensors./.temp` | a `/` next to another becomes `./` |
| `//sensors/temp` | `/./.sensors.temp` | both rules apply in turn |
| `cold-1.temp` | `cold-1//temp` | a `.` in the topic becomes `//` |

"The two characters swap roles, and the escaping keeps the mapping reversible."

**`.` conversion arrived in NATS Server 2.10.** "Before that a `.` in a topic was rejected the way
whitespace still is."

**Six characters are refused outright**: "the space, tab, newline, carriage return, form feed, and the
DEL character". The space "has never been accepted on any version" because "a subject containing a
space would break the NATS wire protocol when forwarded to other connection types". Other control
characters pass through unchanged.

**The refusal is asymmetric**: "**Publishing** to a topic with one of these characters closes the
connection. **Subscribing** to a filter with one of them returns a failure code in the SUBACK packet,
so the subscription isn't created and the connection survives."

**Wildcards map directly**: `+` → `*`, `#` → `>`, and both are subscribe-only.

**`#` below the top level creates two NATS subscriptions.** "In MQTT, `sensors/#` matches
`sensors/cold-1`, `sensors/cold-1/temp`, and also the parent level `sensors` on its own. In NATS,
`sensors.>` requires at least one token after `sensors`" — so the server creates one on `sensors.>`
and one on `sensors`. "A filter of just `#` needs no such help."

**NATS wildcards inside MQTT topics are not escaped.** `*` and `>` are ordinary MQTT characters, so
`fleet/*/telemetry` becomes the real wildcard subscription `fleet.*.telemetry` — "The device asked for
one literal topic and receives every `fleet/<anything>/telemetry` instead." `fleet*/telemetry` stays
literal because `*` is only part of a token.

**Permissions run on the converted subject.** "The server converts first, then checks permissions… A
rule written `sensors/#` never matches anything." And for a `#` subscription both entries are needed:

```
subscribe: ["sensors.>", "sensors"]
```

"Allow only `sensors.>` and the second one is denied — which fails the *whole* filter, not just the
parent level… the server returns `0x80` in the SUBACK and tears down the `sensors.>` subscription it
had already created."

**Leading and trailing slashes are not cosmetic.** "`sensors/temp` and `/sensors/temp` convert to
different subjects… If some devices in a fleet emit a leading slash and others don't, you have two
subject trees, not one."

## Practical takeaways

- The `nats sub ">"` trick the page gives — publish one message and read the subject off the
  subscriber — is the only reliable way to write permissions for a fleet whose topics you do not
  control.
- A device that builds a topic from free text (a location name) is one space away from having its
  connection closed.

## Notable quotes

> "A rule written `sensors/#` never matches anything."

> "If some devices in a fleet emit a leading slash and others don't, you have two subject trees, not
> one."

## Relevance to the wiki

This is the page that makes MQTT an [[subject-permissions]] problem rather than a protocol problem,
and it is the source of [[mqtt]]'s conversion table.

## Questions it answers

Q81 (partly — permissions, not client ids).

## Pages touched

[[mqtt]] · [[subject-permissions]] · [[account]]

## Sources

`raw/nats-docs/learn/mqtt/topics-and-subjects.md` · verified against the server in
`raw/nats-server-src/mqtt-websocket-observed-v2.14.6.md`
