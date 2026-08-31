---
title: Install nats-server
type: operation
kind: runbook
area: [deploy, core, jetstream]
since: [2.10]
verified-against: nats-server 2.14.6
verified-on: 2026-08-31
tags: [install, systemd, docker, kubernetes, http_port, store_dir, LimitNOFILE, lame-duck]
aliases: [install, installation, "install NATS", "set up a server", "first server", nats-server service]
sources: [s-docs-getting-started, s-nats-server-signals, s-gh-6070-lame-duck-under-systemd, s-docs-single-server, s-docs-hardening, s-nats-server-systemd-units, s-docs-kubernetes]
created: 2026-08-31
updated: 2026-08-31
---

# Install nats-server

Get one `nats-server` running as a service you can **reload, drain and monitor** — the node
[[build-a-3-node-cluster]] then joins to two others. A single server is a real deployment for
development, for an edge device and for a small single-instance service, and a single point of
failure for anything else (source: [[s-docs-single-server]]).

## Goal

A running server with:

- a config **file** (not flags), so a change is a reload rather than a restart;
- the **monitoring port on** — it is off unless you turn it on;
- JetStream enabled with an explicit `store_dir`;
- a service unit that reloads on SIGHUP and **drains on stop**.

## Preconditions

- A host with a filesystem you are willing to give JetStream (`store_dir` is where the data lives),
  or Docker, or a Kubernetes cluster with a default storage class.
- Ports you can bind: **4222** clients, **8222** monitoring, and — if this node will ever cluster —
  **6222** routes (source: [[s-docs-hardening]]).
- Decide the JetStream store path **now**. Changing it later moves the data, and on Kubernetes it is
  a PVC you cannot casually re-point ([[s-docs-kubernetes]]).
- If this server will hold JetStream data and later become part of a cluster, **read
  [[streams-deleted-when-clustering-a-standalone-server]] first.** Adding a `cluster` block to a
  server that already has streams destroys them.

## Steps

### Get the binary

```
docker run -p 4222:4222 -p 8222:8222 nats:latest                        # container
brew install nats-server                                                # macOS
curl -sf https://binaries.nats.dev/nats-io/nats-server/v2@latest | sh   # Linux
sudo mv nats-server /usr/local/bin/
```

Windows is a manual download from GitHub Releases. Confirm what you got:

```
nats-server --version
```

(source: [[s-docs-getting-started]]). Pin the version you intend to run — `@latest` is convenient on
a laptop and wrong on a fleet, because a cluster should be upgraded deliberately
([[nats-server-2.14]]).

### Get the `nats` CLI too

The CLI is how you verify everything below, and it is a separate binary from the server:

```
brew install nats-io/nats-tools/nats                                    # macOS
curl -sf https://binaries.nats.dev/nats-io/natscli/nats@latest | sh     # Linux
sudo mv nats /usr/local/bin/
```

```
nats context add local --server nats://localhost:4222 --description "local dev" --select
```

See [[nats-cli]]. On Kubernetes the CLI arrives as [[nats-box]] instead.

### The config file

The smallest config worth deploying — every line earns its place (source:
[[s-docs-single-server]]):

```
# /etc/nats-server.conf
server_name: n1
port: 4222
http_port: 8222

jetstream {
  store_dir: "/var/lib/nats/js"
}
```

- **`server_name`** — what the logs, `/varz` and `nats server list` call this node. Under JetStream,
  server names must be unique within a domain (`inbox/config-keys-table.md`).
- **`http_port: 8222`** — **the monitoring endpoint is off by default.** Nothing else in this wiki's
  monitoring, health-check or probe advice works until this line exists ([[monitoring-endpoints]]).
- **`jetstream { store_dir }`** — enables JetStream and puts its data somewhere you chose. With no
  `max_file_store` / `max_memory_store`, the server picks its own limits from the filesystem — see
  [[jetstream-sizing]] before assuming what they are. **Both halves of this line matter.** Leaving
  `store_dir` out puts the whole store under the system temp directory, with one warning at startup
  (`Temporary storage directory used, data could be lost on system reboot`) and a real risk that a
  distribution's `tmpwatch`/`systemd-tmpfiles` reaps it — [[stream-directories-disappear]]. Leaving
  `max_file_store` out gives a limit that shrinks at every restart on anything before 2.14.6 —
  [[jetstream-out-of-disk]]. Set both.

Start it:

```
nats-server -c /etc/nats-server.conf
```

### Run it under systemd

