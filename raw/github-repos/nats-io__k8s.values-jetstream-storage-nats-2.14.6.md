<!-- source: https://github.com/nats-io/k8s at tag nats-2.14.6 — helm/charts/nats/values.yaml and
     helm/charts/nats/files/config/jetstream.yaml, fetched from raw.githubusercontent.com · fetched 2026-08-31 -->

# nats Helm chart nats-2.14.6 — JetStream storage

A third extract from the same chart release (see `nats-io__k8s.values-nats-2.14.6.md` and
`nats-io__k8s.values-advertise-nats-2.14.6.md`), taken for question-bank row **Q65** —
`hostPath` or a PVC for JetStream on Kubernetes. Only the ranges this wiki cites are stored; line
numbers are the real ones in the file at that tag.

## `config.jetstream` — the storage block (`values.yaml`, lines 89–120)

```yaml
    89	  jetstream:
    90	    enabled: false
    91	
    92	    fileStore:
    93	      enabled: true
    94	      dir: /data
    95	
    96	      ############################################################
    97	      # stateful set -> volume claim templates -> jetstream pvc
    98	      ############################################################
    99	      pvc:
   100	        enabled: true
   101	        size: 10Gi
   102	        storageClassName:
   103	
   104	        # merge or patch the jetstream pvc
   105	        # https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.24/#persistentvolumeclaim-v1-core
   106	        merge: {}
   107	        patch: []
   108	        # defaults to "{{ include "nats.fullname" $ }}-js"
   109	        name:
   110	
   111	      # defaults to the PVC size
   112	      maxSize:
   113	
   114	    memoryStore:
   115	      enabled: false
   116	      # ensure that container has a sufficient memory limit greater than maxSize
   117	      maxSize: 1Gi
   118	
   119	    # merge or patch the jetstream config
   120	    # https://docs.nats.io/running-a-nats-service/configuration#jetstream
```

## What those values render into — `files/config/jetstream.yaml`, complete

```
{{- with .Values.config.jetstream }}
{{- with .memoryStore }}
{{- if .enabled }}
{{- with .maxSize }}
max_memory_store: << {{ . }} >>
{{- end }}
{{- else }}
max_memory_store: 0
{{- end }}
{{- end }}
{{- with .fileStore }}
{{- if .enabled }}
store_dir: {{ .dir }}
{{- if .maxSize }}
max_file_store: << {{ .maxSize }} >>
{{- else if .pvc.enabled }}
max_file_store: << {{ .pvc.size }} >>
{{- end }}
{{- else }}
max_file_store: 0
{{- end }}
{{- end }}
{{- end }}
```

So with the chart's defaults and `config.jetstream.enabled: true`, a node renders:

```
store_dir: /data
max_file_store: 10Gi          # exactly config.jetstream.fileStore.pvc.size
max_memory_store: 0
```

`fileStore.maxSize` overrides it; left unset, `max_file_store` **equals the PVC size, with no
margin**.

## The resolver's own PVC (`values.yaml`, lines 253–270)

The second `volumeClaimTemplate` the chart can create, for the JWT account resolver directory:

```yaml
   253	  resolver:
   254	    enabled: false
   255	    dir: /data/resolver
   256	
   257	    ############################################################
   258	    # stateful set -> volume claim templates -> resolver pvc
   259	    ############################################################
   260	    pvc:
   261	      enabled: true
   262	      size: 1Gi
   263	      storageClassName:
   264	
   265	      # merge or patch the pvc
   266	      # https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.24/#persistentvolumeclaim-v1-core
   267	      merge: {}
   268	      patch: []
   269	      # defaults to "{{ include "nats.fullname" $ }}-resolver"
   270	      name:
```

## Searched for and absent

```
$ grep -n "emptyDir\|hostPath" helm/charts/nats/values.yaml     # (741 lines, tag nats-2.14.6)
   (no matches)
```

The chart exposes **no `hostPath` and no `emptyDir` value**. Its only storage paths are a PVC per
replica (`fileStore.pvc.enabled: true`, the default) or `fileStore.pvc.enabled: false`, which leaves
`store_dir: /data` on whatever the pod's filesystem provides. Anything else has to be reached through
the `merge:` / `patch:` escape hatches.
