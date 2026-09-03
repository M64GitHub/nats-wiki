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
sources: [s-docs-getting-started, s-nats-server-signals, s-gh-6070-lame-duck-under-systemd, s-docs-single-server, s-docs-hardening, s-nats-server-systemd-units, s-docs-kubernetes, s-docs-config-management, s-docs-encryption-and-tls, s-docs-forming-a-cluster, s-docs-rolling-upgrades, s-docs-your-first-cluster, s-gh-3569-connect-to-route-port, s-gh-5924-filestore-dirs-vanished, s-nats-helm-chart-values-2.14.6, s-nats-server-lame-duck, s-nats-server-route-cluster-formation, s-gh-6748-cve-binary-release-docker-images, s-relnotes-2.10, s-relnotes-2.11, s-relnotes-2.12]
created: 2026-08-31
updated: 2026-09-03
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
  **6222** routes (source: [[s-docs-hardening]]). What that route port then does — seed routes, the
  INFO gossip that turns one configured peer into a full mesh, and the cluster-name check on both
  ends — is [[build-a-3-node-cluster]]'s subject (sources: [[s-docs-your-first-cluster]],
  [[s-docs-forming-a-cluster]], [[s-nats-server-route-cluster-formation]]).
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
  distribution's `tmpwatch`/`systemd-tmpfiles` reaps it — reported in the field as 45 of 50 stream
  directories gone weeks after deployment, with `nats stream info` still listing every stream
  (source: [[s-gh-5924-filestore-dirs-vanished]]; [[stream-directories-disappear]]). Leaving
  `max_file_store` out gives a limit that shrinks at every restart on anything before 2.14.6 —
  [[jetstream-out-of-disk]]. Set both.

**Split it with `include` once it grows, and know the two rules.** An `include` path is resolved
"relative to the directory of the config file that contains it, not to the directory you launch the
server from", so a unit that starts from `/` still resolves it. And **an unquoted `$NAME` is a
variable** — it resolves a config-defined variable and then an environment variable, and an unset one
is a parse error — while a quoted `"$NAME"` is the literal string. That inversion is why **bcrypt
hashes, full of `$`, are the values you do quote** (source: [[s-docs-config-management]]).

**Test the file before you start or reload it:**

```
nats-server -c /etc/nats-server.conf -t
```

Start it:

```
nats-server -c /etc/nats-server.conf
```

**Know what a reload will and will not accept before you rely on it.** The principle the docs state:
"A reload can change *policy* (who connects, what they may do, how much they may store), but it can't
change *identity* (the addresses the server and its cluster bind, or where JetStream keeps its
data)." So `port` / `listen`, the cluster's listen host and port and the JetStream `store_dir` need a
restart, while accounts, users, permissions, `max_connections`, `max_payload`, TLS certificate paths,
cluster routes and even the `jetstream` enable flag do not — with `max_subscriptions` as the odd one
out, rejected by a reload despite sitting among reloadable limits (source:
[[s-docs-config-management]]; [[reload-server-config]], [[config-keys]]).

### TLS, if this server is reachable by anything but localhost

Three TLS blocks exist, one per kind of peer, and **they are independent** — turning on TLS for
clients leaves cluster routes and gateway links in plaintext until each block is configured too
(source: [[s-docs-encryption-and-tls]]). A single server only needs the first:

```
tls {
  cert_file: "/var/lib/nats/certs/server-cert.pem"
  key_file:  "/var/lib/nats/certs/server-key.pem"
  ca_file:   "/var/lib/nats/certs/ca.pem"
  verify:    true
}
```

`verify: true` on the **client** block is what makes the link mTLS; without it the server proves
itself to the client and never checks the client's certificate. On routes it is redundant — the
server forces mutual verification there whether or not you set it. Certificate paths are reloadable,
which is what makes [[rotate-tls-certificates]] a reload rather than a restart. The full treatment is
[[tls-in-nats]].

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

Upgrading this binary later is `systemctl stop` (which drains, via the `ExecStop` above), replace the
binary, `systemctl start`. On a **cluster** the order matters — non-leaders first, the meta-leader
last and drained — and that procedure is [[upgrade-a-cluster]] (source:
[[s-docs-rolling-upgrades]]).

**The three lines that matter operationally:**

| line | what it buys |
|---|---|
| `ExecReload=/bin/kill -s HUP $MAINPID` | `systemctl reload nats-server` applies a config change **without dropping connections** — the reloadable half of [[config-keys]] |
| `ExecStop=/bin/kill -s SIGUSR2 $MAINPID` | `systemctl stop` is a **lame-duck drain**, not a kill: the server stops advertising itself and spreads disconnects so clients reconnect elsewhere |
| `TimeoutStopSec=150` | `lame_duck_duration` (**`2m`**) plus buffer. Raise one and you must raise the other, or systemd kills the drain half-finished |

`TimeoutStopSec` has to cover more than that timer: on SIGUSR2 the server first steps down **every**
Raft group it leads and shuts JetStream down, and only then starts spreading client disconnects over
`lame_duck_duration` — the timer governs client eviction and nothing else (source:
[[s-nats-server-lame-duck]], `Server.lameDuckMode()` at v2.14.6).

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

Two more, read from the chart at tag **nats-2.14.6** rather than from a doc page (source:
[[s-nats-helm-chart-values-2.14.6]]):

