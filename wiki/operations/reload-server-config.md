---
title: Reload server config
type: operation
kind: runbook
area: [deploy, security, core]
since: [2.10]
verified-against: nats-server 2.14.6
verified-on: 2026-08-31
tags: [reload, SIGHUP, dry-run, include, reloader, configmap, accounts, max_subscriptions]
aliases: [reload, SIGHUP, "config reload", "reload config", "add an account", "nats-server --signal reload"]
sources: [s-docs-config-management, s-nats-server-signals, s-nats-helm-chart-values-2.14.6, s-docs-hardening, s-docs-accounts-and-multitenancy, s-nats-server-topology, s-nats-server-tls-reload, s-docs-websocket-tls-and-proxies, s-gh-7684-certificate-expiry, s-docs-cross-account, s-docs-putting-it-together, s-relnotes-2.10, s-relnotes-2.11, s-relnotes-2.12, s-relnotes-2.14]
created: 2026-08-31
updated: 2026-09-03
---

# Reload server config

Apply a config change to a running server **without dropping a connection**: validate the file, send
SIGHUP, confirm the log line. The rule that decides whether this works at all is one sentence from
the docs (source: [[s-docs-config-management]]):

> "A reload can change *policy* (who connects, what they may do, how much they may store), but it
> can't change *identity* (the addresses the server and its cluster bind, or where JetStream keeps
> its data)."

Identity changes need a restart, therefore [[upgrade-a-cluster]].

## Goal

A changed config live on every node, with no client reconnect and no window where a node is running
a half-applied file.

## Preconditions

- **The change is reloadable.** Check it in [[config-keys]] or `inbox/config-keys-table.md` — of 621
  documented keys, **411 are marked reloadable** and **174 restart-only**, with 150 of the reloadable
  ones carrying caveats on their own page.
- **The cluster is settled.** Not mid-rebalance, not mid-roll (see *Pitfalls*).
- Shell access to send the signal, or the reloader sidecar on Kubernetes.

## Steps

### 1. Split the file so a change is reviewable

```
# /etc/nats-server.conf
server_name: $SERVER_NAME
listen: "0.0.0.0:4222"

cluster {
  name: "east"
  listen: "0.0.0.0:6222"
  routes: [ "nats://nats-0.nats-headless:6222", "nats://nats-1.nats-headless:6222" ]
}

jetstream { store_dir: "/data/jetstream" }

include "tls.conf"
include "accounts/orders.conf"
```

**An `include` path is relative to the directory of the file that contains it**, not to your working
directory — so the server resolves it the same way whether you launch it from `/` or from
`/etc`. Use absolute paths when in doubt.

**Quoting rule, which bites exactly once:** an **unquoted** `$NAME` resolves a config variable and
then an environment variable, and an unset one is a parse error the dry-run catches. A **quoted**
`"$NAME"` is the literal string — which is why bcrypt hashes, full of `$`, are the values you *do*
quote.

### 2. Know what a reload can change

**Reloadable** (source: [[s-docs-config-management]]):

- accounts, users and permissions — including **adding an account** ([[account]]);
- `max_connections`, `max_payload`, `max_control_line` — **but not `max_subscriptions`, which a
  reload rejects**;
- most JetStream account limits, **and the `jetstream` enable flag itself** — a reload turns
  JetStream on or off;
- TLS `cert_file` / `key_file` paths — the server re-reads the files on reload;
- cluster `routes`, and logging;
- since **2.14**, leafnode `remotes` can be added and removed by reload with no restart
  ([[nats-server-2.14]]);
- **cross-account exports and imports** — the docs' own walkthrough ends "apply with a reload:
  `nats-server --signal reload=<pid>` (or a restart)", and neither side of the share observes the
  wiring: the exporting service publishes exactly as before, and a third account sees nothing unless
  it too imports (source: [[s-docs-cross-account]]). See [[cross-account-sharing]].

**Not reloadable**: `port` / `listen`; the cluster's listen host and port; the JetStream `store_dir`.
**Gateway routes are not reloadable either** — a reload can only refresh their TLS material.

