---
title: "docs.nats.io — Single server"
type: summary
area: [core, deploy, jetstream]
source-url: https://docs.nats.io/learn/topologies/single-server.md
source-path: raw/nats-docs/learn/topologies/single-server.md
author: NATS documentation (Synadia Communications, Inc.)
article: Single server
date: 2026-08-31          # the page is undated; this is the fetch date
version: "2.14"
tags: [single-server, dev-server, http_port, store_dir, edge, replicas, 10074]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# docs.nats.io — Single server

The one-process deployment: the smallest config worth writing, the three jobs one server is
genuinely right for, and the two limits that force a cluster. Short, but it is the only source that
states the **minimum production-shaped config file** and the error you get for asking a standalone
server for replicas.

## Key claims

**The dev-server config** — four settings, each earning its place:

```
# n1.conf — the development server
server_name: n1
port: 4222
http_port: 8222

jetstream {
  store_dir: "./js/n1"
}
```

- `server_name: n1` — "a human-readable name for this server … so that the logs and monitoring
  endpoints identify it clearly".
- `port: 4222` — "the NATS default; it's written out here so the client address is explicit".
- `http_port: 8222` — **"turns on the monitoring endpoint, as it's off by default."** The docs'
  advice is to "enable it at `8222` from the start so `n1` is observable".
- `jetstream { store_dir: … }` — "turns JetStream on and gives it a `store_dir` to write to".

**Start and check:**

```
nats-server -c n1.conf
nats server check connection --server nats://localhost:4222
```

"The server logs that it's listening on `4222` for clients and `8222` for monitoring." A healthy
server answers the check with OK.

**Prove it end to end** with a subscriber and a publisher on the same server:

```
nats sub "orders.>" --server nats://localhost:4222
nats pub orders.created '{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}' --server nats://localhost:4222
```

```
[#1] Received on "orders.created"
{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}
```

**Three jobs one server is right for**, stated as "the correct amount of infrastructure rather than
a compromise":

1. **Development** — a laptop or a CI run, "nothing to coordinate and nothing to wait for".
2. **On the device itself** — "a car, a factory machine, a point-of-sale terminal — or embedded
   in-process inside another application. Each gets a full local NATS with no fleet to operate." Such
   a server "often later dials out to a central system as a leaf node".
3. **A small, single-instance service** — with the argument spelled out: "That service is the least
   available part of the feature, so clustering NATS behind it raises the broker's uptime but not the
   feature's: the service still fails first."

**The two limits.** *Availability*: "If that process dies, or the machine it runs on reboots, every
client loses its connection at once. There's no server to fail over to." *Capacity*: a single server
"scales **vertically** … but every machine has a ceiling".

**The durability sentence worth quoting exactly:** JetStream on one server "stores the ORDERS stream
on disk so messages survive a restart of the process, but they still live on one machine. Lose that
disk and you lose the stream. **One server gives you durability against a crash, never against the
loss of the server itself.**"

**The pitfall — R3 on one server is refused, not degraded:**

```
nats stream add ORDERS --subjects 'orders.*' --storage file --replicas 3 --defaults
```

> The server answers `replicas > 1 not supported in non-clustered mode`.

"Don't treat that error as a config typo to override." On one server, ask for `--replicas 1`.

## Practical takeaways

- **The monitoring port being off by default is the single most consequential default on this page.**
  Every monitoring, health-check and probe page in the docs assumes `8222` is up; nothing turns it on
  for you. See [[monitoring-endpoints]].
- **The error text is a documented API error, not a CLI message.** `raw/nats-docs/reference/jetstream/errors.md:178`
  gives it as `10074 JSStreamReplicasNotSupportedErr`, HTTP 500, description
  `replicas > 1 not supported in non-clustered mode` — so it can be matched on the number, per
  [[error-codes]].
- The page's framing of the third case (**the broker is not the least-available component**) is the
  most useful sizing argument in the deployment chapter, and it belongs in any "should we cluster?"
  conversation.

## Notable quotes

> "One server gives you durability against a crash, never against the loss of the server itself."

> "That service is the least available part of the feature, so clustering NATS behind it raises the
> broker's uptime but not the feature's: the service still fails first."

## Relevance to the wiki

The base config and the verification commands for [[install-nats-server]], and the reason
[[build-a-3-node-cluster]] exists at all.

## Questions it answers

Contributes to Q40 (what one server can and cannot survive). Answers nothing outright on its own.

## Pages touched

[[install-nats-server]] · [[build-a-3-node-cluster]] · [[replicas]] · [[error-codes]] ·
[[monitoring-endpoints]] · [[nats-cli]]
