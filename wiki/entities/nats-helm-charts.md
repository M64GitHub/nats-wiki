---
title: NATS Helm charts (nats-io/k8s)
type: entity
kind: tool
area: [deploy, jetstream, monitoring]
verified-against: nats-io/k8s chart nats-2.14.6
verified-on: 2026-08-31
tags: [tool, helm, kubernetes, statefulset, probes, config-reloader, artifacthub]
aliases: [k8s, "nats-io/k8s", helm chart, nats helm chart, nats-helm-charts]
sources: [s-nats-helm-chart-values-2.14.6, s-docs-rolling-upgrades, s-docs-ecosystem, s-github-repo-facts, s-docs-kubernetes, s-docs-hardening, s-docs-config-management, s-docs-prometheus-and-dashboards, s-gh-7190-asymmetric-cluster]
created: 2026-08-31
updated: 2026-09-01
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
- **The lame-duck defaults leave zero slack, by construction.** The chart sets
  `config.lameDuckGracePeriod: 10s`, `config.lameDuckDuration: 30s` and
  `podTemplate.terminationGracePeriodSeconds: 60` — and its own comment says the last "should be at
  least `lameDuckGracePeriod` + `lameDuckDuration` + 20s shutdown overhead", which 10 + 30 + 20
  satisfies **exactly**. Raise the duration without raising the termination grace period and the
  kubelet's SIGKILL lands inside the drain. Note `30s` is the server's documented *minimum* and a
  third of its own `2m` default (source: [[s-nats-helm-chart-values-2.14.6]]).
- **The reloader only watches volumes mounted under `/etc/`** (`reloader.natsVolumeMountPrefixes`).
  A certificate or config mounted elsewhere never triggers a SIGHUP, and the symptom is
  "reload doesn't work" rather than anything mount-shaped ([[reload-server-config]]).
- **Client discovery is off by default: the chart sets `config.cluster.noAdvertise: true`.** The
  pods never gossip their client URLs, so a client is told about no server other than the one the
  Service gave it — correct, because pod IPs are useless to a client arriving through a Service or a
  load balancer, and the chart's own comment says "If clients are behind a load balancer it is best
  to leave this as is". The client Service has **no `type` field** in the chart at all, so it is a
  plain ClusterIP; there is no `LoadBalancer` or `NodePort` value, and the only ingress in the chart
  is for WebSocket. External clients therefore need a per-pod address and `client_advertise` — the
  chart defines no `advertise` section of its own (source: [[s-nats-helm-chart-values-2.14.6]]).
  See [[how-clients-reach-a-cluster]].
- **Never bind the monitoring port to loopback in this chart.** `http: "127.0.0.1:8222"` is the
  standard host-level hardening answer and on Kubernetes it is an outage: "the kubelet's startup,
  readiness, and liveness probes connect to the pod's IP, not its loopback, so a `127.0.0.1` bind
  fails every probe and the pods never go ready". Keep the chart's default bind and restrict the port
  with a NetworkPolicy instead (source: [[s-docs-hardening]]; [[monitoring-endpoints]]).
- **What the reloader actually does, and its two limits.** It watches the mounted config file with
  **inotify**, reads the server PID from **`/var/run/nats/nats.pid`** and sends SIGHUP, retrying
  **30 times four seconds apart** if the server is briefly unreachable. Where inotify is unavailable
  it needs `--force-poll`, added through **`reloader.merge` — which replaces the container's args
  wholesale**, so the chart's own args have to be repeated alongside it
  (source: [[s-docs-config-management]]). Together with the `/etc/` prefix rule above, these are the
  two ways "reload doesn't work" on Kubernetes turns out not to be a server problem.
- **The chart renames the JetStream metrics, and your dashboards depend on it.**
  [[prometheus-nats-exporter]] emits the JetStream collector under the prefix `jetstream_` by default;
  `-prefix nats` renames it to `nats_`, "the same rename the NATS Helm chart applies". Community
  dashboards and anything built against a Helm-deployed cluster expect `nats_`, so an exporter you run
  yourself without the flag produces panels that silently find no data
  (source: [[s-docs-prometheus-and-dashboards]]).
- **The chart enumerates its peers, and that is why it works.** Each pod's routes are the individual
  headless-service DNS names, not one multi-value name — a single name that resolves to a rotating
  subset of the cluster gives every node a *different* first peer and is a reported cause of
  asymmetric cluster formation on hand-rolled deployments. Copy the enumeration, not the shortcut
  (source: [[s-gh-7190-asymmetric-cluster]]; [[build-a-3-node-cluster]]).
- **`podTemplate.configChecksumAnnotation: true` is the other door**: it hashes the ConfigMap into a
  pod annotation so a config change **rolls the StatefulSet** instead of hot-reloading. Right for a
  change that is not reloadable at all, wrong for a routine policy edit ([[upgrade-a-cluster]]).

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

```yaml
# the drain, and the budget that keeps a roll from taking two nodes at once
config:
  lameDuckGracePeriod: 10s
  lameDuckDuration: 30s
podTemplate:
  terminationGracePeriodSeconds: 60   # >= grace + duration + 20s
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata: { name: nats }
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app.kubernetes.io/name: nats
```

**The probes the chart renders** (for reference — you do not write these):

```yaml
startupProbe:   { httpGet: { path: /healthz,                        port: 8222 }, failureThreshold: 90 }
readinessProbe: { httpGet: { path: "/healthz?js-server-only=true",  port: 8222 } }
livenessProbe:  { httpGet: { path: "/healthz?js-enabled-only=true", port: 8222 } }
```

## Related

[[nack]] · [[nats-box]] · [[nats-surveyor]] · [[monitoring-endpoints]] · [[replicas]] ·
[[jetstream-sizing]] · [[nats-server]] · [[build-a-3-node-cluster]] · [[upgrade-a-cluster]] ·
[[reload-server-config]] · [[install-nats-server]] · [[how-clients-reach-a-cluster]]

## Sources

[[s-docs-ecosystem]] · [[s-github-repo-facts]] · [[s-docs-kubernetes]] ·
[[s-nats-helm-chart-values-2.14.6]] ·
[[s-docs-rolling-upgrades]] · [[s-docs-hardening]] · [[s-docs-config-management]] ·
[[s-docs-prometheus-and-dashboards]] · [[s-gh-7190-asymmetric-cluster]]
