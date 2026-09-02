---
title: JetStream storage on Kubernetes
type: operation
kind: pattern
area: [deploy, jetstream]
since: []
verified-against: nats-server 2.14.6
verified-on: 2026-08-31
tags: [kubernetes, hostPath, PVC, volumeClaimTemplates, storageClassName, statefulset, block-storage, NFS, max_file_store, fileStore]
aliases: [hostPath, hostpath vs pvc, kubernetes storage, jetstream pvc, persistent volume, storageClassName, volumeClaimTemplates, emptyDir]
sources: [s-gh-7749-hostpath-jetstream, s-k8s-760-jetstream-pvc-per-replica, s-nats-helm-chart-values-2.14.6, s-gh-5924-filestore-dirs-vanished, s-nats-server-filestore-layout, s-gh-8001-jetstream-startup-slow-50m, s-nats-server-stream-scale-observed]
created: 2026-08-31
updated: 2026-09-03
---

# JetStream storage on Kubernetes

**One PVC per replica, on SSD-backed block storage, with `max_file_store` set *below* the volume
size.** This page exists because the first two thirds of that sentence are the answer to a question
asked twice in public and the last third is the part nobody says.

## The problem

A JetStream server keeps its whole state — stream blocks, consumer state, the Raft write-ahead log —
under one `store_dir`. On Kubernetes that directory has to survive the pod, and pods move. The choice
is normally posed as **`hostPath` or a PVC**, and it was posed exactly that way in public:

> "We are planning to run NATS JetStream cluster on Kubernetes with multiple worker nodes… Should we
> use `hostPath` on the worker nodes when creating PVCs for JetStream containers? If we do, will this
> impact HA or other JetStream behaviors?" (source: [[s-gh-7749-hostpath-jetstream]])

## The design

**A PVC per replica, through a StatefulSet's `volumeClaimTemplates`.** Each pod gets its own claim
and its own disk; on reschedule Kubernetes reattaches *that* claim to the new pod. Three replicas
means three disks, and there is no supported way to collapse them.

**Why one disk per replica, in a chart maintainer's words:**

> "JetStream needs fast block based storage. Should not use NFS or other slow file based storage with
> it. Most fast block based storage in the cloud only works with a single host as a writer."
> — @caleblloyd, 2023-07-11 (source: [[s-k8s-760-jetstream-pvc-per-replica]])

> "That is why this chart is designed for each replica to get it's own PVC. In the cloud ideally 3
> replicas will run in 3 different availability zones, and each replica has exclusive access to a
> fast block based disk in its availability zone."

That is the same independence [[replicas]] is buying at the NATS layer, expressed at the storage
layer: R3 is only worth its cost while the three copies can fail separately.

**Why not `hostPath`.** It pins a replica's data to one node, so a pod that lands elsewhere — node
drain, node failure, rolling update — starts **empty**:

> "In a 3-node JetStream cluster, losing one server's data means you lose quorum history and need a
> full resync, which can be disruptive." (source: [[s-gh-7749-hostpath-jetstream]])

This wiki has the confirmed version of that failure from a different direction:
[[stream-directories-disappear]], where `store_dir` was backed by storage that did not survive the
pod and the server logged `error opening msg block file` while `nats stream info` still listed every
stream. A maintainer's answer there — "don't rely on RAM disks being anything other than temporary"
— applies to a recycled node's `hostPath` for the same reason
(source: [[s-gh-5924-filestore-dirs-vanished]]).

**The chart does not offer you the choice.** `grep` for `hostPath` and `emptyDir` across all 741
lines of `values.yaml` at chart release **nats-2.14.6** returns nothing. The only storage paths the
chart exposes are a PVC per replica, or `fileStore.pvc.enabled: false`, which leaves `store_dir` on
whatever the pod's filesystem provides (source: [[s-nats-helm-chart-values-2.14.6]]).

## The configuration that implements it

### Helm chart (`nats-2.14.6`)

```yaml
config:
  jetstream:
    enabled: true
    fileStore:
      enabled: true
      dir: /data
      pvc:
        enabled: true
        size: 10Gi
        storageClassName:        # empty -> the cluster's default StorageClass
      maxSize:                   # empty -> max_file_store == pvc.size
    memoryStore:
      enabled: false
```

**Name a `storageClassName`.** Left empty the cluster's default class is used, which on most clusters
is not the fastest one available. SSD-backed classes are what JetStream wants — `gp3` on AWS,
`premium-rwo` on GKE are the examples the public answer gives
(source: [[s-gh-7749-hostpath-jetstream]]).

**Do not trust a `values.yaml` snippet from a search result.** The key path has changed across chart
generations; the answer in gh#7749 writes `nats.jetstream.fileStorage.*`, and the chart at
`nats-2.14.6` uses `config.jetstream.fileStore.*`. Read the chart's own `values.yaml` at the release
you are installing.

### Set `max_file_store` below the volume size

The one change this page argues for beyond the defaults. The chart renders the JetStream block from
`files/config/jetstream.yaml`, and for the file store the whole rule is:

```
{{- if .maxSize }}
max_file_store: << {{ .maxSize }} >>
{{- else if .pvc.enabled }}
max_file_store: << {{ .pvc.size }} >>
{{- end }}
```

