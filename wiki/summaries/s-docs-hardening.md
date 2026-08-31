---
title: "docs.nats.io — Hardening"
type: summary
area: [security, deploy, topology, monitoring]
source-url: https://docs.nats.io/learn/deployment/hardening.md
source-path: raw/nats-docs/learn/deployment/hardening.md
author: NATS documentation (Synadia Communications, Inc.)
article: Hardening
date: 2026-08-31          # the page is undated; this is the fetch date
version: "2.14"
tags: [tls, mtls, systemd, LimitNOFILE, ProtectSystem, GOMEMLIMIT, firewall, monitor-port]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# docs.nats.io — Hardening

TLS on every link, a sandboxed systemd unit, and a monitor port that is not on the internet. The
operator-side half of security — the credentials themselves come from the security chapter; this
page mounts them.

## Key claims

**There are three independent TLS blocks, one per kind of peer:**

- **client** — the top-level `tls {}` block;
- **cluster** — `cluster { tls {} }`, "securing the routes between `n1-east`, `n2-east`, and
  `n3-east`";
- **gateway** — `gateway { tls {} }`, for supercluster links.

"These blocks are independent. Turning on TLS for clients leaves the cluster routes plaintext until
you configure the cluster block too." The named failure: "An operator secures clients and sees the
encrypted client connection, then ships a cluster whose inter-node Raft traffic, including replicated
`ORDERS` data, is still unencrypted."

```
listen: "0.0.0.0:4222"

tls {
  cert_file: "/var/lib/nats/certs/server-cert.pem"
  key_file:  "/var/lib/nats/certs/server-key.pem"
  ca_file:   "/var/lib/nats/certs/ca.pem"
  verify:    true
}

cluster {
  name: "east"
  listen: "0.0.0.0:6222"
  routes: [
    "nats://n2-east:6222"
    "nats://n3-east:6222"
  ]
  tls {
    cert_file: "/var/lib/nats/certs/server-cert.pem"
    key_file:  "/var/lib/nats/certs/server-key.pem"
    ca_file:   "/var/lib/nats/certs/ca.pem"
    verify:    true
  }
}
```

**`verify: true` means different things on the two blocks.** On the client block it is what makes the
link mTLS: "without it the server proves itself to the client but never checks the client's
certificate". On routes it is redundant — "**the server forces mutual verification on them whether or
not you set `verify`**, because each end acts as both client and server on the route". The
consequence: "a node can't join just by knowing the route address; it must present a certificate that
chains to `ca_file`."

`verify_and_map: true` on the client block makes "the client certificate's subject … *be* the NATS
user".

**Certificate rotation is a reload, not a restart.** "The server re-reads `cert_file` and `key_file`
when it reloads its configuration … After the reload, new handshakes present the new certificate
while existing connections keep their session."

```
systemctl reload nats-server
```

**One publish proves the whole hardened path:**

```
nats pub orders.created \
  '{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}' \
  --server tls://nats.acme.internal:4222 \
  --tlsca /etc/nats/certs/ca.pem \
  --creds /etc/nats/creds/order-svc.creds
```

"Drop `--creds` and the server rejects the connection with an authorization error. Drop `--tlsca`
(or point the client at `nats://` instead of `tls://`) and the handshake fails before authentication
is even attempted." **The two failure shapes distinguish a TLS problem from an auth problem with one
command.**

**The hardened systemd unit.** "The NATS distribution ships a hardened unit
(`nats-server-hardened.service`) … you adapt it rather than write it from scratch." The extract the
page shows:

```
ExecStart=/usr/local/bin/nats-server -c /var/lib/nats/nats.conf
ExecReload=/bin/kill -s HUP $MAINPID

LimitNOFILE=800000

ProtectSystem=strict
ReadWritePaths=/var/lib/nats
MemoryDenyWriteExecute=true
ProtectKernelTunables=true
ProtectProc=invisible
PrivateDevices=true

CapabilityBoundingSet=
SystemCallFilter=@system-service ~@privileged ~@resources
```

