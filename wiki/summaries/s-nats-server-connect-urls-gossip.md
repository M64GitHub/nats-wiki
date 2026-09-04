---
title: "nats-server 2.14.6 — connect_urls is fed by routes, and by nothing else"
type: summary
area: [topology, core, clients]
source-url: https://github.com/nats-io/nats-server/blob/v2.14.6/server/route.go
source-path: raw/nats-server-src/client-connect-urls-v2.14.6.md
author: nats-io/nats-server
article: "server.go's connect-URL helpers and their three call sites in route.go"
date: 2026-09-04
version: "2.14"
tags: [gossip, connect_urls, discovery, gateway, supercluster, no_advertise, failover]
aliases: [connect_urls, discovered servers, cross-cluster failover, supercluster client discovery]
sources: [s-nats-server-client-lifecycle-observed, s-docs-resilient-clients-connecting]
created: 2026-09-04
updated: 2026-09-04
---

# nats-server 2.14.6 — `connect_urls` is fed by routes, and by nothing else

Question-bank row 156 asks whether a client discovers the other clusters of a supercluster
([gh#7328](https://github.com/nats-io/nats-server/discussions/7328)). One grep settles it.

## Key claims

- **Two helpers rewrite the `INFO` a client sees**: `addConnectURLsAndSendINFOToClients` and
  `removeConnectURLsAndSendINFOToClients` (`server/server.go:3610–3630`), both wrapping
  `updateServerINFOAndSendINFOToClients`, whose comment is "If there was a change, an INFO protocol is
  sent to registered clients that support async INFO protocols."
- **They have exactly three call sites in the whole `server/` package, and all three are in
  `route.go`**: `:2389` when a route's `INFO` arrives (`s.addConnectURLsAndSendINFOToClients(info.ClientConnectURLs, info.WSConnectURLs)`),
  `:728` when the remote enters lame duck mode, and `:3205` when the last route to a remote closes.
  **`gateway.go` and `leafnode.go` call neither.**
- **All three are gated on `!opts.Cluster.NoAdvertise`** — `cluster { no_advertise: true }` turns the
  whole mechanism off, which is why a deployment behind a load balancer sets it.
- **A gateway carries interest and messages, not addresses.** The line immediately above the first
  call site, `s.sendGatewayConfigsToRoute(c)`, sends gateway configuration *to a route*, not to
  clients.
- Therefore **a client learns its own cluster's members and nothing more**. If its whole cluster goes
  away, its pool empties and the connection closes — while the supercluster is still up, in a cluster
  the client was never told about.

## Practical takeaways

- **Cross-cluster client failover is a configuration you write**, not a property of the topology: list
  the other cluster's seeds in the client's URL set, or put one health-checked name in front of both
  and set `no_advertise: true` so gossip does not undo it.
- **Randomised pools already spread a fleet** across whatever you list, so listing both clusters is
  usually enough — at the cost that a client may sit in the far cluster after a blip
  ([[client-connection-lifecycle]]).
- **Reaching a stream in the other cluster is a separate question** — domains and mirrors, not
  connections ([[jetstream-domain]]).

## Notable quotes

> "Since this is the last route for this remote, possibly update the client connect URLs and send an
> update to connected clients." — `route.go:3201–3203`

## Relevance to the wiki

It converts "the docs never say" into a settled negative, with the grep that proves it, and it gives
[[gateway]] the client-facing paragraph it lacked.

## Questions it answers

156.

## Pages touched

[[gateway]] · [[how-clients-reach-a-cluster]] · [[client-connection-lifecycle]]

## Sources

[[s-nats-server-client-lifecycle-observed]] · [[s-docs-resilient-clients-connecting]]