Do not write a unit from scratch. The server repo ships two, and the hardened one is the one to
adapt (source: [[s-nats-server-systemd-units]], read verbatim from
`util/nats-server-hardened.service` at **v2.14.6**):

```ini
# /etc/systemd/system/nats-server.service
[Unit]
Description=NATS Server
After=network-online.target ntp.service
# If JetStream has its own filesystem, refuse to start when it is not mounted:
# ConditionPathIsMountPoint=/var/lib/nats

[Service]
Type=simple
EnvironmentFile=-/etc/default/nats-server
ExecStart=/usr/local/bin/nats-server -c /etc/nats-server.conf
ExecReload=/bin/kill -s HUP $MAINPID
ExecStop=/bin/kill -s SIGUSR2 $MAINPID

User=nats
Group=nats
Restart=on-failure
RestartSec=5
TimeoutStopSec=150

# JetStream requires 2 FDs open per stream; the default 1024 is not survivable.
LimitNOFILE=800000

ProtectSystem=strict
ReadWritePaths=/var/lib/nats
CapabilityBoundingSet=
MemoryDenyWriteExecute=true
NoNewPrivileges=true
PrivateDevices=true
PrivateTmp=true
PrivateUsers=true
ProtectHome=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectProc=invisible
RestrictAddressFamilies=AF_INET AF_INET6
SystemCallFilter=@system-service ~@privileged ~@resources
UMask=0077

[Install]
WantedBy=multi-user.target
```

```
sudo systemctl daemon-reload
sudo systemctl enable --now nats-server
```

**The three lines that matter operationally:**

| line | what it buys |
|---|---|
| `ExecReload=/bin/kill -s HUP $MAINPID` | `systemctl reload nats-server` applies a config change **without dropping connections** — the reloadable half of [[config-keys]] |
| `ExecStop=/bin/kill -s SIGUSR2 $MAINPID` | `systemctl stop` is a **lame-duck drain**, not a kill: the server stops advertising itself and spreads disconnects so clients reconnect elsewhere |
| `TimeoutStopSec=150` | `lame_duck_duration` (**`2m`**) plus buffer. Raise one and you must raise the other, or systemd kills the drain half-finished |

**The signals the unit wires, and the two it does not** (source: [[s-nats-server-signals]], read from
`server/signal.go` at v2.14.6):

| signal | `--signal` name | effect |
|---|---|---|
| `SIGHUP` | `reload` | re-read the config in place — [[reload-server-config]] |
| `SIGUSR2` | `ldm` | lame-duck drain, then exit — [[upgrade-a-cluster]] |
| `SIGUSR1` | `reopen` | re-open the log file: this is how you rotate logs |
| `SIGINT` | `quit` | stop now, no drain |
| `SIGTERM` | — | the same, **unless a drain is already running**, in which case it is ignored |
| `SIGKILL` | **`stop`** | **`--signal stop` sends SIGKILL** — the name is the trap |

Each is logged before it acts (`Trapped "user defined signal 2" signal`), which is the record of what
a node was asked to do.

**Get the signal right, and then use one drain path.** A unit with `ExecStop=/bin/kill -s SIGINT
$MAINPID` looks correct and never drains — that is a real report, at 2.10.19, where neither
`systemctl stop` nor `nats-server --signal ldm` shut the server down gracefully because of it. The
maintainer's rule in that thread: once the unit has an `ExecStop`, stop through `systemctl`, not with
`nats-server --signal` (source: [[s-gh-6070-lame-duck-under-systemd]]). Do not read a *fast* exit as
a failed drain either: with few or no client connections the server exits immediately, because
`lame_duck_duration` caps how long disconnects are spread over rather than how long the server waits.

`ProtectSystem=strict` makes the whole filesystem read-only except `ReadWritePaths`, so **`store_dir`
must be inside it** or the server cannot start. Certificates only need to be *read*, which `strict`
already allows (source: [[s-docs-hardening]]). `ProtectProc` needs systemd ≥ 247 and `PrivateIPC`
(in the upstream file, omitted above) needs ≥ 248.

### Docker

```
docker run -p 4222:4222 -p 8222:8222 nats:latest
```

JetStream is **off unless you ask for it** — `nats-server -js`, or a config file with a `jetstream`
block mounted into the container (source: [[s-docs-getting-started]]). A container with JetStream on
and no volume is a container that loses your streams.

### Kubernetes

Use the Helm chart; the workload must be a **StatefulSet**, which the chart already handles
(source: [[s-docs-kubernetes]]):

