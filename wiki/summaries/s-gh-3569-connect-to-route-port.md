---
title: "gh#3569 — ERR Log \"attempted to connect to route port\""
type: summary
area: [topology, core, deploy]
source-url: https://github.com/nats-io/nats-server/discussions/3569
source-path: raw/gh-discussions/gh-3569.md
author: "@hufan-ola (asking), @Jarema (maintainer, answering)"
article: "ERR Log \"attempted to connect to route port\""
date: 2022-10-18
version: "2.9"
tags: [routes, route-port, 6222, client-port, log-lines, leafnode]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# gh#3569 — ERR Log "attempted to connect to route port"

A one-exchange thread with an **accepted answer**, and the cheapest possible worked example of the
client-port/route-port confusion: a client pointed at `6222`.

## Key claims

**The symptom** — a `nats sub` aimed at the cluster port works *and* logs an error:

```
nats sub foo -s nats://192.168.0.3:6222

[15355] 2022/10/18 11:30:00.638646 [ERR] 192.168.0.3:57824 - rid:10 - attempted to connect to route port
```

The reporter's configs use `listen: …:4222` / `cluster { listen: …:6222 }` on one server and
`…:4223` / `…:6223` with `routes = [ nats-route://192.168.0.3:6222 ]` on the other.

**The accepted answer** (@Jarema, a NATS maintainer, same day):

> "`cluster` routes are meant to be used only for other nodes (servers) to connect and form a
> cluster. Clients should connect to the listen URL of one of the nodes. In your example it's
> `192.168.0.3:4222`."

with two more points in the same answer:

> "Keep in mind that your cluster should have at least 3 nodes."

and that a hub/spoke ("master/slave") shape wants **leafnodes**, not routes.

**The `rid:` prefix** in the log line is the route connection id — the server logged the client as a
route connection because it arrived on the route listener.

## Practical takeaways

- **`attempted to connect to route port` is a client-side mistake with a server-side log line.** The
  error names exactly what happened and is the fastest confirmation that a connection string carries
  the wrong port.
- **The confusion runs both ways, and only one direction is loud.** A *client* on the route port logs
  this error; a *route* on the client port ([[s-docs-forming-a-cluster]] calls that "half of
  cluster-formation bugs") logs nothing useful and simply never forms the mesh.
- **The subscribe appearing to work is a trap.** The reporter says "subscribe **can receive**
  message" — so the symptom is a log line and a wrong topology, not a failure the application sees.
- **Two nodes is not a cluster to build on**, per the same answer, and the hub/spoke shape is a
  leafnode question ([[leafnode]]).

## Notable quotes

> "`cluster` routes are meant to be used only for other nodes (servers) to connect and form a
> cluster." — @Jarema

## Relevance to the wiki

The port pitfall in [[build-a-3-node-cluster]], stated from both ends rather than one.

## Questions it answers

**Q92** (added with this ingest).

## Pages touched

[[build-a-3-node-cluster]] · [[install-nats-server]]
