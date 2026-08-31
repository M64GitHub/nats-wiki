---
title: "nats Helm chart nats-2.14.6 — values.yaml"
type: summary
area: [deploy, topology]
source-url: https://github.com/nats-io/k8s/blob/nats-2.14.6/helm/charts/nats/values.yaml
source-path: raw/github-repos/nats-io__k8s.values-nats-2.14.6.md, raw/github-repos/nats-io__k8s.values-advertise-nats-2.14.6.md
author: nats-io/k8s maintainers
article: "helm/charts/nats/values.yaml at chart release nats-2.14.6"
date: 2026-08-28          # chart release publish date
version: "2.14.6"
tags: [helm, lameDuckDuration, terminationGracePeriodSeconds, reloader, configChecksumAnnotation, noAdvertise, service, ClusterIP]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# nats Helm chart nats-2.14.6 — values.yaml

The chart defaults the docs quote, read from the chart at its **release tag** rather than from a doc
page, because two runbooks tell an operator to change them.

## Key claims

**Lame-duck timing, with the chart's own sizing rule in a comment:**

```yaml
  # period the server waits after entering lame duck mode before starting
  # to evict clients
  lameDuckGracePeriod: 10s
  # period over which the server evicts all clients after the grace period
  # note: podTemplate.terminationGracePeriodSeconds should be at least
  # lameDuckGracePeriod + lameDuckDuration + 20s shutdown overhead
  lameDuckDuration: 30s
```

```yaml
  # how long to wait for graceful shutdown
  # should be at least config.lameDuckGracePeriod + config.lameDuckDuration
  # + 20s shutdown overhead
  terminationGracePeriodSeconds: 60
```

**The formula is exactly satisfied by the defaults**: 10 + 30 + 20 = 60. So the shipped values leave
**no slack** — raise `lameDuckDuration` by a second without touching
`terminationGracePeriodSeconds` and the kubelet's SIGKILL now lands inside the drain window.

**The chart's `lameDuckDuration: 30s` is the server's documented *minimum***
(`lame_duck_duration` "must be at least 30s"), and a third of the server's own default of `2m`
([[defaults-and-limits]]). [[s-docs-rolling-upgrades]] separately advises *not* to default to the
minimum.

**The reloader sidecar ships enabled:**

```yaml
reloader:
  enabled: true
  image:
    repository: natsio/nats-server-config-reloader
    tag: 0.23.0
  natsVolumeMountPrefixes:
    - /etc/
  merge: {}
  patch: []
```

**`natsVolumeMountPrefixes: [/etc/]` is the constraint nobody reads**: only volumes mounted under
`/etc/` are mounted into the reloader container, so a config or certificate mounted elsewhere is
**not watched** and its change never produces a SIGHUP.

**The alternative to hot reload, one flag away:**

```yaml
podTemplate:
  # adds a hash of the ConfigMap as a pod annotation
  # this will cause the StatefulSet to roll when the ConfigMap is updated
  # set to true to force pod rollouts on config changes instead of using the reloader for hot updates
  configChecksumAnnotation: false
```

**Client discovery is off by default, and the chart says why** (added 2026-08-31, for
question-bank row 67):

```yaml
config:
  cluster:
    # set to false to allow cluster nodes to advertise their addresses
    # so that clients can reconnect without extra DNS lookups.
    # Note: in case clients have external connectivity make sure to define the `advertise` section as well.
    # If clients are behind a load balancer it is best to leave this as is.
    noAdvertise: true
```

This is `cluster { no_advertise: true }` in the server config: the pods never gossip their client
URLs, so a client is told about no server other than the one it dialled. The chart's reasoning is in
the comment — pod IPs are useless to a client that reaches NATS through a Service or a load
balancer, so advertising them would only hand clients addresses they cannot use.

**The client Service is a plain `ClusterIP`.** The `service:` block offers ports but **no `type`
field**, so there is no `LoadBalancer` or `NodePort` value in the chart, and the only `ingress` in
the file is under `websocket`. The word `advertise` appears in the file **only** in the comment
above: the chart defines no `advertise` section itself, so external connectivity is left entirely to
the operator.

## Practical takeaways

- **On Kubernetes, discovery is off unless you turn it on**, and turning it on is wrong while
  clients arrive through a Service or a load balancer — see [[how-clients-reach-a-cluster]].
- **The two timing values are a pair, and the chart's defaults sit exactly on the boundary.** Change
  one, change the other — the rule is in the file, not only in the docs.
- **`configChecksumAnnotation: true` converts every config change into a rolling restart.** That is
  the right choice when a change is *not* reloadable (identity keys, `store_dir`) and the wrong one
  for a routine policy edit, which a SIGHUP applies with no reconnect.
- **A certificate mounted outside `/etc/` is invisible to the reloader**, so a rotation lands on disk
  and nothing signals the server — the failure looks like "reload doesn't work", not like a mount
  problem.
- **Pin claims to the chart release, not to `main`.** The chart is versioned in step with the server
  (`nats-2.14.6`, published 2026-08-28); quoting `main` dates a claim to a moving target.

## Relevance to the wiki

The Kubernetes sections of [[upgrade-a-cluster]] and [[reload-server-config]], the chart facts on
[[nats-helm-charts]], and the Kubernetes half of [[how-clients-reach-a-cluster]].

## Questions it answers

Contributes to **Q63** (the Kubernetes half of a rolling upgrade), **Q54**, and **Q67**
(LoadBalancer or seed URLs on Kubernetes), which [[how-clients-reach-a-cluster]] answers.

## Pages touched

[[nats-helm-charts]] · [[upgrade-a-cluster]] · [[reload-server-config]] · [[install-nats-server]] ·
[[how-clients-reach-a-cluster]]