**In operator mode, account limits are not in this file at all.** They live in the account JWT the
resolver holds; edit and push the JWT ([[account]], [[nsc]]). No reload moves them. **The same is
true of shares**: `nats auth account exports add` / `imports add` change only the local store, and
"both changed account JWTs must then be pushed to the server; until then the share silently doesn't"
take effect (source: [[s-docs-cross-account]]). Reaching for SIGHUP after an `nsc` or `nats auth` edit
is the reflex to unlearn — the operation you want is `push`.

### 3. Validate, then signal

```
nats-server -c /etc/nats-server.conf -t && systemctl reload nats-server
```

The dry-run parses the file and exits without touching the running server: valid prints
`nats-server: configuration file ... is valid` and exits zero, broken prints the parse error with the
offending line and exits non-zero — which is what makes it usable as a gate in a script.

**Gate on the dry-run, not on the signal.** `nats-server --signal reload` **exits 0 even when the
server refused the reload**. The refusal is in the server's log and nowhere else:

```
[ERR] Failed to reload server configuration: nats.conf:5:1: error parsing X509 certificate/key pair: tls: private key does not match public key
```

Observed on the v2.14.6 binary (source: [[s-nats-server-tls-reload]]). The refusal is safe — the
previous configuration stays active and the server keeps serving — but a script that treats the
signal's exit status as "applied" will report success for a change that never landed. Nor do the
`Reloaded:` lines help: a reload that changed nothing prints the same ones.

**What `-t` does not check is whether the server can *start*.** "A JetStream cluster missing
`server_name` or `routes` passes `-t` yet still fails to boot."

That is not a gap in coverage — it is the boundary of what `-t` is. `-t` parses; the semantic checks
live in `validateOptions`, which runs inside `NewServer` (`server.go:729`), long after the parser is
done. **Every** `validateOptions` failure therefore passes the dry run and kills the server on start.
Three reproduced on v2.14.6 (source: [[s-nats-server-topology]]):

| config | `-t` says | starting says |
|---|---|---|
| `lame_duck_grace_period` ≥ `lame_duck_duration` | valid | `lame duck grace period (1m0s) should be strictly lower than lame duck duration (30s)` |
| `gateway {}` with no `port` | valid | `gateway "east" has no port specified (select -1 for random port)` |
| `leafnodes { listen }` + `gateway {}` with no `system_account` | valid | `leaf nodes and gateways (both being defined) require a system account to also be configured` |

The last one is the docs' own composed topology example (`inbox/docs-issues.md` #24).

**So a config gate that only runs `-t` is not a gate.** For a change that touches a topology block,
`lame_duck_*`, or anything else `validateOptions` covers, verify by **starting a server** on the new
file — on a scratch host, or with `-p -1 -m -1` and a throwaway `store_dir` — before you reload or
restart the real one. A reload of an unstartable config is survivable; the **restart** after it is
not.

The signal itself is **SIGHUP**, wired to `systemctl reload` by the shipped unit
([[install-nats-server]]). Equivalent forms:

```
systemctl reload nats-server
nats-server --signal reload
kill -HUP $(cat /var/run/nats/nats.pid)
```

Do it on **every node** — a reload is per-process, and a cluster whose nodes disagree about accounts
is worse than one that has not been changed yet.

### 4. Kubernetes: the reloader sidecar does it

The config arrives as a ConfigMap; editing it changes the file on disk and **nothing tells the server
to re-read it**. That is the sidecar's job: it watches the mounted file with inotify and sends SIGHUP
to the PID in `/var/run/nats/nats.pid`. It ships enabled (source:
[[s-nats-helm-chart-values-2.14.6]]):

```yaml
reloader:
  enabled: true
  natsVolumeMountPrefixes:
    - /etc/
```

**`natsVolumeMountPrefixes` is the constraint that catches people**: only volumes mounted under
`/etc/` are mounted into the reloader container, so a config or certificate mounted somewhere else is
never watched and its change never produces a SIGHUP. It retries if the server is briefly
unreachable — 30 retries, four seconds apart — and takes `--force-poll` through `reloader.merge`
where inotify does not work.

For a change that is **not** reloadable, the chart has the other door:

```yaml
podTemplate:
  configChecksumAnnotation: true   # a ConfigMap change now rolls the StatefulSet
```

That is a rolling restart, so it belongs to [[upgrade-a-cluster]]'s rules, not this page's.

## Verify

The server logs the reload:

```
Reloaded server configuration
```

