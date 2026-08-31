---
title: "nats-io/k8s#760 — how to configure JetStream replicas to share a PVC?"
type: summary
area: [deploy, jetstream]
source-url: https://github.com/nats-io/k8s/discussions/760
source-path: raw/gh-discussions/k8s-760.md
author: "@databasedav (asked); @caleblloyd (answered — Helm chart maintainer)"
article: "GitHub Discussion 760 in nats-io/k8s (Q&A)"
date: 2023-07-10
version: ""              # no server or chart version stated
tags: [kubernetes, PVC, volumeClaimTemplates, block-storage, NFS, existingClaim, availability-zone, helm]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# nats-io/k8s#760 — why each JetStream replica gets its own PVC

Asked for a cost reason — "I want to avoid renting multiple cloud disks" — and answered with the
design rationale behind the chart's storage layout. **The one public maintainer statement this wiki
has found on JetStream storage on Kubernetes.** From 2023, and unchanged in the chart since.

## Key claims

**The request.** "The current behavior creates a new pvc per replica, each of which automatically
acquires a separate cloud disk, but I want to avoid renting multiple cloud disks, is there any way to
point all jetstream replicas to a single pvc?"

**It cannot be done through the chart's normal path.** "You can't, to my knowledge, configure multiple
Stateful Set replicas to provision and use a single PVC using `volumeClaimTemplates`. Might be
possible to mount an existing one to multiple replicas, but I wouldn't really recommend that."
(The asker had found `nats.jetstream.fileStorage.existingClaim` in the chart docs and asked whether
that was the lever.)

**The reason, and the sentence worth quoting:**

> "JetStream needs fast block based storage. Should not use NFS or other slow file based storage with
> it. Most fast block based storage in the cloud only works with a single host as a writer."
> — @caleblloyd, 2023-07-11

**And therefore the design is deliberate:** "That is why this chart is designed for each replica to
get it's own PVC. In the cloud ideally 3 replicas will run in 3 different availability zones, and
each replica has exclusive access to a fast block based disk in its availability zone."

**A `hostPath` provisioner is named, but only as the mechanism that would do what the asker wanted**
— "I think you'd want to look for a PV Provisioner that does that for you… Like a Host Path PV
Provisioner." It is not a recommendation for production, and the asker ruled it out immediately
("my hosts have minimal disk + they might be ephemeral"). Read together with
[[s-gh-7749-hostpath-jetstream]], which argues against `hostPath` for a different reason.

## Practical takeaways

- **Three replicas means three disks.** That is the cost of R3, not a chart defect, and there is no
  supported way to collapse it.
- **Do not put a stream's `store_dir` on NFS or any shared file storage.** A maintainer says so
  directly, and this is the only public place he does.
- The chart's intent is one replica per availability zone with exclusive access to a fast local
  block device — which is also why the replicas' fate is independent, the property
  [[replicas]] is buying.
- `existingClaim` exists in the chart but is not the way to share storage between replicas.

## Notable quotes

> "JetStream needs fast block based storage. Should not use NFS or other slow file based storage with
> it."

## Relevance to the wiki

Supplies the *why* behind question-bank row **Q65**, which
[[s-gh-7749-hostpath-jetstream]] answers only operationally. Together they are the sources for
[[kubernetes-storage]]. It is also the first source in this wiki that rules out network file storage
for JetStream in a maintainer's words rather than by inference.

## Questions it answers

**Q65** — the storage-architecture half: one PVC per replica, on block storage, because cloud block
storage takes a single writer.

## Pages touched

[[kubernetes-storage]] · [[replicas]] · [[jetstream-sizing]]

## Sources

The thread itself. The chart behaviour it describes is confirmed at chart release `nats-2.14.6` in
[[s-nats-helm-chart-values-2.14.6]].
