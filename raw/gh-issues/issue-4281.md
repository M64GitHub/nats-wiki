<!-- source: https://github.com/nats-io/nats-server/issues/4281 (GitHub GraphQL API) · fetched 2026-08-31 -->
# nats-server issue #4281 — nats: error: could not create Stream: insufficient storage resources available (10047)

State: OPEN · opened 2023-06-29 by @jeffmccune

## Original post

## Defect

Make sure that these boxes are checked before submitting your issue -- thank you!

 - [x] Included `nats-server -DV` output
 - [x] Included a [Minimal, Complete, and Verifiable example] (https://stackoverflow.com/help/mcve)

<details><summary>nats-server -DV output</summary>

```
[7] 2023/04/28 18:18:19.790095 [INF] Starting nats-server
[7] 2023/04/28 18:18:19.790168 [INF]   Version:  2.9.16
[7] 2023/04/28 18:18:19.790172 [INF]   Git:      [f84ca24]
[7] 2023/04/28 18:18:19.790187 [INF]   Cluster:  nats
[7] 2023/04/28 18:18:19.790190 [INF]   Name:     nats-0
[7] 2023/04/28 18:18:19.790194 [INF]   Node:     S1Nunr6R
[7] 2023/04/28 18:18:19.790199 [INF]   ID:       NAVQ6FRDQ4DSFKGHYK4SPGOMT67P2SO522WWYAEYYUZRT2X3BEZO74Q2
[7] 2023/04/28 18:18:19.790225 [INF] Using configuration file: /etc/nats-config/nats.conf
[7] 2023/04/28 18:18:19.790229 [INF] Trusted Operators
[7] 2023/04/28 18:18:19.790233 [INF]   System  : ""
[7] 2023/04/28 18:18:19.790248 [INF]   Operator: "OpenInfrastructureServices"
[7] 2023/04/28 18:18:19.790262 [INF]   Issued  : 2023-04-28 18:15:50 +0000 UTC
[7] 2023/04/28 18:18:19.790274 [INF]   Expires : Never
[7] 2023/04/28 18:18:19.791561 [INF] Starting http monitor on 0.0.0.0:8222
[7] 2023/04/28 18:18:19.791696 [INF] Managing all jwt in exclusive directory /accounts/jwt
[7] 2023/04/28 18:18:19.791751 [INF] Starting JetStream
[7] 2023/04/28 18:18:19.793489 [INF]     _ ___ _____ ___ _____ ___ ___   _   __  __
[7] 2023/04/28 18:18:19.793507 [INF]  _ | | __|_   _/ __|_   _| _ \ __| /_\ |  \/  |
[7] 2023/04/28 18:18:19.793514 [INF] | || | _|  | | \__ \ | | |   / _| / _ \| |\/| |
[7] 2023/04/28 18:18:19.793517 [INF]  \__/|___| |_| |___/ |_| |_|_\___/_/ \_\_|  |_|
[7] 2023/04/28 18:18:19.793519 [INF]
[7] 2023/04/28 18:18:19.793522 [INF]          https://docs.nats.io/jetstream
[7] 2023/04/28 18:18:19.793524 [INF]
[7] 2023/04/28 18:18:19.793526 [INF] ---------------- JETSTREAM ----------------
[7] 2023/04/28 18:18:19.793538 [INF]   Max Memory:      2.00 GB
[7] 2023/04/28 18:18:19.793543 [INF]   Max Storage:     10.00 GB
[7] 2023/04/28 18:18:19.793546 [INF]   Store Directory: "/data/jetstream"
[7] 2023/04/28 18:18:19.793548 [INF] -------------------------------------------
[7] 2023/04/28 18:18:19.793998 [INF] Starting JetStream cluster
[7] 2023/04/28 18:18:19.794025 [INF] Creating JetStream metadata controller
[7] 2023/04/28 18:18:19.795194 [INF] JetStream cluster bootstrapping
[7] 2023/04/28 18:18:19.795795 [INF] Listening for websocket clients on wss://0.0.0.0:443
[7] 2023/04/28 18:18:19.796210 [INF] Listening for leafnode connections on 0.0.0.0:7422
[7] 2023/04/28 18:18:19.796808 [INF] Listening for client connections on 0.0.0.0:4222
[7] 2023/04/28 18:18:19.796827 [INF] TLS required for client connections
[7] 2023/04/28 18:18:19.797130 [INF] Server is ready
[7] 2023/04/28 18:18:19.797188 [INF] Cluster name is nats
[7] 2023/04/28 18:18:19.797273 [INF] Listening for route connections on 0.0.0.0:6222
[7] 2023/04/28 18:18:19.810518 [INF] 10.68.253.243:6222 - rid:6 - Route connection created
[7] 2023/04/28 18:18:19.810647 [ERR] Error trying to connect to route (attempt 1): lookup for host "nats-2.nats.holos-dev.svc.cluster.local": lookup nats-2.nats.holos-dev.svc.cluster.local on 10.64.64.10:53: no such host
[7] 2023/04/28 18:18:19.897629 [WRN] Waiting for routing to be established...
[7] 2023/04/28 18:18:19.899732 [INF] JetStream cluster new metadata leader: nats-1/nats

(Output truncated)
```
</details>

#### Versions of `nats-server` and affected client libraries used:

2.9.16

#### OS/Container environment:

Kubernetes kubeadm on top of proxmox ceph rdb storage.

```
Client Version: version.Info{Major:"1", Minor:"26", GitVersion:"v1.26.1", GitCommit:"8f94681cd294aa8cfd3407b8191f6c70214973a4", GitTreeState:"clean", BuildDate:"2023-01-18T15:58:16Z", GoVersion:"go1.19.5", Compiler:"gc", Platform:"linux/amd64"}
Kustomize Version: v4.5.7
Server Version: version.Info{Major:"1", Minor:"25", GitVersion:"v1.25.6", GitCommit:"ff2c119726cc1f8926fb0585c74b25921e866a28", GitTreeState:"clean", BuildDate:"2023-01-18T19:15:26Z", GoVersion:"go1.19.5", Compiler:"gc", Platform:"linux/amd64"}
```

#### Steps or code to reproduce the issue:

```bash
nats --creds tokyo-rain-123-admin.creds stream add MYSTREAM \
  '--subjects=holos.releases.*.elements.>' \
  --storage=file \
  --replicas=3 \
  --retention=limits \
  --discard=old \
  --max-age=90d \
  --max-bytes=32MiB \
  --max-msg-size=128KiB \
  --max-msgs=-1 \
  --max-msgs-per-subject=1 \
  --dupe-window=120s \
  --no-allow-rollup \
  --allow-direct \
  --no-deny-delete \
  --no-deny-purge
```

```console
nats: error: could not create Stream: insufficient storage resources available (10047)
```

#### Expected result:

I first ran into this error with `--max-bytes=64MiB`.  The account had Max Disk Storage of `64 MB` and Max Mem Storage of `64 MB` (note, not MiB) so I made only one change to `--max-bytes=32MiB` and the stream created OK as follows:

<details><summary>Stream MYSTREAM was created</summary>

```console
Stream MYSTREAM was created

Information for Stream MYSTREAM created 2023-06-29 10:59:11

          Description: Redacted
             Subjects: holos.releases.*.elements.>
             Replicas: 3
              Storage: File

Options:

            Retention: Limits
     Acknowledgements: true
       Discard Policy: Old
     Duplicate Window: 15s
           Direct Get: true
    Allows Msg Delete: true
         Allows Purge: true
       Allows Rollups: false

Limits:

     Maximum Messages: unlimited
  Maximum Per Subject: 1
        Maximum Bytes: 32 MiB
          Maximum Age: 90d0h0m0s
 Maximum Message Size: 128 KiB
    Maximum Consumers: unlimited

Cluster Information:

                 Name: nats
               Leader: nats-2
              Replica: nats-0, current, seen 0.00s ago
              Replica: nats-1, current, seen 0.00s ago

State:

             Messages: 0
                Bytes: 0 B
             FirstSeq: 0
              LastSeq: 0
     Active Consumers: 0
```

</details>

I then deleted this stream intending to re-create it with 120s duplicate message window.

```
❯ nats --cred tokyo-admin-123-admin.creds stream del
? Select a Stream MYSTREAM
? Really delete Stream MYSTREAM Yes
```

#### Actual result:

After deleting the stream, I cannot re-create it using the command in "steps to reproduce" I always get the following error even when I put the original `--dupe-window=15s` back.

```console
nats: error: could not create Stream: insufficient storage resources available (10047)
```

Note, there's plenty of storage available and the ext4 file system is writable.

```
❯ for i in $(seq 0 2); do kubectl exec nats-$i --container nats -- df -h /data; done
Filesystem                Size      Used Available Use% Mounted on
/dev/rbd2                 9.7G    424.0K      9.7G   0% /data
Filesystem                Size      Used Available Use% Mounted on
/dev/rbd3                 9.7G    472.0K      9.7G   0% /data
Filesystem                Size      Used Available Use% Mounted on
/dev/rbd2                 9.7G    872.0K      9.7G   0% /data
```

```
❯ for i in $(seq 0 2); do kubectl exec nats-$i --container nats -- touch /data/jetstream/test; done
```

```
❯ for i in $(seq 0 2); do kubectl exec nats-$i --container nats -- ls -l  /data/jetstream/test; done
-rw-r--r--    1 root     root             0 Jun 29 19:02 /data/jetstream/test
-rw-r--r--    1 root     root             0 Jun 29 19:02 /data/jetstream/test
-rw-r--r--    1 root     root             0 Jun 29 19:02 /data/jetstream/test
```
```
for i in $(seq 0 2); do kubectl exec nats-$i --container nats -- unlink /data/jetstream/test; done
```

## Comment — @jeffmccune (2023-06-29)

Searching through slack, it [was suggested](https://natsio.slack.com/archives/C069GSYFP/p1680785859403259?thread_ts=1680785764.882869&cid=C069GSYFP) checking the user account limits, but those look OK:

<details><summary>nats --creds tokyo-rain-123-admin.creds account info</summary>

```console
Connection Information:

               Client ID: 370
               Client IP: 192.168.2.21
                     RTT: 975.641µs
       Headers Supported: true
         Maximum Payload: 1.0 MiB
       Connected Cluster: nats
           Connected URL: tls://nats.core1.ois.lan:4222
       Connected Address: 10.64.192.3:4222
     Connected Server ID: NCRYBVOYNQZP62YFMVEDFZ3BQJRQTI6R676RCIN5HM7GMLN5FDZX2CC2
   Connected Server Name: nats-1
             TLS Version: 1.3 using TLS_AES_128_GCM_SHA256
              TLS Server: nats.core1.ois.lan
            TLS Verified: issuer CN=core1 Cluster CA 45e455,O=Open Infrastructure Services LLC,ST=Oregon,C=US

JetStream Account Information:

Account Usage:

    Storage: 657 B
     Memory: 0 B
    Streams: 1
  Consumers: 0

Account Limits:

   Max Message Payload: 1.0 MiB

   Tier: Default

      Configuration Requirements:

         Stream Requires Max Bytes Set: false
          Consumer Maximum Ack Pending: Unlimited

      Stream Resource Usage Limits:

                    Memory: 0 B of 122 MiB
         Memory Per Stream: Unlimited
                   Storage: 657 B of 122 MiB
        Storage Per Stream: Unlimited
                   Streams: 1 of 3
                 Consumers: 0 of 10
```

</details>

## Comment — @wallyqs (2023-06-29)

Could you post your kubernetes helm config and which version of helm charts did you use?

## Comment — @jeffmccune (2023-06-29)

Thanks for taking a look @wallyqs looks like the nats-0.19.13 chart.

```
NAME            NAMESPACE       REVISION        UPDATED                                 STATUS          CHART                   APP VERSION
nats            holos-dev       3               2023-04-28 11:42:51.391311593 -0700 PDT deployed        nats-0.19.13            2.9.16
```

<details><summary>helm input values</summary>

```yaml
---
auth:
  # Operator JWT and SYS account secrets are stored in nats-auth-config
  enabled: true
  resolver:
    type: full
    store:
      # Must match the path configured in auth.conf by the experiments/workflows/scripts/initialize-auth script
      dir: "/accounts/jwt"
      size: "1Gi"
      storageClassName: "ceph-ssd"

cluster:
  enabled: true
  noAdvertise: true # for LoadBalancer
  # name: nats (defaults to helm release name)
  replicas: 3

  tls:
    secret:
      name: nats-server-tls # Generated by experiments/workflows/scripts/initialize-auth
    ca: "ca.crt"
    cert: "tls.crt"
    key: "tls.key"

# JetStream
nats:
  # External Secrets automatically included from nats.conf
  # https://github.com/nats-io/k8s/blob/nats-0.19.12/helm/charts/nats/templates/configmap.yaml#L17
  config:
    - name: auth # auth.conf
      secret:
        secretName: nats-auth-config

  tls:
    secret:
      name: nats-server-tls
    ca: "ca.crt"
    cert: "tls.crt"
    key: "tls.key"
    verifyAndMap: true

  jetstream:
    enabled: true

    memStorage:
      enabled: true
      size: 2Gi

    fileStorage:
      enabled: true
      size: 10Gi
      # storageClassName: gp2 # NOTE: AWS setup but customize as needed for your infra.
      storageClassName: ceph-ssd

leafnodes:
  enabled: true
  noAdvertise: true # for LoadBalancer

natsbox:
  enabled: true

# Websocket
websocket:
  enabled: true
  port: 443

  tls:
    secret:
      name: nats-server-tls
    cert: "tls.crt"
    key: "tls.key"

# Prometheus Exporter
exporter:
  enabled: true
  serviceMonitor:
    enabled: true

# NACK JetStream Controller
# https://github.com/nats-io/k8s/blob/main/helm/charts/nack/values.yaml
jetstream:
  enabled: true
  nats:
    url: nats://nats:4222
    credentials:
      secret:
        name: nats-sys-creds
        key: sys.creds

  tls:
    enabled: true
    secretName: nats-client-tls
```

</details>

Note, I'm fairly ignorant about the NACK jetstream controller at the bottom, that was an experiment of mine that didn't pan out back in May.

My deployment script overlays the following resources into the rendered output using a kustomize post-renderer:

<details><summary>overlay resources</summary>

```yaml
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: "{{ .Release.Name }}-server-tls"
  namespace: "{{ .Release.Namespace }}"
spec:
  secretName: "{{ .Release.Name }}-server-tls"
  commonName: "{{ .Release.Name }}.{{ .Release.Namespace }}.svc.cluster.local"
  dnsNames:
  # Simple service name, e.g. nats://nats
  - "{{ .Release.Name }}"
  - "{{ .Release.Name }}.{{ .Release.Namespace }}.svc"
  - "{{ .Release.Name }}.{{ .Release.Namespace }}.svc.cluster.local"
  # Wildcards for individual pods in the stateful set
  - "*.{{ .Release.Name }}"
  - "*.{{ .Release.Name }}.{{ .Release.Namespace }}.svc"
  - "*.{{ .Release.Name }}.{{ .Release.Namespace }}.svc.cluster.local"
  # Used interally in the saas environment
  - "{{ .Release.Name }}.{{ .Values.global.oixClusterName }}.ois.lan"
  # used externally in the saas environment
  - '{{ .Release.Name }}.{{ required "\n\nRequired: oixDnsDomain" .Values.oixDnsDomain }}'
  # Websocket matching the virtual-service
  - '{{ .Release.Name }}.pub.{{ required "\n\nRequired: oixDnsDomain" .Values.oixDnsDomain }}'
  ipAddresses:
  - '{{ required "\n\nRequired: global.natsLoadBalancerIP (Defined in k8s/values/cluster-NAME.yaml)" .Values.global.natsLoadBalancerIP }}'
  usages:
  - signing
  - key encipherment
  - server auth
  - client auth
  issuerRef:
    kind: ClusterIssuer
    name: cluster-issuer
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: "{{ .Release.Name }}-client-tls"
  namespace: "{{ .Release.Namespace }}"
spec:
  secretName: "{{ .Release.Name }}-client-tls"
  commonName: "{{ .Release.Name }}-client"
  usages:
  - signing
  - key encipherment
  - client auth
  issuerRef:
    kind: ClusterIssuer
    name: cluster-issuer
---
# Client certificate is used for development purposes by
# experiments/workflows/scripts/nats/natscli
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: "{{ .Release.Name }}-client-bastion-tls"
  namespace: "{{ .Release.Namespace }}"
spec:
  secretName: "{{ .Release.Name }}-client-bastion-tls"
  emailAddresses:
    - root@bastion.ois.lan
  usages:
    - signing
    - key encipherment
    - client auth
  issuerRef:
    kind: ClusterIssuer
    name: cluster-issuer
---
# Client certificate is used for development purposes by
# experiments/workflows/scripts/nats/natscli
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: "{{ .Release.Name }}-client-shared-tls"
  namespace: "{{ .Release.Namespace }}"
spec:
  secretName: "{{ .Release.Name }}-client-shared-tls"
  emailAddresses:
    - shared@ois.run
  usages:
    - signing
    - key encipherment
    - client auth
  issuerRef:
    kind: ClusterIssuer
    name: cluster-issuer
# Necessary to enable TLS from the ingressgateway to the vault service.
---
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: nats
spec:
  host: nats
  trafficPolicy:
    tls:
      mode: SIMPLE
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: nats-auth-config
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: core-vault
    kind: SecretStore
  target:
    name: nats-auth-config
    creationPolicy: Owner
  dataFrom:
    - extract:
        key: "kv/{{ .Values.global.oixClusterName }}/kube-namespace/{{ .Release.Namespace}}/nats-auth-config"
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: nats-sys-creds
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: core-vault
    kind: SecretStore
  target:
    name: nats-sys-creds
    creationPolicy: Owner
  dataFrom:
    - extract:
        key: "kv/{{ .Values.global.oixClusterName }}/kube-namespace/{{ .Release.Namespace}}/nats-sys-creds"
# https://docs.nats.io/running-a-nats-service/nats-kubernetes/helm-charts#using-loadbalancers
---
apiVersion: v1
kind: Service
metadata:
  name: "{{ .Release.Name }}-lb"
spec:
  type: LoadBalancer
  externalTrafficPolicy: Local
  loadBalancerIP: '{{ required "\n\nRequired: global.natsLoadBalancerIP (Defined in k8s/values/cluster-NAME.yaml)" .Values.global.natsLoadBalancerIP }}'
  selector:
    app.kubernetes.io/name: "{{ .Release.Name }}"
  ports:
    - protocol: TCP
      port: 4222
      targetPort: 4222
      name: nats
    - protocol: TCP
      port: 7422
      targetPort: 7422
      name: leafnodes
    - protocol: TCP
      port: 7522
      targetPort: 7522
      name: gateways
---
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: '{{ .Release.Name }}-ws'
  namespace: {{ .Release.Namespace }}
spec:
  hosts:
    - '{{ .Release.Name }}.pub.{{ required "\n\nRequired: oixDnsDomain" .Values.oixDnsDomain }}'
  gateways:
    - istio-ingress/wildcard-pub-gw
  http:
    - route:
        - destination:
            host: '{{ .Release.Name }}.{{ .Release.Namespace }}.svc.cluster.local'
            port:
              number: 443
```

</details>

Here's the complete build script for the helm chart plus overlay which renders the yaml to apply to the cluster.

<details><summary>helm + kustomize build steps and output</summary>

```console
❯ bash -x build
+ : nats
+ export OIX_RELEASE_NAME
+ NAMESPACE=holos-dev
+ export NAMESPACE
+ set -euo pipefail
+++ dirname build
++ cd .
++ pwd
+ CHART_PATH=/home/jeff/workspace/holos/experiments/components/holos-saas/nats
+ export CHART_PATH
++ kubectl config view --minify --flatten '-ojsonpath={.clusters[0].name}'
+ : core1
+ export OIX_CLUSTER_NAME
+ [[ -z nats ]]
++ cd /home/jeff/workspace/holos/experiments/components/holos-saas/nats
++ git rev-parse --show-toplevel
+ TOPLEVEL=/home/jeff/workspace/holos
+ CLUSTER_VALUES=/home/jeff/workspace/holos/k8s/values/cluster-core1.yaml
+ export CLUSTER_VALUES
+ ORG_VALUES=/home/jeff/workspace/holos/k8s/values/org-ois.yaml
+ export ORG_VALUES
+ case "$(basename "$0")" in
++ basename build
+ cmd=("template")
+ helm repo add nats https://nats-io.github.io/k8s/helm/charts/
"nats" already exists with the same configuration, skipping
+ helm repo update
Hang tight while we grab the latest from your chart repositories...
...Successfully got an update from the "nats" chart repository
Update Complete. ⎈Happy Helming!⎈
+ helm template nats nats/nats --version 0.19.13 --namespace holos-dev --create-namespace --values /home/jeff/workspace/holos/k8s/values/org-ois.yaml --values /home/jeff/workspace/holos/k8s/values/cluster-core1.yaml --values /home/jeff/workspace/holos/experiments/components/holos-saas/nats/values.holos.yaml --post-renderer /home/jeff/workspace/holos/experiments/components/holos-saas/nats/kustomize/kustomize
```

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    app.kubernetes.io/instance: nats
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: nats
    app.kubernetes.io/version: 2.9.16
    helm.sh/chart: nats-0.19.13
  name: nats
  namespace: holos-dev
---
apiVersion: v1
data:
  nats.conf: "# NATS Clients Port\nport: 4222\n\n# PID file shared with configuration
    reloader.\npid_file: \"/var/run/nats/nats.pid\"\n###########\n#         #\n# Imports
    #\n#         #\n###########\ninclude ./auth/auth.conf\n\n###############\n#             #\n#
    Monitoring  #\n#             #\n###############\nhttp: 8222\nserver_name:$POD_NAME\n#####################\n#
    \                  #\n# TLS Configuration #\n#                   #\n#####################\ntls
    {\n    cert_file: /etc/nats-certs/clients/nats-server-tls/tls.crt\n    key_file:
    \ /etc/nats-certs/clients/nats-server-tls/tls.key\n    ca_file: /etc/nats-certs/clients/nats-server-tls/ca.crt\n
    \   verify_and_map: true\n}\n###################################\n#                                 #\n#
    NATS JetStream                  #\n#                                 #\n###################################\njetstream
    {\n  max_mem: 2Gi\n  store_dir: /data\n\n  max_file:10Gi\n}\n###################################\n#
    \                                #\n# NATS Full Mesh Clustering Setup #\n#                                 #\n###################################\ncluster
    {\n  port: 6222\n  name: nats\n  tls {\n      cert_file: /etc/nats-certs/cluster/nats-server-tls/tls.crt\n
    \     key_file:  /etc/nats-certs/cluster/nats-server-tls/tls.key\n      ca_file:
    /etc/nats-certs/cluster/nats-server-tls/ca.crt\n  }\n\n  routes = [\n    nats://nats-0.nats.holos-dev.svc.cluster.local:6222,nats://nats-1.nats.holos-dev.svc.cluster.local:6222,nats://nats-2.nats.holos-dev.svc.cluster.local:6222,\n
    \   \n  ]\n  cluster_advertise: $CLUSTER_ADVERTISE\n  no_advertise: true\n\n  connect_retries:
    120\n}\n#################\n#               #\n# NATS Leafnode #\n#               #\n#################\nleafnodes
    {\n  listen: \"0.0.0.0:7422\"\n  no_advertise: true\n\n  remotes: [\n  ]\n}\nlame_duck_grace_period:
    10s\nlame_duck_duration: 30s\n##################\n#                #\n# Websocket
    \     #\n#                #\n##################\nwebsocket {\n  port: 443\n    \n
    \   tls {\n    cert_file: /etc/nats-certs/ws/nats-server-tls/tls.crt\n    key_file:
    /etc/nats-certs/ws/nats-server-tls/tls.key\n    }\n  same_origin: false\n}\n##################\n#
    \               #\n# Authorization  #\n#                #\n##################\n\n
    \     resolver: {\n        type: full\n        dir: \"/accounts/jwt\"\n\n        allow_delete:
    false\n\n        interval: \"2m\"\n      }\n"
kind: ConfigMap
metadata:
  labels:
    app.kubernetes.io/instance: nats
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: nats
    app.kubernetes.io/version: 2.9.16
    helm.sh/chart: nats-0.19.13
  name: nats-config
  namespace: holos-dev
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app.kubernetes.io/instance: nats
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: nats
    app.kubernetes.io/version: 2.9.16
    helm.sh/chart: nats-0.19.13
  name: nats
  namespace: holos-dev
spec:
  clusterIP: None
  ports:
  - appProtocol: tcp
    name: websocket
    port: 443
  - appProtocol: tcp
    name: client
    port: 4222
  - appProtocol: tcp
    name: cluster
    port: 6222
  - appProtocol: http
    name: monitor
    port: 8222
  - appProtocol: http
    name: metrics
    port: 7777
  - appProtocol: tcp
    name: leafnodes
    port: 7422
  - appProtocol: tcp
    name: gateways
    port: 7522
  publishNotReadyAddresses: true
  selector:
    app.kubernetes.io/instance: nats
    app.kubernetes.io/name: nats
---
apiVersion: v1
kind: Service
metadata:
  name: nats-lb
spec:
  externalTrafficPolicy: Local
  loadBalancerIP: 10.64.192.3
  ports:
  - name: nats
    port: 4222
    protocol: TCP
    targetPort: 4222
  - name: leafnodes
    port: 7422
    protocol: TCP
    targetPort: 7422
  - name: gateways
    port: 7522
    protocol: TCP
    targetPort: 7522
  selector:
    app.kubernetes.io/name: nats
  type: LoadBalancer
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: nats-box
    chart: nats-0.19.13
  name: nats-box
  namespace: holos-dev
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nats-box
  template:
    metadata:
      labels:
        app: nats-box
    spec:
      containers:
      - command:
        - tail
        - -f
        - /dev/null
        env:
        - name: NATS_URL
          value: nats
        image: natsio/nats-box:0.13.8
        imagePullPolicy: IfNotPresent
        lifecycle:
          postStart:
            exec:
              command:
              - /bin/sh
              - -c
              - cp /etc/nats-certs/clients/nats-server-tls/* /usr/local/share/ca-certificates
                && update-ca-certificates
        name: nats-box
        resources: {}
        volumeMounts:
        - mountPath: /etc/nats-certs/clients/nats-server-tls
          name: nats-server-tls-clients-volume
      volumes:
      - name: nats-server-tls-clients-volume
        secret:
          secretName: nats-server-tls
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  labels:
    app.kubernetes.io/instance: nats
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: nats
    app.kubernetes.io/version: 2.9.16
    helm.sh/chart: nats-0.19.13
  name: nats
  namespace: holos-dev
spec:
  podManagementPolicy: Parallel
  replicas: 3
  selector:
    matchLabels:
      app.kubernetes.io/instance: nats
      app.kubernetes.io/name: nats
  serviceName: nats
  template:
    metadata:
      annotations:
        checksum/config: b06e68b1e108bc5c97d9d5a3925a67aedff53304dd17709225c3b484232505fd
        prometheus.io/path: /metrics
        prometheus.io/port: "7777"
        prometheus.io/scrape: "true"
      labels:
        app.kubernetes.io/instance: nats
        app.kubernetes.io/name: nats
    spec:
      containers:
      - command:
        - nats-server
        - --config
        - /etc/nats-config/nats.conf
        env:
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: SERVER_NAME
          value: $(POD_NAME)
        - name: POD_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        - name: CLUSTER_ADVERTISE
          value: $(POD_NAME).nats.$(POD_NAMESPACE).svc.cluster.local
        image: nats:2.9.16-alpine
        imagePullPolicy: IfNotPresent
        lifecycle:
          preStop:
            exec:
              command:
              - nats-server
              - -sl=ldm=/var/run/nats/nats.pid
        livenessProbe:
          failureThreshold: 3
          httpGet:
            path: /
            port: 8222
          initialDelaySeconds: 10
          periodSeconds: 30
          successThreshold: 1
          timeoutSeconds: 5
        name: nats
        ports:
        - containerPort: 4222
          name: client
        - containerPort: 7422
          name: leafnodes
        - containerPort: 6222
          name: cluster
        - containerPort: 8222
          name: monitor
        - containerPort: 443
          name: websocket
        readinessProbe:
          failureThreshold: 3
          httpGet:
            path: /
            port: 8222
          initialDelaySeconds: 10
          periodSeconds: 10
          successThreshold: 1
          timeoutSeconds: 5
        resources: {}
        startupProbe:
          failureThreshold: 90
          httpGet:
            path: /healthz
            port: 8222
          initialDelaySeconds: 10
          periodSeconds: 10
          successThreshold: 1
          timeoutSeconds: 5
        volumeMounts:
        - mountPath: /etc/nats-config
          name: config-volume
        - mountPath: /var/run/nats
          name: pid
        - mountPath: /etc/nats-config/auth
          name: auth
        - mountPath: /accounts/jwt
          name: nats-jwt-pvc
        - mountPath: /data
          name: nats-js-pvc
        - mountPath: /etc/nats-certs/clients/nats-server-tls
          name: nats-server-tls-clients-volume
        - mountPath: /etc/nats-certs/cluster/nats-server-tls
          name: nats-server-tls-cluster-volume
        - mountPath: /etc/nats-certs/ws/nats-server-tls
          name: nats-server-tls-ws-volume
      - command:
        - nats-server-config-reloader
        - -pid
        - /var/run/nats/nats.pid
        - -config
        - /etc/nats-config/nats.conf
        - -config
        - /etc/nats-certs/clients/nats-server-tls/ca.crt
        - -config
        - /etc/nats-certs/clients/nats-server-tls/tls.crt
        - -config
        - /etc/nats-certs/clients/nats-server-tls/tls.key
        - -config
        - /etc/nats-certs/cluster/nats-server-tls/ca.crt
        - -config
        - /etc/nats-certs/cluster/nats-server-tls/tls.crt
        - -config
        - /etc/nats-certs/cluster/nats-server-tls/tls.key
        - -config
        - /etc/nats-config/auth/auth.conf
        image: natsio/nats-server-config-reloader:0.10.1
        imagePullPolicy: IfNotPresent
        name: reloader
        resources: {}
        volumeMounts:
        - mountPath: /etc/nats-config
          name: config-volume
        - mountPath: /var/run/nats
          name: pid
        - mountPath: /etc/nats-certs/clients/nats-server-tls
          name: nats-server-tls-clients-volume
        - mountPath: /etc/nats-certs/cluster/nats-server-tls
          name: nats-server-tls-cluster-volume
        - mountPath: /etc/nats-certs/ws/nats-server-tls
          name: nats-server-tls-ws-volume
        - mountPath: /etc/nats-config/auth
          name: auth
      - args:
        - -connz
        - -routez
        - -subz
        - -varz
        - -prefix=nats
        - -use_internal_server_id
        - -jsz=all
        - -leafz
        - http://localhost:8222/
        image: natsio/prometheus-nats-exporter:0.10.1
        imagePullPolicy: IfNotPresent
        name: metrics
        ports:
        - containerPort: 7777
          name: metrics
        resources: {}
      dnsPolicy: ClusterFirst
      serviceAccountName: nats
      shareProcessNamespace: true
      terminationGracePeriodSeconds: 60
      volumes:
      - configMap:
          name: nats-config
        name: config-volume
      - name: auth
        secret:
          secretName: nats-auth-config
      - emptyDir: {}
        name: pid
      - name: nats-server-tls-clients-volume
        secret:
          secretName: nats-server-tls
      - name: nats-server-tls-cluster-volume
        secret:
          secretName: nats-server-tls
      - name: nats-server-tls-ws-volume
        secret:
          secretName: nats-server-tls
  volumeClaimTemplates:
  - metadata:
      name: nats-jwt-pvc
    spec:
      accessModes:
      - ReadWriteOnce
      resources:
        requests:
          storage: 1Gi
      storageClassName: ceph-ssd
  - metadata:
      name: nats-js-pvc
    spec:
      accessModes:
      - ReadWriteOnce
      resources:
        requests:
          storage: 10Gi
      storageClassName: ceph-ssd
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  labels:
    app.kubernetes.io/instance: nats
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: nats
    app.kubernetes.io/version: 2.9.16
    helm.sh/chart: nats-0.19.13
  name: nats
  namespace: holos-dev
spec:
  maxUnavailable: 1
  selector:
    matchLabels:
      app.kubernetes.io/instance: nats
      app.kubernetes.io/name: nats
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: nats-client-bastion-tls
  namespace: holos-dev
spec:
  emailAddresses:
  - root@bastion.ois.lan
  issuerRef:
    kind: ClusterIssuer
    name: cluster-issuer
  secretName: nats-client-bastion-tls
  usages:
  - signing
  - key encipherment
  - client auth
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: nats-client-shared-tls
  namespace: holos-dev
spec:
  emailAddresses:
  - shared@ois.run
  issuerRef:
    kind: ClusterIssuer
    name: cluster-issuer
  secretName: nats-client-shared-tls
  usages:
  - signing
  - key encipherment
  - client auth
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: nats-client-tls
  namespace: holos-dev
spec:
  commonName: nats-client
  issuerRef:
    kind: ClusterIssuer
    name: cluster-issuer
  secretName: nats-client-tls
  usages:
  - signing
  - key encipherment
  - client auth
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: nats-server-tls
  namespace: holos-dev
spec:
  commonName: nats.holos-dev.svc.cluster.local
  dnsNames:
  - nats
  - nats.holos-dev.svc
  - nats.holos-dev.svc.cluster.local
  - '*.nats'
  - '*.nats.holos-dev.svc'
  - '*.nats.holos-dev.svc.cluster.local'
  - nats.core1.ois.lan
  - nats.core1.ois.run
  - nats.pub.core1.ois.run
  ipAddresses:
  - 10.64.192.3
  issuerRef:
    kind: ClusterIssuer
    name: cluster-issuer
  secretName: nats-server-tls
  usages:
  - signing
  - key encipherment
  - server auth
  - client auth
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: nats-auth-config
spec:
  dataFrom:
  - extract:
      key: kv/core1/kube-namespace/holos-dev/nats-auth-config
  refreshInterval: 1h
  secretStoreRef:
    kind: SecretStore
    name: core-vault
  target:
    creationPolicy: Owner
    name: nats-auth-config
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: nats-sys-creds
spec:
  dataFrom:
  - extract:
      key: kv/core1/kube-namespace/holos-dev/nats-sys-creds
  refreshInterval: 1h
  secretStoreRef:
    kind: SecretStore
    name: core-vault
  target:
    creationPolicy: Owner
    name: nats-sys-creds
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: nats
  namespace: holos-dev
spec:
  endpoints:
  - path: /metrics
    port: metrics
  namespaceSelector:
    any: true
  selector:
    matchLabels:
      app.kubernetes.io/instance: nats
      app.kubernetes.io/name: nats
---
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: nats
spec:
  host: nats
  trafficPolicy:
    tls:
      mode: SIMPLE
---
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: nats-ws
  namespace: holos-dev
spec:
  gateways:
  - istio-ingress/wildcard-pub-gw
  hosts:
  - nats.pub.core1.ois.run
  http:
  - route:
    - destination:
        host: nats.holos-dev.svc.cluster.local
        port:
          number: 443
---
# Source: nats/templates/tests/test-request-reply.yaml
apiVersion: v1
kind: Pod
metadata:
  name: "nats-test-request-reply"
  labels:
    chart: nats-0.19.13
    app: nats-test-request-reply
  annotations:
    "helm.sh/hook": test
spec:
  containers:
  - name: nats-box
    image: natsio/nats-box:0.13.8
    env:
    - name: NATS_HOST
      value: nats
    command:
    - /bin/sh
    - -ec
    - |
      nats reply -s nats://$NATS_HOST:4222 'name.>' --command "echo 1" &
    - |
      "&&"
    - |
      name=$(nats request -s nats://$NATS_HOST:4222 name.test '' 2>/dev/null)
    - |
      "&&"
    - |
      [ $name = test ]

  restartPolicy: Never


```

</details>

## Comment — @jeffmccune (2023-06-29)

@wallyqs I unblocked myself by over-provisioning js-disk-storage from 128MiB to 256MiB.  It feels like there's a bug in the limit calculations since the stream size is well within the 128 MiB limit but I'll leave that determination up to you of course.

The only other stream in this account is a kv `CONFIG` bucket.  The KV_CONFIG stream is 32 MiB max and the DOM_ELEMENTS stream is 16 MiB max, which I'd expect to fit in the 128MiB account limit but I might misunderstand how replication is accounted for or something else.  It's notable 32x3+16x3 = 144 which may explain why a 256 MiB account limit works fine.

<details><summary>nats stream info KV_CONFIG</summary>

```console
Information for Stream KV_CONFIG created 2023-06-29 12:13:24

             Subjects: $KV.CONFIG.>
             Replicas: 3
              Storage: File

Options:

            Retention: Limits
     Acknowledgements: true
       Discard Policy: New
     Duplicate Window: 2m0s
           Direct Get: true
    Allows Msg Delete: false
         Allows Purge: true
       Allows Rollups: true

Limits:

     Maximum Messages: unlimited
  Maximum Per Subject: 1
        Maximum Bytes: 32 MiB
          Maximum Age: unlimited
 Maximum Message Size: 512 KiB
    Maximum Consumers: unlimited


Cluster Information:

                 Name: nats
               Leader: nats-2
              Replica: nats-0, current, seen 0.64s ago
              Replica: nats-1, current, seen 0.64s ago

State:

             Messages: 1
                Bytes: 219 B
             FirstSeq: 7 @ 2023-06-29T21:38:51 UTC
              LastSeq: 7 @ 2023-06-29T21:38:51 UTC
     Active Consumers: 0
   Number of Subjects: 1
```

</details>

<details><summary>Fails with nsc account edit --js-disk-storage 128MiB</summary>

```bash
nsc edit account \
    --conns 20 \
    --data 512MiB \
    --js-consumer 10 \
    --js-disk-storage 128MiB \
    --js-mem-storage 32MiB \
    --js-max-disk-stream 128MiB \
    --js-max-mem-stream 32MiB \
    --js-streams 3 \
    --js-consumer 10
```

```bash
nsc push
```

```bash
nats stream add \
  '--subjects=holos.releases.*.elements.>' \
  '--description=Persist dom elements for the web ui' \
  --storage=file \
  --replicas=3 \
  --retention=limits \
  --discard=old \
  --max-age=30d \
  --max-bytes=16MiB \
  --max-msg-size=256KiB \
  --max-msgs=-1 \
  --max-msgs-per-subject=1 \
  --dupe-window=120s \
  --no-allow-rollup \
  --allow-direct \
  --no-deny-delete \
  --no-deny-purge \
  DOM_ELEMENTS
```

```
nats: error: could not create Stream: insufficient storage resources available (10047)
```

</details>

<details><summary>Succeeds with nsc account edit --js-disk-storage 256MiB</summary>

```bash
nsc edit account \
    --conns 20 \
    --data 512MiB \
    --js-consumer 10 \
    --js-disk-storage 256MiB \
    --js-mem-storage 32MiB \
    --js-max-disk-stream 128MiB \
    --js-max-mem-stream 32MiB \
    --js-streams 3 \
    --js-consumer 10
```

```bash
nsc push
```

```bash
nats stream add \
  '--subjects=holos.releases.*.elements.>' \
  '--description=Persist dom elements for the web ui' \
  --storage=file \
  --replicas=3 \
  --retention=limits \
  --discard=old \
  --max-age=30d \
  --max-bytes=16MiB \
  --max-msg-size=256KiB \
  --max-msgs=-1 \
  --max-msgs-per-subject=1 \
  --dupe-window=120s \
  --no-allow-rollup \
  --allow-direct \
  --no-deny-delete \
  --no-deny-purge \
  DOM_ELEMENTS
```

```
Stream DOM_ELEMENTS was created                                                                                                                                                         [1/6884]

Information for Stream DOM_ELEMENTS created 2023-06-29 14:47:15

          Description: Persist dom elements for the web ui
             Subjects: holos.releases.*.elements.>
             Replicas: 3
              Storage: File

Options:

            Retention: Limits
     Acknowledgements: true
       Discard Policy: Old
     Duplicate Window: 2m0s
           Direct Get: true
    Allows Msg Delete: true
         Allows Purge: true
       Allows Rollups: false

Limits:

     Maximum Messages: unlimited
  Maximum Per Subject: 1
        Maximum Bytes: 16 MiB
          Maximum Age: 30d0h0m0s
 Maximum Message Size: 256 KiB
    Maximum Consumers: unlimited


Cluster Information:

                 Name: nats
               Leader: nats-0
              Replica: nats-1, current, seen 0.00s ago
              Replica: nats-2, current, seen 0.00s ago

State:

             Messages: 0
                Bytes: 0 B
             FirstSeq: 0
              LastSeq: 0
     Active Consumers: 0
```

</details>

## Comment — @wallyqs (2023-06-29)

thanks for the info, I will validate on my end whether this is a bug or something we can improve but good to hear that you are unblocked.

## Comment — @dee-ynput (2024-07-27)

I think I had the same issue.

I could not create more than a few (almost empty) streams before receiving err_code 10047 (or 10028 for memory streams).

I had to set jetstream max file to 100G instead of 10G in order to create my streams, even though my steams were less than 5Mo.

Hope this will help others to not lose the 3h I lost😭😅.
And thanks @jeffmccune for your detailed report which saved my night 🙏🦄 

<details>
<summary>here is the server varz</summary>
<pre>
{
  "server_id": "NAFKEFDYMDCFWY5ZUKMAQEQ6XQ4XFHCFYZ6DOKXBRKYUPFNQD2SFJV7S",
  "server_name": "ayon_nats",
  "version": "2.10.17",
  "proto": 1,
  "git_commit": "b91de03",
  "go": "go1.22.4",
  "host": "0.0.0.0",
  "port": 4221,
  "max_connections": 100,
  "max_subscriptions": 1000,
  "ping_interval": 60000000000,
  "ping_max": 3,
  "http_host": "0.0.0.0",
  "http_port": 8221,
  "http_base_path": "/",
  "https_port": 0,
  "auth_timeout": 2,
  "max_control_line": 2048,
  "max_payload": 65536,
  "max_pending": 10000000,
  "cluster": {

  },
  "gateway": {

  },
  "leaf": {

  },
  "mqtt": {

  },
  "websocket": {

  },
  "jetstream": {
    "config": {
      "max_memory": 1000000000,
      "max_storage": 100000000000,
      "store_dir": "/data/nats/jetstream",
      "sync_interval": 120000000000,
      "compress_ok": true
    },
    "stats": {
      "memory": 0,
      "storage": 4022205,
      "reserved_memory": 0,
      "reserved_storage": 37580963840,
      "accounts": 1,
      "ha_assets": 0,
      "api": {
        "total": 52,
        "errors": 4
      }
    }
  },
  "tls_timeout": 2,
  "write_deadline": 3000000000,
  "start": "2024-07-27T20:11:22.2576767Z",
  "now": "2024-07-27T20:16:15.5566358Z",
  "uptime": "4m53s",
  "mem": 21278720,
  "cores": 6,
  "gomaxprocs": 6,
  "cpu": 0,
  "connections": 2,
  "total_connections": 7,
  "routes": 0,
  "remotes": 0,
  "leafnodes": 0,
  "in_msgs": 5556,
  "out_msgs": 5738,
  "in_bytes": 3454832,
  "out_bytes": 413704,
  "slow_consumers": 0,
  "subscriptions": 71,
  "http_req_stats": {
    "/": 1,
    "/varz": 1
  },
  "config_load_time": "2024-07-27T20:11:22.2576767Z",
  "system_account": "$SYS",
  "slow_consumer_stats": {
    "clients": 0,
    "routes": 0,
    "gateways": 0,
    "leafs": 0
  }
}
</pre>
</details>

## Comment — @derhuerst (2024-12-04)

I just ran into this error too.

```
port: 4222
http_port: 8222
server_name: vbb_gtfs_rt_production_2
jetstream {
  max_mem: 2G
  max_file: 16G
  store_dir: /var/lib/jetstream
}
```

```shell
nats stream add  --defaults  --subjects='aus.istfahrt.>'  --description='VDV-454 AUS IstFahrt messages'  --ack --retention=limits --discard=old  --max-bytes='10G'  'AUS_ISTFAHRT_2'
```

## Comment — @derekcollison (2024-12-04)

`max_bytes` will reserve that for you against the jetstream limits for the servers and the account.

We currently do not do overcommit in the face of max_bytes.

## Comment — @derhuerst (2024-12-05)

I don't understand. Does this mean that using `max_bytes` for all streams is supposed to prevent this problem from occurring? That didn't work for me.

## Comment — @derekcollison (2024-12-05)

When you specify max_bytes that is now considered "used" for all intent and purposes such that you should never fail to add a message to that stream since we pre-check for the reservation against all server and account limits.

So even though they might be empty the system will see those as reserved and deny new streams if the capacity limit has been reached.

## Comment — @heimalne (2025-01-06)

Just wanted to leave a note for Arm Mac users using Docker: On Mac Docker creates a virtual machine with a "virtual size limit". When that limit is reached, running Nats inside a Docker container can also produce that insuffient storage error. The fix is to either increase the Docker limit, or prune/ delete old images.

## Comment — @derhuerst (2025-01-13)

> So even though they might be empty the system will see those as reserved and deny new streams if the capacity limit has been reached.

I just configured `max_file: 16G` for the NATS server, and then tried to add two JetStream streams with `--max-bytes=10G` & `--max-bytes=5G` (respectively). I still got the error message "nats: error: could not create Stream: insufficient storage resources available (10047)".

```shell
nats-server --version
# nats-server: v2.10.22
nats --version
# 0.1.5
```

## Comment — @metacoma (2025-04-08)

facing with the same issue

```bash
$ nats -s ${nats_url} stream ls
╭─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────╮
│                                                         Streams                                                         │
├─────────────────────────────────────────────────┬─────────────┬─────────────────────┬──────────┬─────────┬──────────────┤                                   
│ Name                                            │ Description │ Created             │ Messages │ Size    │ Last Message │                                   
├─────────────────────────────────────────────────┼─────────────┼─────────────────────┼──────────┼─────────┼──────────────┤                                   
│ KN_USER_BOB__HOST_UBUNTU_DEV_TO                 │             │ 2025-04-07 14:16:38 │ 0        │ 0 B     │ never        │                                   
│ KN_USER_BOB__HOST_UBUNTU_DEV_FROM               │             │ 2025-04-07 14:13:14 │ 3        │ 983 B   │ 1d1h42m41s   │                                   
│ KN_USER_BEBEBEKA__ALICE_HOST_BROKER_KNE_TRIGGER │             │ 2025-03-31 21:51:17 │ 225      │ 173 KiB │ 3d1h57m54s   │                                   
╰─────────────────────────────────────────────────┴─────────────┴─────────────────────┴──────────┴─────────┴──────────────╯
```

```
/ # du -h -s /data/jetstream/
116.0K  /data/jetstream/
```

```
[7] 2025/04/08 20:07:12.084012 [INF] Starting nats-server                                                                                                  │
[7] 2025/04/08 20:07:12.084133 [INF]   Version:  2.10.24
```

## Comment — @derekcollison (2025-04-11)

If you set max_bytes on a stream we use that to determine reservation and not overcommit.

## Comment — @derhuerst (2025-04-11)

But in my case, the sum of the two streams' `max_bytes` was *less* than NATS' `max_file`.

## Comment — @derekcollison (2025-04-11)

Can you upgrade to 2.10.27 and see if the issue persists?
