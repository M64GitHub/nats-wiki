---
title: NATS Helm charts (nats-io/k8s)
type: entity
kind: tool
area: [deploy, jetstream, monitoring]
verified-against: nats-io/k8s chart nats-2.14.6
verified-on: 2026-08-31
tags: [tool, helm, kubernetes, statefulset, probes, config-reloader, artifacthub]
aliases: [k8s, "nats-io/k8s", helm chart, nats helm chart, nats-helm-charts]
sources: [s-docs-ecosystem, s-github-repo-facts, s-docs-kubernetes]
created: 2026-08-31
updated: 2026-08-31
---

# NATS Helm charts (nats-io/k8s)

**The official way to run `nats-server` on Kubernetes.** One chart renders the StatefulSet, the
headless and ClusterIP services, the ConfigMap, the three `/healthz` probes and the config-reloader
sidecar (source: [[s-docs-kubernetes]]).

## Where it fits

The deployment surface for everything else in this wiki: [[replicas]], [[jetstream-sizing]] and
[[monitoring-endpoints]] all land in this chart's `values.yaml` when the target is Kubernetes.

## Facts

| | |
|---|---|
| repo | `nats-io/k8s` |
| latest release | **`nats-2.14.6`**, 2026-08-28 — **the chart tag tracks the server version** |
| licence | Apache-2.0 |
| charts | `nats`, `surveyor` ([[nats-surveyor]]), `nack` ([[nack]]) |
| repo URL | `https://nats-io.github.io/k8s/helm/charts/` |
| also published to | Artifact Hub, `helm/nats/nats` |
| requires | Helm 3 |

```
helm repo add nats https://nats-io.github.io/k8s/helm/charts/
helm repo update
helm install nats nats/nats -f values.yaml
```

**The release name names the pods**: `helm install nats …` gives `nats-0`, `nats-1`, `nats-2`.

## What an operator needs to know

- **It must be a StatefulSet, and the chart knows why.** Node identity has to survive a restart —
  `nats-1` must come back as `nats-1` with its volume. A Deployment cannot promise that.
- **`podManagementPolicy: Parallel` is already set — do not "fix" it.** The ordered default waits for
  each pod to be ready before starting the next, "and that **deadlocks a NATS cluster**, because no
  single node is ready until it can see its peers". This is the classic failure of a hand-rolled
  StatefulSet.
- **Clients dial the ClusterIP service `nats`, not the headless one.** The headless service exists so
  nodes can route to each other by stable DNS
  (`nats-0.nats-headless.default.svc.cluster.local`); the ClusterIP service is the one readiness
  pulls a bad pod out of.
- **The readiness probe is deliberately shallow** (`/healthz?js-server-only=true`), so **a pod still
  catching up its R3 replicas reports ready and serves clients**. The strict `/healthz` is on the
  *startup* probe with `failureThreshold: 90` (~900 s). To widen that, "override the probe fields
  through the chart's container `merge`/`patch`; there's **no named `failureThreshold` value**".
- **The config-reloader sidecar is what makes a ConfigMap edit take effect.** `nats-server` reloads
  on SIGHUP; the `nats-server-config-reloader` container (enabled by default) sends it. Without it a
  config change "sits inert until the pod restarts".
- **A pod stuck `Pending` is almost always an unbound volume**, not a NATS problem — the chart
  provisions through `volumeClaimTemplates`, so check for a default storage class rather than
  deleting the pod.

## Cheat sheet

```yaml
# values.yaml — a three-node JetStream cluster on a 10Gi volume per pod
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

```
helm repo add nats https://nats-io.github.io/k8s/helm/charts/
helm install nats nats/nats -f values.yaml
helm upgrade  nats nats/nats -f values.yaml
kubectl get pods -l app.kubernetes.io/name=nats
kubectl exec -it deploy/nats-box -- sh          # then: nats stream info ORDERS
```

**The probes the chart renders** (for reference — you do not write these):

```yaml
startupProbe:   { httpGet: { path: /healthz,                        port: 8222 }, failureThreshold: 90 }
readinessProbe: { httpGet: { path: "/healthz?js-server-only=true",  port: 8222 } }
livenessProbe:  { httpGet: { path: "/healthz?js-enabled-only=true", port: 8222 } }
```

## Related

[[nack]] · [[nats-box]] · [[nats-surveyor]] · [[monitoring-endpoints]] · [[replicas]] ·
[[jetstream-sizing]] · [[nats-server]] · [[build-a-3-node-cluster]]

## Sources

[[s-docs-ecosystem]] · [[s-github-repo-facts]] · [[s-docs-kubernetes]]