```
helm repo add nats https://nats-io.github.io/k8s/helm/charts/
helm install nats nats/nats -f values.yaml
```

```yaml
# values.yaml — one JetStream server
config:
  jetstream:
    enabled: true
    fileStore:
      pvc:
        size: 10Gi
```

Two chart facts that bite: the release name names the pods (`helm install nats …` → `nats-0`), and
**you must not bind the monitor port to `127.0.0.1` here** — the kubelet's probes connect to the pod
IP, so a loopback bind fails every probe and no pod goes ready (source: [[s-docs-hardening]]). See
[[nats-helm-charts]].

## Verify

```
nats server check connection --server nats://localhost:4222
```

A healthy server answers and the check reports OK (source: [[s-docs-single-server]]).

Then prove a message actually flows — two terminals:

```
nats sub "orders.>" --server nats://localhost:4222
nats pub orders.created '{"order_id":"ord_8w2k"}' --server nats://localhost:4222
```

```
[#1] Received on "orders.created"
{"order_id":"ord_8w2k"}
```

The monitoring port, which is the one thing an install can silently get wrong:

```
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8222/healthz     # 200
```

`/healthz` answers `200` healthy, `503` not ([[monitoring-endpoints]]). If it does not answer at all,
`http_port` is missing from the config.

And that JetStream is actually on:

```
nats stream add ORDERS --subjects 'orders.*' --storage file --replicas 1 --defaults
nats stream info ORDERS
```

## Rollback

```
sudo systemctl stop nats-server        # drains: SIGUSR2, up to TimeoutStopSec
sudo systemctl disable nats-server
```

**Stopping the service does not remove the data.** `store_dir` still holds every stream; a
reinstall on the same path picks them up again, and deleting that path is the irreversible step.
Take a backup before touching it (step 3 of the current plan writes
[[backup-and-restore-jetstream]]).

## Pitfalls

**The monitoring port is off by default.** `http_port` is not set unless you set it, and every probe,
scrape and health check in this wiki assumes it (source: [[s-docs-single-server]]).

**The default file-descriptor limit is 1024 and JetStream spends about two per stream**, before
client sockets and route connections. A node that runs out of FDs fails in ways that look like
network problems. `LimitNOFILE=800000` in the unit is the shipped answer (source:
[[s-nats-server-systemd-units]], [[s-docs-hardening]]).

**`--replicas 3` on one server is refused, not degraded:**

```
nats stream add ORDERS --subjects 'orders.*' --storage file --replicas 3 --defaults
```

> `replicas > 1 not supported in non-clustered mode`

That is error **10074** `JSStreamReplicasNotSupportedErr` ([[error-codes]]). Redundancy is a
cluster's job — [[replicas]], [[build-a-3-node-cluster]].

**Do not "upgrade" this server into a cluster later by adding a `cluster` block.** Streams that exist
on a standalone server are marked orphaned and deleted on the first clustered restart —
[[streams-deleted-when-clustering-a-standalone-server]]. Plan the cluster before the data exists, or
back up and restore into the new cluster.

**A `MemoryMax` below the working set is an OOM kill, not a limit.** `max_memory_store` is an
accounting limit checked as messages arrive and `GOMEMLIMIT` is a soft GC target; neither reserves
anything. systemd logs `Main process killed (oom-kill)` (source: [[s-docs-hardening]]). The shipped
unit leaves every resource cap commented out for exactly this reason.

**Running from flags instead of a file costs you the reload.** `nats-server -js -m 8222` is fine for a
demo; a config file is what makes `systemctl reload` meaningful ([[config-keys]]).

## Related

[[build-a-3-node-cluster]] · [[jetstream-sizing]] · [[monitoring-endpoints]] · [[config-keys]] ·
[[nats-cli]] · [[nats-box]] · [[nats-helm-charts]] · [[replicas]] ·
[[streams-deleted-when-clustering-a-standalone-server]] · [[nats-server]] · [[error-codes]] ·
[[reload-server-config]] · [[upgrade-a-cluster]] · [[tls-in-nats]] · [[subject-permissions]] ·
[[unauthenticated-clients-still-connect]] · [[rotate-tls-certificates]]

## Sources

[[s-docs-getting-started]] · [[s-docs-single-server]] · [[s-docs-hardening]] ·
[[s-nats-server-systemd-units]] · [[s-nats-server-signals]] ·
[[s-gh-6070-lame-duck-under-systemd]] · [[s-docs-kubernetes]]
