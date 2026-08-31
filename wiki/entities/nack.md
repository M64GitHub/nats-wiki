---
title: NACK (JetStream controller for Kubernetes)
type: entity
kind: tool
area: [deploy, jetstream, kv, objectstore]
verified-against: nack v0.24.0
verified-on: 2026-08-31
tags: [tool, kubernetes, crd, controller, control-loop, drift, jetstream]
aliases: [nack, "nats-io/nack", jetstream controller, jetstream.nats.io]
sources: [s-docs-ecosystem, s-github-repo-facts, s-docs-kubernetes]
created: 2026-08-31
updated: 2026-08-31
---

# NACK (JetStream controller for Kubernetes)

**Streams and consumers as Kubernetes resources.** NACK runs in the cluster, watches CRDs and calls
the JetStream API until the cluster matches what you declared — so the desired state lives in version
control instead of someone's terminal history (source: [[s-docs-kubernetes]]).

## Where it fits

The declarative alternative to running [[nats-cli]] by hand. Both drive the same `$JS.API`
([[js-api]]) through [[jsm-go]]; the difference is who owns the asset.

## Facts

| | |
|---|---|
| repo | `nats-io/nack` |
| latest release | **v0.24.0**, 2026-08-18 |
| licence | Apache-2.0 |
| API group | **`jetstream.nats.io/v1beta2`** |
| kinds | `Stream`, `Consumer`, `Account`, and — **control-loop mode only** — `KeyValue`, `ObjectStore` |
| default reconcile | recreates a **deleted** asset on its **~30-second resync** |
| `--control-loop` mode | also **reverts manual config edits**, on about a **one-minute cycle** |
| deployed by | the `nack` chart in [[nats-helm-charts]] |

## What an operator needs to know

- **Pick one owner per stream.** By default NACK recreates a deleted stream but does **not** revert a
  manual `nats stream edit` — "a config change sticks until the CRD itself next changes". In
  `--control-loop` mode it enforces config drift too. Mixing CLI and CRD management of the same asset
  is the documented way to get a stream that keeps changing back.
- **KV and Object Store need control-loop mode.** "Key/Value stores and Object stores are **only
  supported in control-loop mode**. If you create KeyValue or ObjectStore resources without enabling
  control-loop mode, **they will not be reconciled**" — silently, which is the worst shape.
- **`--crd-connect` is the old way to put connection config in the manifest**, and it "is not
  required if running with `--control-loop`"; under control-loop, resource-level connection config
  always overrides the global config.
- **Verify what it built, don't assume.** The docs' own check is `nats stream info ORDERS` from
  [[nats-box]], looking for `Replicas: 3`; if it reads `1`, the CRD is missing `replicas: 3` or the
  reconcile has not finished — read the resource's `.status` first.
- **The CRD field set is much larger than the examples**: `maxBytes`, `maxAge`, `placement`,
  `mirror`, `sources` and the rest of [[stream]]'s configuration are all expressible.

## Cheat sheet

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
---
apiVersion: jetstream.nats.io/v1beta2
kind: Consumer
metadata:
  name: shipping
spec:
  streamName: ORDERS
  durableName: shipping
---
apiVersion: jetstream.nats.io/v1beta2
kind: Consumer
metadata:
  name: analytics
spec:
  streamName: ORDERS
  durableName: analytics
  filterSubject: orders.shipped
```

```
kubectl apply -f orders-stream.yaml -f orders-consumers.yaml
kubectl get streams,consumers
kubectl describe stream orders          # the .status block the controller writes back

# install with drift enforcement (and KV / Object Store support)
helm install nack nats/nack --set jetstream.additionalArgs={--control-loop} --wait
```

## Related

[[nats-helm-charts]] · [[nats-box]] · [[nats-cli]] · [[jsm-go]] · [[stream]] · [[consumer]] ·
[[js-api]] · [[key-value]] · [[object-store]]

## Sources

[[s-docs-ecosystem]] · [[s-github-repo-facts]] · [[s-docs-kubernetes]]
