---
title: "gh#5859 — Symptom: Unexpected `nats: timeout`"
type: summary
area: [core, jetstream, deploy, topology]
source-url: https://github.com/nats-io/nats-server/discussions/5859
source-path: raw/gh-discussions/gh-5859.md
author: "@RitikaLaddha and @davidmcote (reporting), @wallyqs (maintainer, responding)"
article: "Symptom: Unexpected `nats: timeout`"
date: 2024-08-28
version: "2.10.18 and 2.10.20"
tags: [timeout, request-reply, gomaxprocs, kubernetes, routes, leafnode, ping, unresolved]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# gh#5859 — Two independent reports of `nats: timeout`, neither closed

The thread behind question-bank **Q77**. **No chosen answer.** Two unrelated deployments, two
maintainer hypotheses, and no confirmation for either — but three of the four things the maintainer
says are checkable facts, and one of them corrects a symptom the reporters were chasing.

## Key claims

**Report 1 — Java on AKS, `2.10.18`, Bitnami chart.** Requests with a 30 s timeout return nothing:

```
java.util.concurrent.CancellationException: Future cancelled, response not registered in time, check connection status.
	at io.nats.client.support.NatsRequestCompletableFuture.cancelTimedOut(NatsRequestCompletableFuture.java:42)
```

The reporter's evidence for a server problem was these two log lines:

```
[DBG] 10.0.6.146:45496 - cid:14 - Client Ping Timer
[DBG] 10.0.6.146:45496 - cid:14 - Delaying PING due to remote client data or ping 48s ago
```

**Those lines are not a symptom** (@wallyqs, 2024-09-27):

> "The Delaying PING message is just part of the periodic ping interval from the server which happens
> every 2 minutes unless there is some recent data being sent (if there was data in the past 2m then it
> will not send the ping thus logging `Delaying PING due to remote client`...)."

**The one concrete server defect found, and it is in the config** (@wallyqs, 2024-08-28):

> "Also the following configuration will not work ok on k8s, you need to add all the A records from
> the statefulset to the config or use the nats-io/k8s helm chart"

against a `routes` block holding a **single** service DNS name:

```
  routes = [
    nats://nats_cluster:paass@nats:6222
  ]
```

with the fix spelled out on 2024-09-04 as one entry per pod:

```
  routes = [
    nats://nats-0.nats_cluster:paass@nats:6222
    nats://nats-1.nats_cluster:paass@nats:6222
    nats://nats-2.nats_cluster:paass@nats:6222
  ]
```

This is the same defect [[s-gh-7190-asymmetric-cluster]] records from the other end: one
multi-valued DNS name as a route address gives nodes unequal route counts and partitions clients.

**Report 2 — a resource-constrained edge topology, `2.10.20`.** `JetStream.publishAsync` failing "a
nontrivial fraction" of the time with the same Java exception, across

```
(app, Java) ---> (leaf1, core NATS) ---> (nats-server, core NATS) <--- (leaf2, JetStream)
```

after upgrading server 2.9.11 → 2.10.20 and jnats 2.16.14 → 2.20.2 together. Raising the
`PublishOptions` response timeout to 5 s did not help.

**The maintainer's hypothesis for report 2** is a single line out of the reporter's own debug log:

```
maxprocs: Updating GOMAXPROCS=1: determined from CPU quota
```

> "I think in your case what may be blocking or causing delays in the server is the `GOMAXPROCS=1`
> setting reported in the logs, do the machines only have one cpu?"

The host has 8 vCPUs; the containers are capped at `cpus: '1.50'`, and the reporter notes that
**not all processes picked the same `GOMAXPROCS` from an identical cgroup limit**. The advice —

> "@davidmcote I think for now you could try to set it to GOMAXPROCS=2"

— is the last message in the thread. No result was ever posted.

**Two useful negatives from report 2.** The reporter's `ConnectionListener`/`ErrorListener` never fired
(so no reconnects, no client-side slow consumers) and `docker stats` never showed the servers at their
CPU limit — meaning the CPU hypothesis was not confirmed by the obvious measurement either.

**A leafnode domain line worth keeping**, from the same debug log:

```
192.168.0.2:54654 - lid_ws:1 - JetStream using domains: local "", remote "myjsdomain"
```

That is the server saying, per leafnode connection, that it is **not** extending JetStream. See
[[streams-not-visible-across-a-leafnode]].

## Practical takeaways

- `nats: timeout` is a **client-side** error: the reply never arrived inside the client's deadline.
  The server does not send it and does not log it, which is why both reporters went hunting through
  server logs and found nothing.
- Distinguish it from `no responders available for request`, which the server *does* produce and which
  means the opposite: nothing was subscribed at all.
- `Delaying PING due to remote client data or ping Ns ago` at DBG is normal. Ruling it out early saves
  the same wasted search twice in this one thread.
- One DNS name in `routes` on Kubernetes is a real, independently attested cluster defect. Check it
  before anything subtler.
- `maxprocs: Updating GOMAXPROCS=N: determined from CPU quota` in the startup log tells you how many
  cores the server thinks it has. A value of 1 under load is worth pinning up even without a
  confirmed causal link — the maintainer suggested it, nobody proved it.

## Relevance to the wiki

The symptom page is [[nats-timeout]]. The strongest server-side cause on that page comes from the
source rather than this thread — the JetStream API queue draining every pending request when
`request_queue_limit` is reached, which produces exactly this symptom and no reply (see
[[s-nats-server-jetstream-log-warnings]]).

## Questions it answers

- **Q77** — what an unexpected `nats: timeout` means and how to trace it. Partially: the thread
  supplies the causes to rule out, not a confirmed fix.

## Pages touched

[[nats-timeout]] · [[build-a-3-node-cluster]] · [[stream-has-high-message-lag]] ·
[[streams-not-visible-across-a-leafnode]] · [[slow-consumer-detected]] · [[js-api]]
