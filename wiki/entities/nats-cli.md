---
title: natscli (the nats CLI)
type: entity
kind: tool
area: [core, jetstream, monitoring, deploy, security]
verified-against: natscli v0.4.0
verified-on: 2026-08-31
tags: [tool, cli, nats, contexts, check, bench, auth]
aliases: [natscli, nats, nats cli, "nats-io/natscli"]
sources: [s-docs-ecosystem, s-github-repo-facts, s-docs-getting-started, s-docs-prometheus-and-dashboards]
created: 2026-08-31
updated: 2026-08-31
---

# natscli (the nats CLI)

**The one tool an operator actually lives in.** `nats` publishes and subscribes, manages streams and
consumers, inspects a running cluster through the system account, runs benchmarks and health checks,
and manages operators, accounts and users through `nats auth` (source: [[s-docs-ecosystem]]).

## Where it fits

Every command line in this wiki's runbooks and gotchas is this binary. It reaches JetStream through
[[jsm-go]], the same library [[nack]] and the Terraform provider use — which is why its view of a
stream matches theirs exactly.

## Facts

| | |
|---|---|
| repo | `nats-io/natscli` |
| latest release | **v0.4.0**, 2026-05-01 |
| licence | Apache-2.0 |
| binary | **`nats`** (the repo is `natscli`; the command is `nats`) |
| contexts stored in | `~/.config/nats/context` — JSON, one file per context |
| under it | [[jsm-go]] |
| bundled in | [[nats-box]] |

```
brew install nats-io/nats-tools/nats                              # macOS
curl -sf https://binaries.nats.dev/nats-io/natscli/nats@latest | sh   # Linux
go install github.com/nats-io/natscli/nats@latest                 # from source
scoop bucket add extras && scoop install extras/natscli           # Windows
```

## What an operator needs to know

- **`nats auth` is the built-in identity tool, and it is not yet complete.** The docs state the gap
  precisely: "A few `nsc` capabilities aren't in `nats auth` **v0.4.0** yet — activation tokens and
  importing a single account into an existing operator among them. For those, keep using `nsc` on the
  same store" (`learn/security/operator-mode.md`). Both tools read the **same nsc-compatible store**,
  so this is a per-command choice, not a per-deployment one. See [[nsc]].
- **Contexts are the difference between safe and terrifying.** A context bundles server URLs and
  credentials under a name — "You can also add authentication configuration here, such as `user` and
  `password` or `creds`" — and `nats context select` switches the target of every later command. Running
  a `purge` against the wrong cluster is a context mistake, not a typo.
- **`nats server check` is the alerting surface**, not a human one — it emits Nagios-style exit codes
  and a Prometheus `textfile` format. **A check with no explicit threshold never fires**
  (source: [[s-docs-prometheus-and-dashboards]]).
- **Check thresholds can live on the asset.** Since natscli 0.2.0, stream and consumer checks
  auto-configure from metadata: a check that accepts `--msgs-warn` reads the metadata key
  `io.nats.monitor.msgs-warn` when the flag is absent.
- **`--defaults` in the docs' examples means "accept every unspecified value"** — convenient in a
  tutorial, dangerous in production, where the unspecified values are exactly the ones
  [[defaults-and-limits]] exists for.

## Cheat sheet

**Contexts**

```
nats context add orders \
  --server nats://localhost:4222 \
  --user order-svc --description "ORDERS prod"
nats context add nats --server demo.nats.io:4222 --description "NATS Demo" --select
nats context select orders
nats context ls
nats context unselect
```

**Streams**

```
nats stream ls
nats stream add ORDERS --subjects "orders.>" --storage file --replicas 3 --retention limits --defaults
nats stream info ORDERS
nats stream edit ORDERS --max-age=7d
nats stream edit ORDERS --replicas=3
nats stream edit ORDERS --discard new --max-msgs 1
nats stream subjects ORDERS                 # per-subject message counts
nats stream view ADVISORIES
nats stream get ORDERS --last-for orders.shipped
nats stream find --replicas=1               # every R1 stream in the account
nats stream purge ORDERS --subject orders.shipped
nats stream purge ORDERS --keep 50
nats stream rmm ORDERS 2                    # delete one message by sequence
nats stream backup  ORDERS ./backups/orders/2026-06-04 --consumers
nats stream restore ./backups/orders/2026-06-04
nats stream cluster step-down ORDERS --preferred n2-east
```

