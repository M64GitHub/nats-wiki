---
title: "gh#7749 — Should we use hostPath for a JetStream cluster running in K8S?"
type: summary
area: [deploy, jetstream]
source-url: https://github.com/nats-io/nats-server/discussions/7749
source-path: raw/gh-discussions/gh-7749.md
author: "@royatanu94 (asked); @MILLERMARRU (answered — a community member, not a maintainer)"
article: "GitHub Discussion 7749 (Q&A)"
date: 2026-01-21          # opened; the single reply is 2026-06-27
version: ""               # no server version stated by either participant
tags: [kubernetes, hostPath, PVC, volumeClaimTemplates, storageClassName, statefulset, gp3, raft]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# gh#7749 — hostPath or a PVC for JetStream on Kubernetes

The question behind question-bank row **Q65**, opened 2026-01-21 and left without a reply for five
months. **Read the provenance before quoting it: there is no chosen answer, no maintainer ever
replied, and the one answer is from a community member.** It is nonetheless the only public thread
that puts the question in these words, and its reasoning is checkable against the chart and against
the rest of this wiki.

## Key claims

**The question.** "We are planning to run NATS JetStream cluster on Kubernetes with multiple worker
nodes, where each node may run one or more JetStream pods. Should we use `hostPath` on the worker
nodes when creating PVCs for JetStream containers? If we do, will this impact HA or other JetStream
behaviors?"

**The answer, in one line:** "**Do not use `hostPath` for JetStream in production Kubernetes.**"

**Why, as given:** "`hostPath` binds the JetStream data directory to a specific node. If the pod is
rescheduled to a different node (node drain, node failure, rolling update), the new pod starts on a
different node with no data — effectively losing that server's portion of the stream. In a 3-node
JetStream cluster, losing one server's data means you lose quorum history and need a full resync,
which can be disruptive."

**What to use instead** — "PersistentVolumeClaim (PVC) via StatefulSet — this is the correct pattern
and what the NATS Helm chart uses by default", with the values shown as:

```yaml
nats:
  jetstream:
    enabled: true
    fileStorage:
      enabled: true
      storageClassName: "gp3"   # or your cloud provider's SSD class
      size: "20Gi"
```

"Each StatefulSet pod gets its own PVC via the `volumeClaimTemplates`. When a pod is rescheduled,
Kubernetes reattaches the same PVC to the pod on the new node (for network-attached storage like AWS
EBS, GCP PD, Azure Disk)."

**On storage class:** "For the best throughput, use SSD-backed storage classes (`gp3` on AWS,
`premium-rwo` on GKE). JetStream is write-heavy and benefits significantly from low-latency storage."

**On HA:** "Each of your 3 NATS nodes maintains its own copy of the stream state (RAFT replication).
With PVCs, a node failure means another node takes leadership and the recovered pod rejoins with its
PVC intact — no data loss and no full resync needed."

## What this wiki can and cannot take from it

**Checkable and confirmed elsewhere:** the chart really does provision through `volumeClaimTemplates`
(`raw/github-repos/nats-io__k8s.values-nats-2.14.6.md`, [[s-nats-helm-chart-values-2.14.6]]), and the
consequence of a node losing its store is exactly the shape recorded in
[[stream-directories-disappear]], where the confirmed cause was a `store_dir` that did not survive
the pod.

**Not checkable from this thread:** the `values.yaml` keys are given as `nats.jetstream.fileStorage.*`
— a **path this wiki has not verified against the chart at `nats-2.14.6`**, and the older chart used a
different layout. Treat the shape as illustrative and read the chart's own values file for the
current key names.

**Not stated at all:** any nats-server version, and any measurement. "No full resync needed" is a
claim about Raft catch-up, not a benchmark.

## Practical takeaways

- `hostPath` pins a JetStream replica's data to one node; a rescheduled pod is an **empty** replica,
  not a moved one.
- One PVC per replica through `volumeClaimTemplates` is the pattern the chart implements, and the
  reason is in [[s-k8s-760-jetstream-pvc-per-replica]], not here.
- Pick an SSD-backed storage class. JetStream is write-heavy; see [[jetstream-sizing]] for what
  actually runs out first.

## Relevance to the wiki

The public half of question-bank row **Q65** (★). Paired with [[s-k8s-760-jetstream-pvc-per-replica]],
which supplies the maintainer's reasoning, it is enough to write [[kubernetes-storage]].

## Questions it answers

**Q65** — should JetStream use `hostPath` or a PVC on Kubernetes? **A PVC**, one per replica, on
SSD-backed block storage.

## Pages touched

[[kubernetes-storage]] · [[stream-directories-disappear]] · [[jetstream-sizing]]

## Sources

The thread itself. The chart claim it makes is checked against
[[s-nats-helm-chart-values-2.14.6]]; the storage rationale is in
[[s-k8s-760-jetstream-pvc-per-replica]].
