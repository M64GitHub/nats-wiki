---
title: "ADR-40 — the NATS connection"
type: summary
area: [core, clients, deploy]
source-url: https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-40.md
source-path: raw/adr/ADR-40.md
author: "@Jarema, @aricart, @piotrpio"
article: ADR-40 NATS Connection
date: 2023-10-12
version: "2.10"
tags: [connection, info, connect, discovery, connect_urls, reconnect, tls-first, ping, docs-issue-31]
aliases: [ADR-40, NATS Connection, server discovery, connect_urls]
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# ADR-40 — what every client must do, and the one part an operator owns

The cross-client specification for connecting, reconnecting and discovering the rest of a cluster.
Four revisions between 2023-10-12 and 2025-11-05, status **Implemented**. Most of it is client
behaviour and out of this wiki's scope; the parts kept here are the ones an **operator** can change
or observe from the server side, plus the client defaults that decide what a cluster looks like
during a failure.

## Key claims

### The handshake, and the two TLS orders

Plain: connect → server sends `INFO` → client sends `CONNECT` → `PING`/`PONG` keeps it alive.

TLS has two flows. **Standard (explicit) TLS**: `INFO` arrives in the clear, the client upgrades if
`tls_required` is set, then `CONNECT`. **TLS-first (implicit)**: the handshake happens before any
protocol byte, and `INFO` arrives inside the tunnel — "available since NATS Server 2.10.4", and it
needs both `handshake_first` in the server's `tls` block **and** `tls_first` on the client. See
[[tls-in-nats]] for the server side and the fallback.

"If clients set `protocol` field in CONNECT to equal or greater than 1, Server can send subsequent
INFO on an ongoing connection" — this is what makes live topology updates possible at all.

### Server discovery, in two paragraphs and a TODO

"When Server sends back INFO. It may contain additional URLs to which the client can make connection
attempts. The client should store those URLs and use them in the Reconnection Strategy."

"A client should have an option to turn off using advertised URLs. By default, those URLs are used."

That is the entire specification, followed by `**TODO**: Add more in-depth explanation how topology
discovery works` — so what a server actually advertises is nowhere in public prose. It was therefore
observed directly, on 2.14.6
(`raw/nats-server-src/compression-purge-discovery-observed-v2.14.6.md`):

- a **standalone** server sends no `connect_urls` at all;
- a **clustered** server sends its own client URL *and* every peer URL it has learned over the
  routes, resolved to the host's routable address — not to `0.0.0.0` and not to what `listen` says;
- `cluster { no_advertise: true }` on one node removes that node from **every** node's list, because
  it stops the server sending its client URLs over the route (`route.go:2764`) as well as
  suppressing its own (`server.go:4596`);
- `client_advertise: "<host>:<port>"` replaces that node's URL everywhere in the cluster, verbatim
  and unresolved.

### The reconnect algorithm clients are expected to share

1. "Immediate reconnect attempt" on detecting the loss.
2. Then "exponential backoff with jitter … Default Jitter should also be included to avoid
   thundering herd problems."
3. "If the Server returned additional URLs, the client should try reconnecting in random order to
   each Server on the list, unless randomization option is disabled."
4. "Successful reconnect resets the timers."
5. "Upon reconnection, clients should resubscribe to all created subscriptions."

Disconnection is detected two ways: missing two consecutive `PONG`s, or an error from the socket.

### The client defaults that shape a failure

| option | ADR default | why an operator cares |
|---|---|---|
| Ping interval | **2 minutes** | the upper bound on how long a client keeps writing into a dead socket |
| Max pings out | **2** | so detection takes up to ~2 ping intervals, not one |
| Connection timeout | **5s** | how long an initial connect can hang |
| Retry on failed initial connect | **false** | a client that starts before the cluster does exits with an error |
| Max reconnects | stated as `3 / none` | see *What the ADR gets wrong* |
| Ignore advertised servers | **false** | discovery is on unless someone turned it off |
| Retain servers order | **false** | the seed list is shuffled, which is what spreads clients across a cluster |
| TLS required | **false** | `tls://` in the URL also forces it |

"Shorter PING intervals can improve responsiveness of the client to network issues, but it also
increases the load on the whole NATS system and the network itself with each added client."

On max reconnects: "This is useful for preventing `zombie services` from endlessly reaching the
servers, but it can also be a footgun and surprise for users who do not expect that the client can
give up entirely."

### Later revisions: the escape hatches

Revision 4 (2025-11-05) adds a **custom server pool** (`SetServerPool`, replacing the pool including
advertised servers), a **reconnect-to-specific-server** callback, and an **on-demand reconnect**
"useful for refreshing auth or rebalancing clients". "By default, advertised servers are merged with
the provided pool."

Also specified: a **disconnect buffer** that holds publishes while disconnected and returns an error
once full.

## What the ADR gets wrong

- **Max reconnects has no readable default.** The text is `**default: 3 / none` — an unclosed bold
  marker and two values with nothing saying which client uses which. A client-visible default that
  can silently end a service's connectivity deserves a number.
- **Server discovery is a TODO in an ADR marked *Implemented*.** Two `**TODO**` markers and the
  truncated sentence "**Note**: Server will send back the info only" sit in the section that decides
  whether clients can reach a cluster at all. Recorded as docs issue #31.

## Practical takeaways

- **Seed URLs and discovery are not alternatives.** The seed list is what the client uses to reach
  *someone*; `connect_urls` is what it learns once connected. Both matter, and the second is the one
  an operator can break from the server config.
- **Anywhere a client cannot route to what the server advertises — Kubernetes behind a LoadBalancer,
  NAT, a leaf on the far side of a firewall — the fix is `client_advertise` or
  `no_advertise`,** not client-side hacks. See [[how-clients-reach-a-cluster]].
- **Expect ~4 minutes of silence before a client with default settings notices a dead server**
  (2 minute ping interval x 2 missed pongs), unless the socket errors first.
- **Reconnect storms are bounded by client defaults you do not control**; jitter and shuffling are
  specified, but a cluster that loses a node still sees every one of its clients arrive at the
  survivors at once.

## Relevance to the wiki

The specification behind [[how-clients-reach-a-cluster]], the client-side half of [[tls-in-nats]]'s
TLS-first section, and the reason a rolling restart looks the way it does in
[[upgrade-a-cluster]].

## Questions it answers

Q67 (LoadBalancer or seed URLs on Kubernetes), answered by [[how-clients-reach-a-cluster]].

## Pages touched

[[how-clients-reach-a-cluster]] · [[tls-in-nats]] · [[build-a-3-node-cluster]] ·
[[upgrade-a-cluster]]
