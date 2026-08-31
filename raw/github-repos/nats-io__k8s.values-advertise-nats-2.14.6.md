<!-- source: https://github.com/nats-io/k8s at tag nats-2.14.6, helm/charts/nats/values.yaml fetched from raw.githubusercontent.com · fetched 2026-08-31 -->
# nats Helm chart nats-2.14.6 — client advertising and the client Service

A second extract from the same file as `nats-io__k8s.values-nats-2.14.6.md`, taken while answering
question-bank row 67 ("LoadBalancer or seed URLs — how should clients reach a cluster on
Kubernetes?"). Line numbers are the real ones in `helm/charts/nats/values.yaml` at tag
**nats-2.14.6** (741 lines).

## `config.cluster.noAdvertise` — the chart turns client discovery **off** by default

```yaml
    50	config:
    51	  cluster:
    52	    enabled: false
    53	    port: 6222
    54	    # must be 2 or higher when jetstream is enabled
    55	    replicas: 3
    56	    # set to false to allow cluster nodes to advertise their addresses
    57	    # so that clients can reconnect without extra DNS lookups.
    58	    # Note: in case clients have external connectivity make sure to define the `advertise` section as well.
    59	    # If clients are behind a load balancer it is best to leave this as is.
    60	    noAdvertise: true
    61	
```

## The client Service — `ClusterIP`, with no `type` field offered

```yaml
   476	service:
   477	  enabled: true
   478	
   479	  # service port options
   480	  # additional boolean field enable to control whether port is exposed in the service
   481	  # must be enabled in the config section also
   482	  # https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.24/#serviceport-v1-core
   483	  ports:
   484	    nats:
   485	      enabled: true
   486	    leafnodes:
   487	      enabled: true
   488	    websocket:
   489	      enabled: true
   490	    mqtt:
   491	      enabled: true
   492	    cluster:
   493	      enabled: false
   494	    gateway:
   495	      enabled: false
   496	    monitor:
   497	      enabled: false
   498	    profiling:
   499	      enabled: false
   500	
```

The chart exposes no `service.type`, so the Service is Kubernetes' default, **ClusterIP**. There is
no `LoadBalancer` or `NodePort` value in the file, and no ingress for the client port — the only
`ingress` block in the chart is under `websocket`. `advertise` appears in the file **only** in the
comment above; the chart defines no `advertise` section of its own.
