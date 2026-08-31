---
title: "nats-server v2.14.6 — the shipped systemd units"
type: summary
area: [deploy, security]
source-url: https://github.com/nats-io/nats-server/tree/v2.14.6/util
source-path: raw/nats-server-src/systemd-units-v2.14.6.md
author: nats-io/nats-server maintainers
article: "util/nats-server.service and util/nats-server-hardened.service at tag v2.14.6"
date: 2026-08-27          # v2.14.6 publish date
version: "2.14.6"
tags: [systemd, ExecStop, SIGUSR2, lame-duck, LimitNOFILE, TimeoutStopSec, GOMEMLIMIT, hardening]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# nats-server v2.14.6 — the shipped systemd units

The two unit files in `util/` at tag **v2.14.6**, read because
[[s-docs-hardening]] names `nats-server-hardened.service` as the file to adapt but shows only an
extract. The extract omits the line that matters most to an operator: **`ExecStop`**.

## Key claims

**The three process signals, from `nats-server.service` (both units carry all three):**

```ini
ExecStart=/usr/sbin/nats-server -c /etc/nats-server.conf
ExecReload=/bin/kill -s HUP $MAINPID
ExecStop=/bin/kill -s SIGUSR2  $MAINPID
```

with the unit's own comment on the last line:

> "The nats-server uses SIGUSR2 to trigger Lame Duck Mode (LDM) shutdown"

So on a machine running the shipped unit, **`systemctl stop nats-server` is a lame-duck shutdown, not
a kill**: the server stops advertising itself and spreads client disconnects over
`lame_duck_duration` so they reconnect elsewhere. `systemctl reload` is the SIGHUP config reload.

**`TimeoutStopSec=150`**, with the reasoning stated in the file:

> "This should be `lame_duck_duration` + some buffer to finish the shutdown. By default,
> `lame_duck_duration` is 2 mins."

150s = 120s + 30s of buffer. `lame_duck_duration` is documented as `2m` and
`lame_duck_grace_period` as `10s` (`inbox/config-keys-table.md`, from
`raw/nats-docs/reference/config.md`), and the server defines the same two values as
`DEFAULT_LAME_DUCK_DURATION = 2 * time.Minute` and
`DEFAULT_LAME_DUCK_GRACE_PERIOD = 10 * time.Second` (`server/const.go:196` and `:200`, v2.14.6).

**Identity and restart policy**, in both units:

```ini
Type=simple
User=nats
Group=nats
Restart=on-failure
RestartSec=5          # hardened unit only
After=network-online.target ntp.service
```

**`ntp.service` in `After=` is deliberate**, and it is the only place in the sources read so far
where the server's dependency on a sane clock is expressed as configuration.

**File descriptors**, with the same comment the docs page paraphrases:

```ini
# Capacity Limits
# JetStream requires 2 FDs open per stream.
LimitNOFILE=800000
```

**`GOMEMLIMIT` is commented out in the shipped unit**, and the file recommends *not* putting it in
the unit at all:

> "You might find it better to set GOMEMLIMIT via /etc/default/nats-server, so that you can change
> limits without needing a systemd daemon-reload."

which is why the hardened unit carries `EnvironmentFile=-/etc/default/nats-server`. The resource
controls (`MemoryMax`, `CPUWeight`, `IOWeight`, accounting) are all present but **commented out**,
under "Replace weights by values that make sense for your situation".

**The full hardening set** — the docs page shows nine of these; the file has:

```ini
CapabilityBoundingSet=
LockPersonality=true
MemoryDenyWriteExecute=true
NoNewPrivileges=true
PrivateDevices=true
PrivateTmp=true
PrivateUsers=true
ProcSubset=pid
ProtectClock=true
ProtectControlGroups=true
ProtectHome=true
ProtectHostname=true
ProtectKernelLogs=true
ProtectKernelModules=true
ProtectKernelTunables=true
ProtectSystem=strict
ReadOnlyPaths=
RestrictAddressFamilies=AF_INET AF_INET6
RestrictNamespaces=true
RestrictRealtime=true
RestrictSUIDSGID=true
SystemCallFilter=@system-service ~@privileged ~@resources
UMask=0077
InaccessiblePaths=/etc/ssh
ProtectProc=invisible     # systemd >= 247
PrivateIPC=true           # systemd >= 248
ReadWritePaths=/var/lib/nats
```

Two of these carry a **systemd version floor in a comment** — `ProtectProc` needs ≥ 247 and
`PrivateIPC` needs ≥ 248 — so the file is not copy-safe onto an older distribution without removing
them.

**Paths differ from the docs page.** The units use `ExecStart=/usr/sbin/nats-server -c
/etc/nats-server.conf`; [[s-docs-hardening]] shows `/usr/local/bin/nats-server -c
/var/lib/nats/nats.conf`. Both are examples; `ReadWritePaths=/var/lib/nats` is the one path that must
match wherever `store_dir` actually is.

**Two commented hints that are really deployment advice:**

```ini
# If you use a dedicated filesystem for JetStream data, then you might use something like:
# ConditionPathIsMountPoint=/srv/jetstream
```

```ini
# If you install this service as nats-server.service and want 'nats'
# to work as an alias, then uncomment this next line:
#Alias=nats.service
```

## Practical takeaways

- **`ExecStop=/bin/kill -s SIGUSR2 $MAINPID` is the single most valuable line in the file**, and it
  is missing from the docs page's extract. Without it, `systemctl stop` sends SIGTERM and clients are
  dropped rather than drained — which is the difference between a rolling upgrade that is invisible
  and one that is not.
- **`TimeoutStopSec` and `lame_duck_duration` are coupled.** Raise one and you must raise the other,
  or systemd kills the process partway through the drain.
- **The hardened unit is deliberately conservative about resource caps**: every one is commented out,
  because a cap set below the working set is an OOM kill ([[s-docs-hardening]]).
- **`ConditionPathIsMountPoint`** is the cheapest possible guard against the classic JetStream
  accident: the data volume failing to mount and the server happily writing to the root filesystem
  underneath it.

## Notable quotes

> "The nats-server uses SIGUSR2 to trigger Lame Duck Mode (LDM) shutdown"

> "This should be `lame_duck_duration` + some buffer to finish the shutdown."

## Relevance to the wiki

The systemd section of [[install-nats-server]] — quoted from the file rather than from the docs
page's extract — and the drain step every rolling upgrade depends on ([[upgrade-a-cluster]], step 2
of the current plan).

## Questions it answers

Contributes to Q63 (a rolling upgrade's per-node drain is `systemctl stop` *only* when the unit
carries this `ExecStop`).

## Pages touched

[[install-nats-server]] · [[build-a-3-node-cluster]] · [[jetstream-sizing]] · [[config-keys]] ·
[[defaults-and-limits]]
