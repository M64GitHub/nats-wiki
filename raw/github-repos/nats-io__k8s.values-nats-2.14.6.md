<!-- source: https://github.com/nats-io/k8s at tag nats-2.14.6, helm/charts/nats/values.yaml fetched from raw.githubusercontent.com · fetched 2026-08-31 -->
# nats Helm chart nats-2.14.6 — the values this wiki quotes

Chart release **nats-2.14.6** (published 2026-08-28), the chart that ships alongside nats-server
v2.14.6. Only the ranges this wiki cites are stored; line numbers are the real ones in
`helm/charts/nats/values.yaml` at that tag. Read while ingesting
`learn/deployment/rolling-upgrades.md` and `learn/deployment/config-management.md`, both of which
state chart defaults.

## Lame-duck timing (`config.lameDuckGracePeriod`, `config.lameDuckDuration`)

```yaml
  276	
  277	  # period the server waits after entering lame duck mode before starting
  278	  # to evict clients
  279	  lameDuckGracePeriod: 10s
  280	  # period over which the server evicts all clients after the grace period
  281	  # https://docs.nats.io/running-a-nats-service/nats_admin/lame_duck_mode
  282	  # note: podTemplate.terminationGracePeriodSeconds should be at least
  283	  # lameDuckGracePeriod + lameDuckDuration + 20s shutdown overhead
  284	  lameDuckDuration: 30s
  285	
```

## Graceful shutdown and the config-checksum annotation (`podTemplate`)

```yaml
  519	  name:
  520	
  521	# stateful set -> pod template
  522	podTemplate:
  523	  # adds a hash of the ConfigMap as a pod annotation
  524	  # this will cause the StatefulSet to roll when the ConfigMap is updated
  525	  # set to true to force pod rollouts on config changes instead of using the reloader for hot updates
  526	  configChecksumAnnotation: false
  527	
  528	  # how long to wait for graceful shutdown
  529	  # should be at least config.lameDuckGracePeriod + config.lameDuckDuration
  530	  # + 20s shutdown overhead
  531	  terminationGracePeriodSeconds: 60
```

## The config-reloader sidecar (`reloader`)

```yaml
  411	reloader:
  412	  enabled: true
  413	  image:
  414	    repository: natsio/nats-server-config-reloader
  415	    tag: 0.23.0
  416	    pullPolicy:
  417	    registry:
  418	    digest:
  419	    fullImageName:
  420	
  421	  # env var map, see nats.env for an example
  422	  env: {}
  423	
  424	  # all nats container volume mounts with the following prefixes
  425	  # will be mounted into the reloader container
  426	  natsVolumeMountPrefixes:
  427	    - /etc/
  428	
  429	  # merge or patch the container
  430	  # https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.24/#container-v1-core
  431	  merge: {}
  432	  patch: []
```