So with the defaults a node comes up with **`max_file_store: 10Gi` on a 10Gi volume**
(source: [[s-nats-helm-chart-values-2.14.6]]). That is a ceiling with no margin, and it is unsafe for
a reason that has nothing to do with Kubernetes: **every JetStream storage figure is logical, not
physical.** `max_file_store` is compared against the sum of live message record lengths, while the
files under `store_dir` carry tombstones, half-dead blocks and a last block that is never compacted —
measured at 3.79 MB on disk for a server reporting 3% of a 4MB ceiling used
([[filestore-layout]], `inbox/docs-issues.md` #33). Set `fileStore.maxSize` explicitly, below
`pvc.size`, and size the gap with [[jetstream-sizing]].

### Outside the chart

The same shape by hand: a StatefulSet with `volumeClaimTemplates`, one claim per replica, and a
server config whose `jetstream { store_dir }` points at the mount:

```
jetstream {
  store_dir: "/data"
  max_file_store: 8GB          # deliberately below the 10Gi volume
  max_memory_store: 0
}
```

See [[install-nats-server]] for the rest of the deployment and [[build-a-3-node-cluster]] for the
cluster block.

## Trade-offs and costs

| | one PVC per replica | `hostPath` |
|---|---|---|
| pod rescheduled to another node | claim follows the pod; replica resumes | replica starts **empty**, full resync |
| cost | one cloud disk per replica — three for R3 | none beyond the node |
| latency | network-attached; a hop away | local NVMe, the fastest option available |
| availability zones | one replica per AZ, each with its own disk | replicas pinned to nodes |
| supported by the chart | yes, and it is the only path | **no value exists for it** |

**The cost objection is real and has no supported answer.** "I want to avoid renting multiple cloud
disks" was the whole reason k8s#760 was opened, and the answer was that the chart cannot do it and
mounting one claim into several replicas "I wouldn't really recommend"
(source: [[s-k8s-760-jetstream-pvc-per-replica]]). Three replicas cost three disks.

**Never NFS, never any shared file storage.** The maintainer statement above is the only public one
this wiki has found, and it is unambiguous.

## When *not* to use it

- **Memory streams.** `memoryStore` with `fileStore.pvc.enabled: false` needs no volume at all — but
  the data goes away with the process, which is the supported behaviour, not a workaround
  (source: [[s-gh-5924-filestore-dirs-vanished]]). See [[stream]].
- **A single-node development server.** `hostPath` or an `emptyDir` is fine when losing the store is
  an inconvenience rather than an incident. The argument on this page is about a replicated
  production cluster.
- **A node-local, deliberately ephemeral edge server** — a leaf whose streams are mirrors and whose
  loss is recovered from the hub. Then the disk is a cache, and the [[mirrors-and-sources]] lag is
  your real RPO. Decide that explicitly; do not arrive at it by choosing `hostPath` for cost.

## To verify

- **Whether a `hostPath`-backed replica really cannot be recovered in place** by rescheduling the pod
  back to its original node. Both public sources argue from the mechanism, not from a run, and this
  wiki has not tested it. **(unverified)**
- Whether the chart's `fileStore.pvc.enabled: false` path is ever the intended production
  configuration; the chart says nothing about it.

## A restart reads the stream, and the probe waits for it

The one public report of a multi-minute JetStream restore ran under this chart, on Ceph: a 7 GB
sourcing stream read end to end at 20 MB/s while the readiness probe logged `Healthcheck failed`
every few seconds for 6 min 38 s and the pod stayed not-ready (source:
[[s-gh-8001-jetstream-startup-slow-50m]]). Two things follow for the storage class. The restore
after an unclean stop, and every start of a stream with an idle source on 2.10–2.14, is a
**sequential read of the whole stream on one goroutine** — the volume's single-stream read rate is
what sets the restart window, not its IOPS rating (6.4 s for 6.8 GB on a laptop SSD; source:
[[s-nats-server-stream-scale-observed]]). And the probe is right to fail: `/healthz` answers 503
until the stores are recovered, so `terminationGracePeriodSeconds` and the startup probe's budget
must cover bytes ÷ read rate for the largest stream on the node. The causes and the fixes are on
[[jetstream-recovery-is-slow]].


## Related

[[jetstream-sizing]] · [[filestore-layout]] · [[jetstream-out-of-disk]] ·
[[stream-directories-disappear]] · [[nats-helm-charts]] · [[install-nats-server]] ·
[[build-a-3-node-cluster]] · [[replicas]] · [[upgrade-a-cluster]] · [[stream]] ·
[[mirrors-and-sources]]

## Sources

- [[s-gh-7749-hostpath-jetstream]] — the question, and the only public answer to it. **Not a
  maintainer**; provenance is on the summary.
- [[s-k8s-760-jetstream-pvc-per-replica]] — the chart maintainer's rationale: fast block storage,
  single writer, one PVC per replica.
- [[s-nats-helm-chart-values-2.14.6]] — the chart at `nats-2.14.6`: the storage block, the absent
  `hostPath`, and `max_file_store` rendered equal to the PVC size.
- [[s-gh-5924-filestore-dirs-vanished]] — what a `store_dir` that does not survive the pod looks like
  when it happens.
- [[s-nats-server-filestore-layout]] — why the ceiling must sit below the volume. · [[s-gh-8001-jetstream-startup-slow-50m]] · [[s-nats-server-stream-scale-observed]]