- **The shipped drain arithmetic has no slack.** The chart's own comment gives the rule —
  `terminationGracePeriodSeconds` ≥ `lameDuckGracePeriod` + `lameDuckDuration` + 20s overhead — and
  its defaults satisfy it *exactly*: `10s + 30s + 20s = 60`. Raise `lameDuckDuration` by one second
  without raising `terminationGracePeriodSeconds` and the kubelet's SIGKILL lands **inside** the
  drain window. The chart's `30s` is also the server's documented **minimum** and a third of the
  server's own `2m` default, while [[upgrade-a-cluster]] advises against running at the minimum.
- **The config-reloader sidecar ships enabled and only watches `/etc/`.**
  `natsVolumeMountPrefixes: [/etc/]` means a config file or a certificate mounted anywhere else is
  never seen by the reloader, so its change never produces a SIGHUP and the server keeps running the
  old one — silently. Mount under `/etc/`, or extend the list.

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

## A CVE fix as a binary-only release, and the Docker image

CVE-2025-30215 (CRITICAL, "affecting all NATS Server versions from v2.2.0, prior to v2.11.1 or
v2.10.27") shipped on 2025-03-31 as `v2.10.27-binary` and `v2.11.1-binary`: GitHub releases with
binaries only, the source and the tags a week later (2025-04-08) — "for workflows that rely on
building from source, we recommend using the binary in the interim" (source: [[s-relnotes-2.10]]).
The official `nats` image on Docker Hub is **not built by the NATS team** — "The builds are not done
by us but docker. We are in the queue already though" — but by Docker's official-images pipeline from
a pull request the team opens; the `-binary` images appeared within the day, the Alpine variants of
the tagged releases only after the docker-library PR (#18802) merged on 2025-04-08, "and it will
still take some time for the images to be built" (source:
[[s-gh-6748-cve-binary-release-docker-images]]). So: patch a CRITICAL CVE from the GitHub binary, or
an image you build from it, on day one; the Hub tag and the Helm chart that pins it follow their own
queue.


## Version notes: the 2.11 line

- **A graceful `SIGTERM` exits 0 from 2.11.0** — "will now return exit code 0 instead of exit code
  1" (#6336); 2.11.10 fixes the code when the signal arrives right after startup (#7367) (source:
  [[s-relnotes-2.11]]). A unit that treated the old exit 1 as a failure, or a restart policy keyed on
  it, behaves differently after the upgrade.
- 2.11.8 added community-contributed builds for Solaris and Illumos (#7122).
- The CVE cadence of early 2026 — 2.11.14 (2026-03-09), 2.11.15 (2026-03-24), 2.11.16 (2026-04-14)
  — shipped the same days as 2.12.5, 2.12.6 and 2.12.7; the Docker-image lag described above applies
  to each.


## Version notes: the 2.12 line

**2.12.6**: "when running as a Windows service, switching to lame duck mode should now correctly
exit the process" (#7958). **2.12.12**: per-connection log lines that were noisy in normal operation
demoted to debug (#8289); JSONP callback support removed from the monitoring endpoints. **2.12.5**:
`max_conns: 0` refuses every client connection (#7877) — a way to drain a server without stopping
it (source: [[s-relnotes-2.12]]).


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

**Clients connect to 4222, never to 6222.** Pointing a client at the route port half-works and logs

```
[ERR] 192.168.0.3:57824 - rid:10 - attempted to connect to route port
```

The `rid:` prefix is a *route* connection id — the server logged your client as a route because it
arrived on the route listener. "`cluster` routes are meant to be used only for other nodes (servers)
to connect and form a cluster. Clients should connect to the listen URL of one of the nodes"
(source: [[s-gh-3569-connect-to-route-port]]). If you want a hub-and-spoke shape, the answer is
leafnodes, not routes — [[leafnode]], [[choosing-a-topology]].

**Running from flags instead of a file costs you the reload.** `nats-server -js -m 8222` is fine for a
demo; a config file is what makes `systemctl reload` meaningful ([[config-keys]]).

## Related

[[build-a-3-node-cluster]] · [[jetstream-sizing]] · [[monitoring-endpoints]] · [[config-keys]] ·
[[nats-cli]] · [[nats-box]] · [[nats-helm-charts]] · [[replicas]] ·
[[streams-deleted-when-clustering-a-standalone-server]] · [[nats-server]] · [[error-codes]] ·
[[reload-server-config]] · [[upgrade-a-cluster]] · [[tls-in-nats]] · [[subject-permissions]] ·
[[unauthenticated-clients-still-connect]] · [[rotate-tls-certificates]] · [[leafnode]] ·
[[choosing-a-topology]] · [[stream-directories-disappear]] · [[jetstream-out-of-disk]]

## Sources

[[s-docs-getting-started]] · [[s-docs-single-server]] · [[s-docs-hardening]] ·
[[s-nats-server-systemd-units]] · [[s-nats-server-signals]] ·
[[s-gh-6070-lame-duck-under-systemd]] · [[s-docs-kubernetes]] · [[s-docs-config-management]] ·
[[s-docs-encryption-and-tls]] · [[s-docs-forming-a-cluster]] · [[s-docs-rolling-upgrades]] ·
[[s-docs-your-first-cluster]] · [[s-gh-3569-connect-to-route-port]] ·
[[s-gh-5924-filestore-dirs-vanished]] · [[s-nats-helm-chart-values-2.14.6]] ·
[[s-nats-server-lame-duck]] · [[s-nats-server-route-cluster-formation]] · [[s-gh-6748-cve-binary-release-docker-images]] · [[s-relnotes-2.10]] · [[s-relnotes-2.11]] · [[s-relnotes-2.12]]