"`LimitNOFILE=800000` lifts the file descriptor (FD) ceiling far above the default 1024. **Each
stream costs roughly two FDs**, and inter-node gossip plus client sockets add many more."
"`ProtectSystem=strict` mounts the entire filesystem read-only *except* the paths in
`ReadWritePaths`, which is why the TLS certificates and the JetStream store both live under
`/var/lib/nats`."

**The monitor port is the one link TLS does not cover.** "The server listens on four ports: **4222**
for clients, **6222** for cluster routes, **7222** for gateways, and **8222** for the HTTP monitor.
The first three carry TLS once you configure it. The monitor port does not: it serves `/varz`,
`/healthz`, and the rest in plaintext, and its `/varz` output leaks the server version,
connected-client count, and memory usage to anyone who can reach it."

```
http: "127.0.0.1:8222"
```

**…except on Kubernetes.** "The kubelet's startup, readiness, and liveness probes connect to the
pod's IP, not its loopback, so a `127.0.0.1` bind fails every probe and the pods never go ready.
There, keep the chart's default bind and restrict the port with a NetworkPolicy instead."

```
ufw allow 4222/tcp
ufw allow from 10.0.0.0/24 to any port 6222 proto tcp
ufw deny 8222/tcp
```

**Four pitfalls:**

1. **`ProtectSystem=strict` blocks writes, not reads.** Reading rotated certificates from outside
   `ReadWritePaths` on a SIGHUP works. "What genuinely fails under `strict` is the server *writing*
   to a path not listed — the JetStream `store_dir` (and the pid and ports-file directories) must sit
   inside `ReadWritePaths`, or the server can't come up."
2. **A memory cap below the working set gets the process OOM-killed.** "Neither reserves memory at
   startup: `max_memory_store` is an accounting limit checked as messages arrive, and `GOMEMLIMIT` is
   a soft target that only makes GC more aggressive." systemd logs
   `Main process killed (oom-kill)`. The recommendation:

   ```
   # With jetstream { max_memory_store: 4Gi }, size for the store plus buffers.
   MemoryMax=6G
   Environment=GOMEMLIMIT=5500MiB
   ```

   — `MemoryMax` above expected use, `GOMEMLIMIT` "somewhat below `MemoryMax` so GC reins memory in
   before the hard cap".
3. **A reachable `:8222/varz` is reconnaissance.** "the server version, the client count, and the
   memory footprint".
4. **A firewall blocking 6222 leaves nodes unable to form quorum.** "it's easy to deny 6222 to the
   world while forgetting to allow it *between* the east nodes … `n1-east`, `n2-east`, and `n3-east`
   each come up alone … and show as orphans that never join the `east` cluster."

## Practical takeaways

- **Three TLS blocks means three chances to leave a link plaintext**, and the cluster block is the
  one people miss — it is the link carrying replicated JetStream data.
- **Routes are mutually verified whether or not you ask.** That is the strongest argument for putting
  TLS on the cluster block: it turns the route port from "anyone who knows the cluster name" into
  "anyone holding a certificate from your CA".
- **The systemd unit is where the FD limit lives**, and 1024 is not survivable for a JetStream node —
  two FDs per stream before client sockets. See [[jetstream-sizing]].
- **`http: "127.0.0.1:8222"` is a host-only answer.** On Kubernetes it is an outage: every probe
  fails and no pod goes ready ([[nats-helm-charts]]).

## Notable quotes

> "An operator secures clients and sees the encrypted client connection, then ships a cluster whose
> inter-node Raft traffic, including replicated `ORDERS` data, is still unencrypted."

> "The kubelet's … probes connect to the pod's IP, not its loopback, so a `127.0.0.1` bind fails
> every probe and the pods never go ready."

## Relevance to the wiki

The systemd and firewall sections of [[install-nats-server]], the TLS-on-routes section of
[[build-a-3-node-cluster]], and the reload half of the wanted [[rotate-tls-certificates]]. The unit
the page adapts is read verbatim in [[s-nats-server-systemd-units]].

## Questions it answers

Contributes to Q50 (certificate rotation is a SIGHUP, not a restart) — the runbook that answers it is
step 4's.

## Pages touched

[[install-nats-server]] · [[build-a-3-node-cluster]] · [[jetstream-sizing]] ·
[[monitoring-endpoints]] · [[nats-helm-charts]] · [[config-keys]] · [[account]]