**Consumers**

```
nats consumer add  ORDERS shipping --pull --ack explicit --defaults
nats consumer add  ORDERS shipping --pull --ack explicit --filter "orders.eu" --defaults
nats consumer info ORDERS shipping
nats consumer info ORDERS shipping --json
nats consumer next ORDERS shipping --count 10 --ack --timeout 5s
nats consumer next ORDERS shipping --term          # terminate instead of acking
nats consumer pause  ORDERS shipping "1h" --force
nats consumer resume ORDERS shipping --force
nats consumer unpin  ORDERS sequencer ordered      # release a pinned client
nats consumer rm     ORDERS shipping --force
```

**KV and Object Store**

```
nats kv add     INVENTORY --history 1
nats kv status  INVENTORY
nats kv put     INVENTORY widget-blue 42
nats kv get     INVENTORY widget-blue --raw
nats kv history INVENTORY widget-blue
nats kv watch   INVENTORY
nats kv purge   INVENTORY widget-red
nats object add  INVOICES --description "Invoice PDFs"
nats object put  INVOICES invoice-ord_8w2k.pdf --chunk-size 524288 --force
nats object get  INVOICES invoice-ord_8w2k.pdf --output ./invoice.pdf
nats object ls   INVOICES
nats object info INVOICES invoice-ord_8w2k.pdf
nats object rm   INVOICES invoice-ord_8w2k.pdf
```

**The cluster, through the system account**

```
nats server list
nats server info n1-east
nats server report jetstream
nats server report routes      # the mesh inside a cluster
nats server report gateways    # between clusters
nats server report leafnodes
nats server cluster step-down                  # move the meta leader
nats server request profile heap --name=n1-east ./profiles
nats account info
```

**Health checks and alerting**

```
nats server check connection --server nats://localhost:4222
nats server check stream   --stream=ORDERS --peer-expect=3
nats server check consumer --stream ORDERS --consumer shipping \
  --unprocessed-critical 100 --redelivery-critical 10
nats server check message  --stream ORDERS ...   # canary-message freshness
```

Stream-check thresholds worth naming: `--lag-critical=MSGS` and `--seen-critical=DURATION` for
sources and mirrors, `--peer-expect=SERVERS`, `--peer-lag-critical=OPS`,
`--peer-seen-critical=DURATION` for Raft peers, `--msgs-warn` / `--msgs-critical` for depth.

**Traffic, latency and subject mapping**

```
nats pub orders.created '{"order_id":"ord_8w2k"}'
nats sub "orders.>"
nats request orders.inventory.check '{"sku":"widget-blue"}'
nats rtt --server nats://n1:4222,nats://n2:4222,nats://n3:4222
nats bench pub test --msgs 10000000 --clients 2 --no-progress
nats trace orders.us.created
nats server mappings "orders.created.*" "orders.created.{{partition(3, 1)}}.{{wildcard(1)}}" orders.created.ord_8w2k
```

**Identity** — see [[nsc]] for the same operations in the standalone tool.

```
nats auth operator add ACME
nats auth account add ORDERS --defaults
nats auth user add order-svc ORDERS --defaults --credential order-svc.creds
nats auth user credential order-svc.creds order-svc ORDERS --expire 720h -f
nats auth account push ORDERS -s nats://127.0.0.1:4222 --creds sys.creds
nats auth operator backup ACME acme-operator.backup --key backup-curve.nk
```

## Related

[[nsc]] · [[nk]] · [[nats-box]] · [[nats-top]] · [[jsm-go]] · [[monitoring-endpoints]] ·
[[defaults-and-limits]] · [[prometheus-nats-exporter]] · [[nats-server]]

## Sources

[[s-docs-ecosystem]] · [[s-github-repo-facts]] · [[s-docs-getting-started]] ·
[[s-docs-prometheus-and-dashboards]]
