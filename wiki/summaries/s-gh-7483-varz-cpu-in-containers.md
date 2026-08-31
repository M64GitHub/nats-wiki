---
title: "gh#7483 — what is /varz cpu relative to, on a 0.25 vCPU container?"
type: summary
area: [monitoring, deploy]
source-url: https://github.com/nats-io/nats-server/discussions/7483
source-path: raw/gh-discussions/gh-7483.md
author: "@NevinDry"
article: "nats-io/nats-server discussion 7483"
date: 2025-10-28
version: ""
tags: [varz, cpu, cores, containers, fargate, unanswered, nats-server-check]
aliases: []
sources: []
created: 2026-09-01
updated: 2026-09-01
---

# gh#7483 — what is /varz cpu relative to, on a 0.25 vCPU container?

The source of question-bank row **Q60**, **closed with zero comments and no answer chosen**. The
question is precise and operationally consequential, and nobody replied.

## Key claims

**The setup**: a healthcheck script built on `nats server check server`, wanting CPU warning and
critical thresholds. "Previously, I was using nproc to detect the number of cores and calculate
thresholds. For example… if I have 2 cores and want a warning threshold at 80%, I might set it as
2 * 80 = 160%."

**The observation**, on an AWS ECS Fargate container allocated **0.25 vCPU**:

```json
{ "cores": 2, "cpu": 10 }
```

"The `"cores": 2` value corresponds to the number of logical CPUs on the **host**, not the vCPU
allocated to my container. This is consistent with nproc, which also shows 2."

**The question**: "Is the `"cpu"` value from VARZ (10 in this example) calculated relative to the
allocated vCPU (0.25) or to the logical cores on the host (2)? This distinction is critical because it
changes how I should calculate CPU thresholds for alerts."

## Practical takeaways

- The answer, from the source, is **neither**: `cpu` is a percentage of **one core**, so `100.0` is one
  core fully consumed ([[s-nats-server-monitoring-observed]]). For this reporter, `cpu: 10` is 0.1 of a
  core — **40 % of their 0.25 vCPU allocation**, not 10 % of anything.
- Their instinct to scale a threshold by core count is right in shape and wrong in input: the scale
  factor is the **container's CPU allocation**, not `cores` and not `nproc`.
- Their observation about `cores` is correct and matches the source: `Varz.Cores` is
  `runtime.NumCPU()`, and nothing in the monitoring or process-stats code consults a cgroup quota.

## Notable quotes

> "This distinction is critical because it changes how I should calculate CPU thresholds for alerts."

## Relevance to the wiki

An operator sizing an alert threshold gets it wrong by the ratio between host cores and container
allocation unless they know what the number means, and no public source says. The answer is on
[[monitoring-endpoints]].

## Questions it answers

Q60 (it *asks* it; the answer comes from the source).

## Pages touched

[[monitoring-endpoints]] · [[jetstream-sizing]]

## Sources

`raw/gh-discussions/gh-7483.md`
