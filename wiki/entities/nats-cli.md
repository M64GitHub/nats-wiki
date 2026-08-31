---
title: natscli (the nats CLI)
type: entity
kind: tool
area: [core, jetstream, monitoring, deploy, security]
verified-against: natscli v0.4.0
verified-on: 2026-08-31
tags: [tool, cli, nats, contexts, check, bench, auth]
aliases: [natscli, nats, nats cli, "nats-io/natscli"]
sources: [s-natscli-backup-restore, s-docs-ecosystem, s-github-repo-facts, s-docs-getting-started, s-docs-prometheus-and-dashboards, s-natscli-account-tls, s-docs-authentication-basics, s-docs-operator-mode, s-docs-decentralized-auth]
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
nats stream backup  ORDERS ./backups/orders/2026-06-04 --consumers   # --consumers is the default
nats stream backup  ORDERS ./backups/orders/2026-06-04 --check       # verify checksums first
nats stream backup  ORDERS ./b --chunk-size 64k --window-size 1m     # for a slow or distant link
nats stream restore ./backups/orders/2026-06-04
nats stream restore ./b --cluster west --tag ssd --replicas 1        # restore elsewhere, smaller
nats stream cluster step-down ORDERS --preferred n2-east
nats stream cluster peer-remove ORDERS n4-east   # move ONE replica off a server
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
nats server check connection --server nats://localhost:4222   # no system account needed
nats server list
nats server info n1-east
nats server report jetstream
nats server report routes      # the mesh inside a cluster
nats server report gateways    # between clusters
nats server report leafnodes
nats server cluster step-down                  # move the meta leader
nats server cluster peer-remove n4-east        # drop a server from the meta group (one at a time)
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

**Identity** — see [[nsc]] for the same operations in the standalone tool, and
[[set-up-operator-mode]] for the order to run them in.

```
nats auth operator add ACME
nats auth operator select ACME
nats auth account add ORDERS --defaults
nats auth account keys add ORDERS order-writer --pub-allow 'orders.>' --sub-allow '_INBOX.>'
nats auth user add order-svc ORDERS --key order-writer --defaults --credential order-svc.creds
nats auth user credential order-svc.creds order-svc ORDERS --expire 720h -f
nats auth user info order-svc ORDERS
nats auth user rm order-svc ORDERS --revoke -f
nats auth account push  ORDERS -s nats://127.0.0.1:4222 --creds sys.creds
nats auth account query ORDERS -s nats://127.0.0.1:4222 --creds sys.creds
nats auth account exports add Shipments "orders.shipped" ORDERS
nats auth account imports add Shipments "orders.shipped" ANALYTICS --source <ORDERS-key> --local orders.shipped
nats auth operator backup ACME acme-operator.backup --key backup-curve.nk
nats auth nkey gen account --output issuer.nk
nats auth nkey show issuer.nk
nats server generate ./acme-server
```

**`push` is not optional and `query` is how you check it.** An `edit`, a `keys add` or a
`user rm --revoke` changes only the local store; the running server keeps validating against the copy
its resolver holds ([[operator-mode]]).

**Certificates and account data**

```
nats account tls --expire-warn 30d
nats account tls --ocsp --no-pem
nats account backup ./acct-backup --check --consumers
nats account restore ./acct-backup --cluster east
nats server passwd --pass "s3cr3t-rotate-me-later"
```

`nats account tls` reports **every certificate of every verified chain** on the connection the CLI
already has — no `handshake_first`, no monitoring port, no `openssl`. `--expire-warn` defaults to
**`1w`** (`0` disables it) and the command **exits non-zero** when anything is expired or expiring, so
it drops straight into cron. Its `#   Expiration:` line is emitted for every certificate deliberately,
"to have a stable grep pattern" (source: [[s-natscli-account-tls]]). See
[[rotate-tls-certificates]].

`nats server passwd` hashes a password with bcrypt at **cost 11** by default (`--cost` to raise it,
`--generate` to invent one) and **refuses anything under 10 characters** (source:
[[s-docs-authentication-basics]]).

## Related

[[nsc]] · [[nk]] · [[nats-box]] · [[nats-top]] · [[jsm-go]] · [[monitoring-endpoints]] ·
[[defaults-and-limits]] · [[prometheus-nats-exporter]] · [[nats-server]] · [[operator-mode]] ·
[[set-up-operator-mode]] · [[rotate-tls-certificates]] · [[tls-in-nats]] · [[account]]

## Sources

[[s-docs-ecosystem]] · [[s-github-repo-facts]] · [[s-docs-getting-started]] ·
[[s-docs-prometheus-and-dashboards]] · [[s-natscli-account-tls]] ·
[[s-docs-authentication-basics]] · [[s-docs-operator-mode]] · [[s-docs-decentralized-auth]]