and, on failure, `Failed to reload server configuration: <error>` (source:
[[s-nats-server-signals]]). Check the node is still serving and no client reconnected:

```
nats server list                 # every node up, uptime unchanged — a reload is not a restart
nats server info n1-east
```

For an account or permission change, verify with the credential rather than the config:

```
nats pub orders.created '{"order_id":"ord_8w2k"}' --creds /etc/nats/creds/order-svc.creds
```

## Rollback

**A failed reload needs no rollback.** The server validates the new config first and, on a parse or
validation failure, **the old config stays active** — the reload is atomic: "either the new config
applies cleanly, or nothing changes". The worst case is that nothing happened.

To undo a *successful* reload, restore the previous file and reload again. Keep the config in version
control; that is the rollback.

## Reload over the system account (since 2.10.0)

Besides SIGHUP and `nats-server --signal reload`, a server reloads its config on a request to
**`$SYS.REQ.SERVER.<server-id>.RELOAD`** in the system account — "Reload server config by sending a
message in the system account" (2.10.0, #4307) (source: [[s-relnotes-2.10]]); the subject is
`serverReloadReqSubj` in `server/events.go` at v2.14.6, line 70. It is the one reload path that
needs no access to the process, and it is **documented nowhere in the docs** (`inbox/docs-issues.md`
#54). Two 2.10 fixes on the reload path itself: mapping updates for the global account propagate
to leafnodes again (2.10.8, #4937), and a server started with `--js --store_dir` no longer has
JetStream disabled by a reload (2.10.28, #6609).


## Verify the running config with the digest (since 2.11.0)

`nats-server -t` prints a **configuration state digest** — "A hash of the configuration file can be
generated using the `-t` option on the command line" — and `/varz` reports the hash of the config
the server is running as **`config_digest`** (2.11.0, #4325) (source: [[s-relnotes-2.11]]). Compare
the two after a reload to know the server took the file you think it did. `config_digest` is
documented nowhere in the docs (`inbox/docs-issues.md` #57). Reload fixes along the line: a panic
adding a dedicated route on reload with no pinned routes and no system account (2.11.0, #6668); a
gateway TLS reload applies to implicit remotes (2.11.4, #6886); the parser errors on
self-referencing environment variables (2.11.12, #7737); gateway `pinned_certs` reload corrected
(2.11.17).


## What became reloadable in 2.12

- **`max_mem_store` and `max_file_store` "can now be increased (but not decreased) via config
  reload"** (2.12.7, #8014); `/varz` reports the new limits after the reload from 2.12.14 (#8394)
  (source: [[s-relnotes-2.12]]).
- **`leafnodes { remotes [ { disabled } ] }`** reloads: false → true disconnects the solicited
  leafnode and stops it reconnecting, true → false solicits it again (2.12.0, #7054).
- **`jetstream { meta_compact_sync: true }` by reload** is the mitigation the 2.12.5 body prescribes
  for its consumer-loss regression.
- 2.12.6 fixed the configuration digest removing entries from used-variable tracking, "which could
  cause configuration fields to disappear from the returned config" (#7959).


## Pitfalls

**Never SIGHUP an unvalidated config.** The server would keep the old one anyway, but the failure
belongs in your terminal, not in the server log at 3am — and it is the *only* place it will appear,
since the signal command exits 0 regardless (source: [[s-nats-server-tls-reload]]).

**Lowering a store limit does not evict data.** Drop an account's `max_file` below what a stream
already holds, reload, and the messages stay while **new writes fail** until someone trims the stream
under the limit. The reload changes the ceiling, not the contents. Raise limits freely; lower them
after checking what is stored ([[jetstream-sizing]]).

**Do not reload during a rebalance or a rolling upgrade.** A SIGHUP while JetStream is moving
replicas or handing off Raft leadership competes with that work. Wait for a named leader and
caught-up replicas ([[rebalance-streams]], [[upgrade-a-cluster]]).

**`max_subscriptions` sits in a group of reloadable limits and is not one.** The per-client key and
the per-account `accounts.…max_subscriptions` are different keys with different behaviour
([[config-keys]]).

**A certificate that has already expired is not a reload problem.** Rotation *is* a reload — replace
the file, SIGHUP, and new handshakes present the new certificate while open connections keep their
session. That much is measured, not assumed: at v2.14.6 the reload picks up a replaced `cert_file` on
a client listener and on a leafnode remote alike, but `config_digest` and every log line stay
identical to a no-op reload's, so `/varz`'s `tls_cert_not_after` is the only confirmation
(source: [[s-nats-server-tls-reload]]). But once the certificate has expired the server presents a dead one and **every new
connection and every reconnect fails the handshake** until you drop in a valid file and reload. Track
expiry; rotate with margin ([[rotate-tls-certificates]]).

That distinction is worth stating because the public thread this was investigated from reads as a
reload defect and is not one: the reporter's certificate had already expired, and a reload that
changes nothing looks identical to one that worked (source: [[s-gh-7684-certificate-expiry]]).

**`-t` is a parse check, not a start check.** A config can validate and still refuse to boot: the
docs' own composed example — `cluster {}`, `gateway {}`, `leafnodes { listen }` and `jetstream {}` on
one server — has no `system_account`, and `validateLeafNodeOptions` stops the server with
`leaf nodes and gateways (both being defined) require a system account to also be configured`
(`server/leafnode.go:343–350` at v2.14.6; source: [[s-docs-putting-it-together]], recorded as
`inbox/docs-issues.md` #24). On a *reload* this is the harmless direction — the old config stays
active — but it means a change that passed review and passed `-t` can still turn the next restart
into an outage. Startup-only failures like this one are why the verify step below reads the log, not
the exit code. See [[account]] and [[build-a-3-node-cluster]].

**A reload applied on one node is not applied on the cluster.** Signal every node, and on Kubernetes
confirm the sidecar actually watched the path you changed.

## `websocket { … }` is nearly all-or-nothing

Worth a line of its own because it is the block most likely to be edited during an incident, and its
reload rule is unlike the rest of the server's (source: [[s-docs-websocket-tls-and-proxies]]).

**Only certificate material reloads.** Changing `cert_file` or `key_file` and sending a reload picks
up the new certificate for connections made afterwards; existing connections keep the one they
negotiated — the same rule as any other listener.

**Everything else in the block is rejected — and a rejected field aborts the whole reload**, including
changes in the same edit that would have been accepted. So editing `allowed_origins` and a certificate
path together lands **neither**. `verify_and_map`, `pinned_certs`, `allowed_origins` and the timeouts
all fall on that side.

The practical rule: treat any `websocket {}` change except a certificate path as a **restart**, and
make certificate rotations their own edit. See [[websocket]] and [[run-nats-behind-a-proxy]].

## Version notes: the 2.14 line

**2.14.0**: **`leafnodes { remotes }` can be added and removed by reload** (#7937) — a new remote no
longer needs a restart; `feature_flags` is a new top-level block, and the docs mark it *Requires
Restart* (source: [[s-relnotes-2.14]]). **2.14.4**: `/varz` reports the JetStream limits after a
reload changed them (#8394) — before it, `max_file_store` raised by reload (2.12.7) was applied but
not shown. **2.14.5**: `dial_timeout` arrives; whether it reloads was not tested.


## Related

[[install-nats-server]] · [[upgrade-a-cluster]] · [[rebalance-streams]] · [[config-keys]] ·
[[account]] · [[nats-helm-charts]] · [[rotate-tls-certificates]] · [[jetstream-sizing]] ·
[[nats-server-2.14]] · [[nsc]] · [[build-a-3-node-cluster]] · [[tls-in-nats]] ·
[[cross-account-sharing]] · [[unauthenticated-clients-still-connect]] · [[operator-mode]] ·
[[leafnode]] · [[gateway]]

## Sources

[[s-docs-config-management]] · [[s-nats-server-signals]] · [[s-nats-helm-chart-values-2.14.6]] ·
[[s-docs-hardening]] · [[s-docs-accounts-and-multitenancy]] · [[s-nats-server-topology]] ·
[[s-nats-server-tls-reload]] ·
[[s-docs-websocket-tls-and-proxies]] ·
[[s-gh-7684-certificate-expiry]] ·
[[s-docs-cross-account]] · [[s-docs-putting-it-together]] · [[s-relnotes-2.10]] · [[s-relnotes-2.11]] · [[s-relnotes-2.12]] · [[s-relnotes-2.14]]
