---
title: "gh#6892 — How to handle system failures caused by hardware issues in NATS clusters"
type: summary
area: [topology, deploy, core]
source-url: https://github.com/nats-io/nats-server/discussions/6892
source-path: raw/gh-discussions/gh-6892.md
author: "@lightwinglc (asked); nobody answered"
article: "GitHub Discussion 6892 (Q&A)"
date: 2025-05-14
version: ""              # no server version stated
tags: [hardware-failure, sick-node, slow-consumer, kick, lame-duck, peer-remove, unanswered]
aliases: []
sources: []
created: 2026-09-01
updated: 2026-09-01
---

# gh#6892 — evicting a sick-but-not-dead server and its clients

Opened 2025-05-14 in Q&A; **zero comments and no answer** when fetched on 2026-09-01. Short, and the
question is precise.

## The report

A host running a NATS server and an application suffers a hardware fault: CPU at 100 %, nobody can
log in, and the monitoring system cannot kill the process. The *other* servers' logs show the faulty
server "was removed from the cluster due to a 'slow consumer'" — its routes were closed. Yet
"external service consumers still report system slowness until the host completely crashes after
10+ minutes, after which they report normal operation."

The question: "Is there an API interface that can remove both the NATS service and its client
connections associated with a specific IP from the cluster?"

## What the thread establishes

Only the shape of the problem, which is the useful part: a server can be **out of the route mesh**
(the healthy peers dropped it as a slow consumer) and still **holding its clients**, who keep trying
to use it because from their side the TCP connection is alive. Nothing about the server's health is
visible to a client until the server stops answering pings or closes the socket. The 10-plus minutes
are the time until the host died.

## Practical takeaways

Assembled from the server source and a run, not from the thread
([[s-nats-server-kick-ldm-mqtt-session]], [[s-nats-server-jetstream-cluster]]):

- **There is no request that removes a server *and* its clients from outside.** The two per-client
  requests that exist — `$SYS.REQ.SERVER.<id>.KICK` and `$SYS.REQ.SERVER.<id>.LDM`, both
  `{"cid": <n>}` — are served **by the sick server itself**, so they help only while it can still
  process system-account traffic.
- **What can be done from outside**: take its JetStream assets away (`nats server cluster
  peer-remove`, which the healthy meta leader executes), and have the platform kill it — on
  Kubernetes the liveness probe does this; on a host, the watchdog does.
- **The clients are the other half of the answer**: they leave a stalled server on their own ping
  timeout, not when the cluster notices. See [[evict-a-sick-server]].

## Relevance to the wiki

The question behind [[evict-a-sick-server]], and the reason [[meta-layer]] records what a
peer-remove does to a running server.

## Questions it answers

- **Q40** — *How do I evict a sick-but-not-dead node (and its clients) from a cluster during a
  hardware failure?* Not answered in public; the wiki's answer is assembled from the source and a
  run and says which part cannot be done from outside.

## Pages touched

[[evict-a-sick-server]] · [[meta-layer]] · [[slow-consumer-detected]]
