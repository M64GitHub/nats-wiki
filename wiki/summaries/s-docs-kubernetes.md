---
title: "docs.nats.io — Kubernetes"
type: summary
area: [deploy, jetstream, topology]
source-url: https://docs.nats.io/learn/deployment/kubernetes.md
source-path: raw/nats-docs/learn/deployment/kubernetes.md
author: NATS documentation (Synadia Communications, Inc.)
article: Kubernetes
date: 2026-08-31          # the page is undated; this is the fetch date
version: "2.14"
tags: [kubernetes, helm, statefulset, healthz, probes, nack, crd, config-reloader]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# docs.nats.io — Kubernetes

The Helm chart and the NACK controller, with the probe wiring and the four traps that catch teams
the first time. The most operationally dense page in the deployment chapter.

## Key claims

**A NATS cluster must be a StatefulSet, not a Deployment.** "Each node owns a slice of the R3 stream
on its own disk, and node identity has to survive a restart: `nats-1` must come back as `nats-1`,
with its volume, not as a fresh replica." Pods are named by ordinal — `nats-0`, `nats-1`, `nats-2`.

**Install:**

```
helm repo add nats https://nats-io.github.io/k8s/helm/charts/
helm install nats nats/nats -f values.yaml
```

```yaml
# values.yaml — a three-node JetStream cluster
config:
  cluster:
    enabled: true
    replicas: 3
  jetstream:
    enabled: true
    fileStore:
      pvc:
        size: 10Gi
```

The release name is what names the pods: `helm install nats …` yields `nats-0..2`.

**The chart already sets `podManagementPolicy: Parallel`** — "don't add it to `values.yaml`". Why it
matters: "the ordered default would wait for each pod to become ready before starting the next, and
that **deadlocks a NATS cluster**, because no single node is ready until it can see its peers."

**Two services.** A **headless** service gives each pod a stable DNS name
(`nats-0.nats-headless.default.svc.cluster.local`) used for routing between nodes; a regular
**ClusterIP** service named `nats` is what clients dial — "the one readiness pulls a not-ready pod
out of".

**Three probes, all on the monitor port 8222**, rendered by the chart:

```yaml
startupProbe:   { httpGet: { path: /healthz,                       port: 8222 }, failureThreshold: 90 }
readinessProbe: { httpGet: { path: "/healthz?js-server-only=true", port: 8222 } }
livenessProbe:  { httpGet: { path: "/healthz?js-enabled-only=true", port: 8222 } }
```

- **startup** — the strict `/healthz` (meta layer plus every stream and consumer asset);
  `failureThreshold: 90` is "~900s window for the node to boot + sync".
- **readiness** — `js-server-only=true` "checks only that the server and its JetStream subsystem are
  up — it deliberately skips every stream, consumer, and meta-assignment check". Consequence, stated
  plainly: **"a pod catching its R3 replicas up after a restart still reports ready and keeps
  serving clients."**
- **liveness** — `js-enabled-only=true`, "the last resort that restarts a truly wedged process".
- To widen the startup window, "override the probe fields through the chart's container
  `merge`/`patch`; there's **no named `failureThreshold` value**".

**NACK declares JetStream assets as CRDs**, `apiVersion: jetstream.nats.io/v1beta2`, kinds `Stream`
and `Consumer`:

```yaml
apiVersion: jetstream.nats.io/v1beta2
kind: Stream
metadata:
  name: orders
spec:
  name: ORDERS
  subjects: ["orders.>"]
  storage: file
  replicas: 3
```

`kubectl apply -f …`, and "the controller watches the CRD, calls the JetStream API on the cluster …
and writes the result back into the resource's `.status`."

**Four pitfalls:**

1. **"A pod stuck Pending is usually an unbound volume."** With no default storage class the claim
   hangs forever and `nats-0` blocks the whole cluster. "The fix when a pod hangs is to confirm a
   storage class exists, not to delete and retry the pod."
2. **"A ConfigMap edit does not reload the server by itself."** The running server keeps its old
   config "until something sends it a SIGHUP". The chart ships the **`nats-server-config-reloader`
   sidecar, enabled by default**, to do that; "without it, a config change sits inert until the pod
   restarts".
3. **"Replica catch-up shows up in the startup probe, not readiness"** — the readiness consequence
   above.
4. **"Never mix CLI and CRD management of the same stream."** By default NACK "re-creates a stream
   that's been deleted (it notices on its **~30-second resync**), yet it does *not* revert a manual
   `nats stream edit`: a config change sticks until the CRD itself next changes." Run with
   **`--control-loop`** and it "also enforces config drift, reverting manual edits on about a
   **one-minute cycle**". Either way, "pick one owner per stream".

**Verification is `nats stream info ORDERS` from the `nats-box` pod** (`kubectl exec -it
deploy/nats-box -- sh`); the line that matters is `Replicas: 3`.

## Practical takeaways

- **The readiness probe is deliberately shallow, and that is a design decision you inherit.** A pod
  serving clients while its replicas are still catching up is the documented behaviour, not a bug —
  if that is unacceptable, the probe is yours to change.
- **`podManagementPolicy: Parallel` explains a class of "cluster never forms" reports** on
  hand-rolled StatefulSets that copy a generic template.
- **The 30-second resync vs one-minute control loop is the whole difference** between "NACK protects
  against deletion" and "NACK owns the config".

## Notable quotes

> "The ordered default would wait for each pod to become ready before starting the next, and that
> deadlocks a NATS cluster, because no single node is ready until it can see its peers."

## Relevance to the wiki

Everything on [[nats-helm-charts]] and [[nack]], and the Kubernetes surface of the wanted runbooks
[[install-nats-server]] and [[build-a-3-node-cluster]].

## Questions it answers

Q65 partly (the chart provisions PVCs through `volumeClaimTemplates` by default; the page never
compares against `hostPath`, so the row stays open).

## Pages touched

[[nats-helm-charts]] · [[nack]] · [[nats-box]] · [[nats-cli]] · [[monitoring-endpoints]] ·
[[replicas]]
