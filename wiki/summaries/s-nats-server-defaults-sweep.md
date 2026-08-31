---
title: "nats-server v2.14.6 — the config-default sweep: leafnode compression, mqtt.max_ack_pending, mqtt.port"
type: summary
area: [topology, core, deploy]
source-url: https://github.com/nats-io/nats-server/tree/v2.14.6/server
source-path: raw/nats-server-src/defaults-observed-v2.14.6.md
author: nats-io/nats-server contributors
article: "server/opts.go, mqtt.go, server.go, websocket.go at v2.14.6, plus four runs of the v2.14.6 binary"
date: 2026-08-31
version: "2.14.6"
tags: [compression, s2_auto, mqtt, max_ack_pending, listener-ports, check-defaults]
aliases: ["defaults sweep", "check-defaults"]
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# nats-server v2.14.6 — what the default sweep found

Not a document but a **sweep**: `tools/check-defaults.py` compared all **216 documented defaults** in
`inbox/config-keys-table.md` against the option parser, the use sites, the command-line flags and the
constants of `nats-server` at **v2.14.6**, and every disagreement it produced was then read in the
source and, where it was behavioural, **run on the v2.14.6 binary**. The report is
`inbox/check-defaults-v2.14.6.md`; the source ranges and the runs are in
`raw/nats-server-src/defaults-observed-v2.14.6.md`.

Result: **175 agree, 15 disagree, 26 the tool could not resolve** (listed for a human). Twelve of the
fifteen re-derive `inbox/docs-issues.md` #19 and #22 with no human input; three are new, below. A human read of the unresolved list added one more (`mqtt.port`).

## Key claims

### Leafnode compression defaults to `s2_auto`, not `accept`

`setBaselineOptions()` defaults **both** the leafnode listener (`opts.go:6082–6089`) and **every
remote** (`opts.go:6099–6106`) to `CompressionS2Auto`, each under the comment *"Default to
compression `s2_auto`"*. The `accept` default is the **route** block's, twenty lines earlier
(`opts.go:6061–6070`). The generated reference publishes `accept` for the leafnode pages, which is
what the cluster does.

The two are not cosmetic: `accept` means *inherit, and if both ends accept, no compression*.

**Observed.** A hub and a leaf with nothing configured but a port and a remote URL report
`"compression": "s2_uncompressed"` on `/leafz` — the level `s2_auto` selects while the RTT is under
the first threshold (`selectS2AutoModeBasedOnRTT`, `server.go:625`). The same pair with
`compression: accept` written on both ends reports `"compression": "off"`. Recorded as
`inbox/docs-issues.md` #27.

### `mqtt.max_ack_pending` defaults to 1024, not 100

`mqttDefaultMaxAckPending = 1024` (`mqtt.go:151`), applied where the option is read — `mqtt.go:3336`,
`5497`, `5633`, all `if maxAckPending == 0 { maxAckPending = mqttDefaultMaxAckPending }`. The
reference's `mqtt.md` states `100`. `mqtt.ack_wait`'s documented `30s` is right by the same mechanism
(`mqttDefaultAckWait`, `mqtt.go:147`). Recorded as #28.

### `mqtt.port` has no default; `mqtt { }` starts no listener

`validateMQTTOptions` returns at `mqtt.go:692` when the port is zero; `1883` appears nowhere in the
non-test source. **Observed:** `mqtt { }` with JetStream enabled starts the server, logs no
*"Listening for MQTT clients"* line, and reports `"mqtt": {}` in `/varz`; with `port: 1883` the same
binary logs the listener. This is the same failure as the three topology ports in
`inbox/docs-issues.md` #23, and is recorded as #29.

### A default applied at the use site is invisible in `/varz`

The mechanism behind two of the three: when the server leaves an option at zero and substitutes a
constant where it reads it, the option stays zero, and `/varz` — which tags most of these fields
`omitempty` — omits it. `curl /varz | jq .mqtt` on a server with `mqtt { port: 1883 }` returns only
`host`, `port` and `tls_timeout`. **Never read a default off `/varz` and conclude the server has
none**; and equally, never conclude from a `/varz` value that the key was configured.

### The sweep confirmed the numbers already recorded

Mechanically re-derived, from the source alone: all nine `tls.timeout` keys at **2s**
(`TLS_TIMEOUT`), all six `authorization.timeout` keys at **2s** (`AUTH_TIMEOUT`, via
`getDefaultAuthTimeout`, `+1` on top of the TLS timeout when TLS is configured),
`jetstream.max_buffered_msgs` at **100000** (`streamDefaultMaxQueueMsgs`) and
`jetstream.info_queue_limit` at **`request_queue_limit`** (10000). Observed on the binary in the same
run: `/varz` reports `auth_timeout: 2` and `tls_timeout: 2` on a server with no TLS and no
authorization block at all.

## Practical takeaways

- **Leafnode links compress by default.** Budget the CPU, or set `compression: off` deliberately —
  the reference will not tell you that you are turning something off.
- **Write every listener port explicitly.** Four blocks publish a default the server does not apply,
  and three of the four fail silently.
- A documented default is worth checking against the server whenever the value would change a sizing
  or a capacity decision — which is what `tools/check-defaults.py` now does for all 216 in one run.

## Relevance to the wiki

Corrects [[config-keys]] (which repeated the docs' `1883` and `100`), extends the listener-port
section to a fourth key, and gives [[leafnode]] its compression default. Feeds
[[defaults-and-limits]].

## Questions it answers

No row in `inbox/question-bank.md` asks any of these directly — nobody asks in public what a
default is, they discover it. What the sweep answers is the standing question the config table
cannot: **whether a published default is the one the server applies**. It also strengthens row 12's
answer ([[defaults-and-limits]]) by saying which values on that page were machine-checked.

## Pages touched

[[config-keys]] · [[defaults-and-limits]] · [[leafnode]]
