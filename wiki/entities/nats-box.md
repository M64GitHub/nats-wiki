---
title: nats-box
type: entity
kind: tool
area: [deploy, monitoring, security]
verified-against: nats-box v0.19.7
verified-on: 2026-08-31
tags: [tool, container, kubernetes, docker, toolbox]
aliases: [nats-box, "nats-io/nats-box", "natsio/nats-box"]
sources: [s-docs-ecosystem, s-github-repo-facts, s-docs-kubernetes, s-nats-server-readme]
created: 2026-08-31
updated: 2026-09-01
---

# nats-box

**A container with the NATS tools in it.** The standard way to get a shell with `nats`, `nsc`,
`nats-top` and `nk` next to a cluster — especially on Kubernetes, where installing a CLI on a node is
not an option (source: [[s-docs-ecosystem]]).

## Where it fits

The Helm chart deploys it alongside the StatefulSet, which is why the docs' verification steps read
"open a shell in `nats-box`" rather than "run `nats` locally" (source: [[s-docs-kubernetes]]).

## Facts

| | |
|---|---|
| repo | `nats-io/nats-box` |
| latest release | **v0.19.7**, 2026-06-02 |
| licence | Apache-2.0 |
| image | **`natsio/nats-box`** on Docker Hub |
| contains | [[nats-cli]] (`nats`), [[nsc]], **[[nats-top]]** and [[nk]] |

The docs' ecosystem page names three tools (`nats`, `nsc`, `nk`); the image's own README lists
**four**, including `nats-top`.

## What an operator needs to know

- **It is the CLI's deployment vehicle on Kubernetes.** `kubectl exec -it deploy/nats-box -- sh`
  puts you inside the cluster's DNS, so `nats stream info ORDERS` resolves `nats-0..2` over the
  headless service with no port-forward.
- **Mount a volume for `nsc`.** `docker run --rm -it -v $(pwd)/nsc:/nsc natsio/nats-box:latest`
  keeps accounts, nkeys and creds on the host — otherwise the identity store dies with the
  container, which is a very bad way to lose an operator key.
- **It is not a Docker Official Image, and the server is.** `nats-server` ships as the Docker Hub
  library image **`_/nats`** — which is why `docker run … nats:latest` needs no registry prefix
  (source: [[s-nats-server-readme]]) — while nats-box lives under the **`natsio/`** namespace. On a
  cluster that mirrors or allow-lists images by provenance, the two are governed by different rules,
  and the toolbox is the one that will be missing.
- **A shell in the cluster is a privilege.** Anything reachable from that pod's credentials is
  reachable by anyone who can `exec` into it; on a hardened cluster, treat nats-box as an admin
  surface, not a utility.

## Cheat sheet

```
docker run --rm -it natsio/nats-box:latest
docker run --rm -it -v $(pwd)/nsc:/nsc natsio/nats-box:latest     # persist the nsc store
kubectl run -i --rm --tty nats-box --image=natsio/nats-box --restart=Never   # ad-hoc pod
kubectl exec -it deploy/nats-box -- sh                            # the chart's own pod
```

```
# inside the container
nats pub -s demo.nats.io test 'Hello World'
nats stream ls
nats stream info ORDERS
nsc init -d /nsc
```

## Related

[[nats-cli]] · [[nsc]] · [[nk]] · [[nats-top]] · [[nats-helm-charts]] · [[nack]]

## Sources

[[s-docs-ecosystem]] · [[s-github-repo-facts]] · [[s-docs-kubernetes]] · [[s-nats-server-readme]]
