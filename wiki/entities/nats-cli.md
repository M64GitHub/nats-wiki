---
title: natscli (the nats CLI)
type: entity
kind: tool
area: [core, jetstream, monitoring, deploy, security]
verified-against: natscli v0.4.0
verified-on: 2026-08-31
tags: [tool, cli, nats, contexts, check, bench, auth]
aliases: [natscli, nats, nats cli, "nats-io/natscli"]
sources: [s-natscli-backup-restore, s-docs-ecosystem, s-github-repo-facts, s-docs-getting-started, s-docs-prometheus-and-dashboards, s-natscli-account-tls, s-docs-authentication-basics, s-docs-operator-mode, s-docs-decentralized-auth, s-natscli-stream-external, s-docs-putting-it-together, s-docs-jetstream-in-a-cluster, s-docs-publishing, s-docs-altering-stream-state, s-docs-subject-mapping, s-docs-kv-ttl-and-limits, s-docs-kv-your-first-bucket, s-docs-accounts-and-multitenancy, s-docs-authorization, s-docs-config-and-jwt-backup, s-docs-forming-a-cluster, s-docs-kubernetes, s-docs-single-server, s-docs-stream-backup-restore, s-docs-your-first-cluster, s-gh-6605-which-consumer-is-slow, s-gh-7684-certificate-expiry, s-gh-7854-jwt-push-timeout, s-nats-server-snapshot-restore, s-nats-server-mirrors-observed, s-nats-go-kv-object-mirror, s-issue-5106-object-store-mirror-list, s-nats-server-system-subjects-observed, s-nats-cli-help-0.4.0, s-natscli-auth-exports-imports, s-nats-cli-core-commands, s-nats-server-core-delivery-observed, s-docs-core-nats-publish-subscribe, s-docs-core-nats-subjects-and-mapping, s-nats-cli-request-reply-source, s-nats-server-request-reply-observed, s-docs-core-nats-request-reply, s-docs-core-nats-queue-groups, s-adr-47-request-many, s-nats-cli-reconnect, s-nats-server-client-lifecycle-observed, s-docs-resilient-clients-drain-and-shutdown, s-docs-resilient-clients-connecting, s-docs-resilient-clients-reconnection-and-events]
created: 2026-08-31
updated: 2026-09-04
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
| `nats auth` store | `$XDG_DATA_HOME/nats` (default `~/.local/share/nats`) — **nsc-compatible**: `stores/<OPERATOR>/…` holds JWTs, `keys/keys/O\|A\|U/…/*.nk` holds seeds |
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
  a `purge` against the wrong cluster is a context mistake, not a typo. The docs' own single-server
  walkthrough writes `--server nats://localhost:4222` on every line instead, which is the honest form
  for a one-off: no stored state to be wrong about (source: [[s-docs-single-server]] — the same page's
  `--replicas 3` refusal, `replicas > 1 not supported in non-clustered mode`, is a server rule and
  lives on [[replicas]]).
- **`nats server check` is the alerting surface**, not a human one — it emits Nagios-style exit codes
  and a Prometheus `textfile` format. **A check with no explicit threshold never fires**
  (source: [[s-docs-prometheus-and-dashboards]]).
- **Check thresholds can live on the asset.** Since natscli 0.2.0, stream and consumer checks
  auto-configure from metadata: a check that accepts `--msgs-warn` reads the metadata key
  `io.nats.monitor.msgs-warn` when the flag is absent.
- **`--defaults` in the docs' examples means "accept every unspecified value"** — convenient in a
  tutorial, dangerous in production, where the unspecified values are exactly the ones
  [[defaults-and-limits]] exists for.
- **A permissions failure reaches the CLI as a timeout, not as a denial.** Every JetStream API call is
  a request under the hood, so a locked-down user running `nats stream info` fails with
  `context deadline exceeded` rather than a permission error — the publish is denied, no responder
  ever sees it, and the CLI just waits (source: [[s-docs-authorization]]; see
  [[subject-permissions]]). The evidence is server-side, and it names the CLI: `[ERR] … -
  "v1.51.0:go:NATS CLI Version v0.4.0" - "$G/user:order-svc" - Publish Violation - Subject
  "billing.charge"`. The same shape appears one level up: **`nats account info` printing an info block
  with no `Account:` line at all** is a permissions symptom, not a server problem — the CLI asks the
  server over `$SYS.REQ.USER.INFO` and the user's publish allow list blocks that request
  (source: [[s-docs-accounts-and-multitenancy]]).
- **Every `nats server …` command needs a system-account user, and most tutorials' configs do not
  have one.** The docs say it plainly of their own cluster walkthrough: the commands "query the system
  account (`$SYS`), which these configs don't set up; add one … and connect with its credentials
  before you run them" (source: [[s-docs-forming-a-cluster]]). Declaring your own `accounts` block is
  what takes the user away — see [[account]]. `nats server account info SYS` and
  `nats account info` both report `System Account: true`/`false`, which is the quickest check that the
  credentials you are holding are the ones the `server` commands need
  (source: [[s-docs-accounts-and-multitenancy]]).
- **The `Routes` column of `nats server list` counts connections, not peers.** "Each link to a peer is
  a small pool of connections (three by default) plus a dedicated system-account route, so a
  three-server cluster shows several per server" — two peers × (3 pooled + 1 system) = the 8 a healthy
  three-node cluster prints. **What confirms the mesh is that the count is the same on every row and
  non-zero**, never its absolute value (source: [[s-docs-forming-a-cluster]]; `cluster.pool_size`
  defaults to 3 — see [[build-a-3-node-cluster]]).
- **Under Kubernetes, pick one owner per stream: the CLI or the CRD, never both.** [[nack]] re-creates
  a stream that has been deleted (it notices on its ~30-second resync) but does **not** revert a manual
  `nats stream edit` — the change sticks until the CRD itself next changes. Run NACK with
  `--control-loop` and it also enforces config drift, reverting your edit on about a one-minute cycle
  (source: [[s-docs-kubernetes]]). Verification from inside the cluster is
  `kubectl exec -it deploy/nats-box -- sh` and then `nats stream info ORDERS`; see [[nats-box]].
- **`nats-top` is a different binary, and it is not a reliable way to find a flagged slow consumer.**
  There is no `nats top` subcommand — see [[nats-top]] — and the community's suggested
  `nats-top -sort pending` was reported not to work, with `Pending: 0` on every connection while the
  counter still reported slow consumers (source: [[s-gh-6605-which-consumer-is-slow]]). The symptom and
  what is actually known about it live on [[slow-consumer-detected]].

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

**Publishing**

```
nats pub --jetstream orders.created '{"order_id":"ord_8w2k"}'     # reads the PubAck
nats pub --jetstream orders.created --header "Nats-Msg-Id:ord_8w2k-created" '{…}'
printf '%s\n' '{"line":"sku-1"}' '{"line":"sku-2"}' \
  | nats pub --atomic --send-on=newline --force-stdin orders.created
nats bench js pub async orders.created --batch 1000                # the only async path in the CLI
nats bench js pub fast                                             # fast-ingest, benchmark only
nats pub orders.created "order {{Count}}" --count 100 --sleep 1s --trace   # watch client failover
```

**`--trace` on a long `--count` run is the cheapest demonstration of server-driven failover**: kill the
server the CLI is attached to and it prints `>>> Disconnected due to: EOF, will attempt reconnect`
followed by `>>> Reconnected to nats://localhost:4223` — a server you never named, learned from the
`INFO` the first one sent. `no_advertise: true` is the one control that turns that off
(source: [[s-docs-your-first-cluster]]; see [[build-a-3-node-cluster]]).

**A plain `nats pub` is a core publish** and prints `Published N bytes` whether or not a stream stored
the message. Only `--jetstream` reads the `PubAck` and surfaces a missed subject as
`nats: error: nats: no responders available for request` (source: [[s-docs-publishing]]; see
[[publishing]]). And **`nats stream rmm` securely erases** — it overwrites the stored bytes — where a
client's `DeleteMsg` does not (source: [[s-docs-altering-stream-state]]).

**Key/Value**

```
nats kv add INVENTORY --history 1                       # --history caps at 64; 1 is the default
nats kv put INVENTORY widget-blue 42                    # unconditional
nats kv create INVENTORY flash-sale 99 --ttl 30m        # CAS against revision 0; --ttl on CREATE only
nats kv update INVENTORY widget-blue 40 "$REVISION"     # CAS against a named revision
nats kv edit INVENTORY --history 10 --marker-ttl 1h     # raising history is not retroactive
nats kv get INVENTORY widget-blue --raw                 # --raw prints the value without the entry
nats kv watch INVENTORY widget-blue                     # snapshot, then live
nats kv history INVENTORY widget-blue
nats kv del INVENTORY widget-blue                       # marker, history kept
nats kv purge INVENTORY widget-red                      # rollup marker, history dropped
```

**`--ttl` is accepted on `create` only**, and a later `put` or `update` silently drops it — the key
stops expiring rather than keeping its clock (source: [[s-docs-kv-ttl-and-limits]]). The CLI parses
`MB`/`KB` as **binary** units, so `--max-bucket-size 16MB` prints back as `16 MiB`. See
[[key-value]].

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
nats stream rmm ORDERS 2                    # delete one message by sequence -- SECURELY ERASES
nats stream edit ORDERS --transform-source "ingest.*" --transform-destination "orders.{{partition(3,1)}}.{{wildcard(1)}}"
nats stream edit ORDERS --republish-source "orders.>" --republish-destination "dash.orders.>"
nats server mappings "orders.*" "orders.{{wildcard(1)}}.archived" orders.created   # test a transform
nats stream backup  ORDERS ./backups/orders/2026-06-04 --consumers   # --consumers is the default
nats stream backup  ORDERS ./backups/orders/2026-06-04 --check       # verify checksums first
nats stream backup  ORDERS ./b --chunk-size 64k --window-size 1m     # for a slow or distant link
nats stream restore ./backups/orders/2026-06-04
nats stream restore ./b --cluster west --tag ssd --replicas 1        # restore elsewhere, smaller
nats stream cluster step-down ORDERS --preferred n2-east
nats stream cluster peer-remove ORDERS n4-east   # move ONE replica off a server
```

**What `--chunk-size` and `--window-size` are actually tuning.** The server cuts the tarball into
chunks and pushes them to an inbox subject, keeping a window's worth of unacknowledged chunks in
flight — **8 MiB by default, which is 64 of the default 128 KiB chunks** — and **if no ack arrives for
about five seconds the backup aborts**. That five-second abort, not throughput, is why a slow or
distant link needs the smaller chunk and window (source: [[s-docs-stream-backup-restore]], numbers
confirmed against the server in [[s-nats-server-snapshot-restore]]). Consumer state is included by
default and **nothing warns you** when `--no-consumers` drops it — until the consumer is missing in
production. See [[backup-and-restore-jetstream]].

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
nats auth nkey gen curve --output backup-curve.nk                    # the seal key: a CURVE key
nats auth operator backup  ACME acme-operator.backup --key backup-curve.nk
nats auth operator restore ACME acme-operator.backup --key backup-curve.nk
nats auth nkey gen account --output issuer.nk
nats auth nkey show issuer.nk
nats server generate ./acme-server
```

**Backup and restore of the identity plane, and the three things that catch people out.** An
unsealed `nats auth operator backup` prints its own warning — "the output file is unencrypted and
contains secrets, consider encrypting it with `nats auth nkey seal`" — and whoever holds that one file
*is* the operator. `--key` takes a **file path, not the key string**. `restore` keeps the original
keys, so **every creds file you handed out before the disaster keeps working**, and it refuses to run
over an existing operator (`nats: error: operator ACME already exist`) — move the old store aside
first. Neither backup nor restore touches the server: the resolver directory is still empty until you
`nats auth account push`, and until then a client gets `nats: error: nats: Authorization Violation`
(source: [[s-docs-config-and-jwt-backup]]). See [[backup-and-restore-identity]].

**`SYSTEM` is pre-created and its user is not.** `nats auth operator add` makes the `SYSTEM` account
for you, but there is no user inside it, so `nats auth user add sys SYSTEM --defaults` and
`nats auth user credential sys.creds sys SYSTEM` come **before** any push — a push with no system user
is one of the ways `$SYS.REQ.CLAIMS.UPDATE` has nothing listening. `nats auth operator select` is
required too and the docs' own walkthrough omits it. `nats server generate` is interactive: choose
*"'nats auth' managed NATS Server configuration"* to get a `server.conf` that already trusts the
operator (source: [[s-gh-7854-jwt-push-timeout]]). See [[set-up-operator-mode]].

**`push` is not optional and `query` is how you check it.** An `edit`, a `keys add` or a
`user rm --revoke` changes only the local store; the running server keeps validating against the copy
its resolver holds ([[operator-mode]]).

**Permissions, in the JWT world**

```
nats auth user edit order-svc ORDERS --pub-allow "orders.>"
```

**Each flag replaces that entire list**, so always pass the complete set of subjects — a second
`--pub-allow` run is not additive (source: [[s-docs-authorization]]). See [[subject-permissions]].

**Certificates and account data**

```
nats account info --user analytics-reader --password an4lytics
nats server account info SYS --user sys-admin --password syspass
nats sub '$SYS.SERVER.>' --user sys-admin --password syspass
nats account tls --expire-warn 30d
nats account tls --ocsp --no-pem
nats account backup ./acct-backup --check --consumers
nats account restore ./acct-backup --cluster east
nats server passwd --pass "s3cr3t-rotate-me-later"
```

`nats account tls` reports **every certificate of every verified chain** on the connection the CLI
already has — no `handshake_first`, no monitoring port, no `openssl`. That last one is the point
rather than a convenience: `openssl s_client -connect host:4222` normally fails against NATS, because
the server sends its plaintext `INFO` line before the TLS handshake, so the CLI's own connection is
the shortest path to an expiry date on a server you cannot reconfigure
(source: [[s-gh-7684-certificate-expiry]]; `/varz` exposes `tls_cert_not_after` as the other route —
[[monitoring-endpoints]]). `--expire-warn` defaults to
**`1w`** (`0` disables it) and the command **exits non-zero** when anything is expired or expiring, so
it drops straight into cron. Its `#   Expiration:` line is emitted for every certificate deliberately,
"to have a stable grep pattern" (source: [[s-natscli-account-tls]]). See
[[rotate-tls-certificates]].

`nats server passwd` hashes a password with bcrypt at **cost 11** by default (`--cost` to raise it,
`--generate` to invent one) and **refuses anything under 10 characters** (source:
[[s-docs-authentication-basics]]).

**Topology and cross-domain JetStream**

```
nats server report routes
nats server report gateways
nats server report leafnodes
nats stream find --replicas=1
nats server check stream --stream=ORDERS --peer-expect=3
nats --js-domain hub stream ls
nats stream add --output orders-eu.json
nats stream add --config orders-eu.json --validate
```

The three `server report` commands need the system account and survey one layer each; the Leafnode
Report's `Account` column is an isolation audit and its `Spoke` column is a property of *where you
ran the command* (source: [[s-docs-putting-it-together]]). See [[leafnode]] and [[gateway]].

`nats server check stream --peer-expect` **exits non-zero** when a stream is under-replicated, and
`nats stream find --replicas=1` lists the streams that silently have no failover
(source: [[s-docs-jetstream-in-a-cluster]]) — [[replicas]].

**Interactive `nats stream add` builds cross-domain and cross-account sources for you.** Answer
"Import mirror from a different JetStream domain" and give the domain name; the CLI composes
`$JS.<domain>.API` itself and the delivery prefix is optional. The *different account* branch asks
for both prefixes and requires both, because those are **your local import subjects** — none of this
is in the docs (source: [[s-natscli-stream-external]]). See [[cross-domain-sourcing]].

```
# sharing between accounts: the flags 0.4.0 has (and --private / an activation command it does not)
nats auth account exports add Api "api.>" FABRIC --service --token-position 2
nats auth account imports add Api "api.>" TENANT --service --source <FABRIC-key> --local api.> --share
```

`--share` puts the requester's user into `Nats-Request-Info` on the exporter's side
([[service-import-request-info]]); a private export needs `nsc` ([[nsc]]) (source:
[[s-natscli-auth-exports-imports]]).


## The `$SYS` requests the CLI does not wrap

`nats server request` has subcommands for `variables`, `connections`, `subscriptions`, `routes`,
`gateways`, `leafnodes`, `accounts`, `jetstream`, `jetstream-health`, `ipqueue`, `raft`, `profile`
and `kick` (0.4.0) — and none for `STATSZ` or `IDZ`, which have no HTTP form either. The raw
request works with the system user, one reply per server (source:
[[s-nats-server-system-subjects-observed]] §2; the full table is [[system-subjects]]):

```
nats --server nats://sys:sys@host:4222 req '$SYS.REQ.SERVER.PING.IDZ'    '{}' --replies 3   # {"name","host","id"} per server
nats --server nats://sys:sys@host:4222 req '$SYS.REQ.SERVER.PING.STATSZ' '{}' --replies 3   # {"server", "statsz"} per server
nats --server nats://sys:sys@host:4222 req '$SYS.REQ.SERVER.<id>.RELOAD' ''                  # reload by message
```


## The flag for every stream and consumer field

`nats stream add` (47 stream flags) and `nats consumer add` (38) at 0.4.0 are captured verbatim in
`raw/nats-cli/help-0.4.0.md`; the flag beside each API field is on [[stream-and-consumer-config]].
Two CLI defaults differ from the server's: `--ack` defaults to `explicit` where the API's
`ack_policy` default is `none`, and `--max-pending=-1` / `--wait=-1s` mean "let the server decide"
(1000 and 30 s for an explicit consumer). `consumer edit` has flags for exactly the fields the server
lets an update change; `--config file.json` on either command sends a raw configuration for anything
the flags do not cover (source: [[s-nats-cli-help-0.4.0]]).


## Mirrors of buckets — what the CLI builds, and what it cannot read

Checked on CLI 0.4.0 against nats-server 2.14.6 (sources: [[s-nats-server-mirrors-observed]],
[[s-nats-go-kv-object-mirror]], [[s-issue-5106-object-store-mirror-list]]):

```
nats kv add DNS_M --mirror DNS --storage memory          # a KV mirror; same domain: nats kv ls DNS_M prints "No keys found in bucket"
nats kv add CFG_M --mirror CFG --mirror-domain leaf      # across a domain: readable by its own name at once
nats stream add KV_DNS_TR --config kv-mirror.json        # a KV mirror readable by name: add "$KV.DNS.>" -> "$KV.DNS_TR.>" yourself
nats stream add OBJ_dms_mirror --config obj-mirror.json  # an object bucket: no --mirror on `nats object add`; the transform is required
nats consumer add S C --pull --deliver subject …         # "last per subject" is spelled `subject`; `last-per-subject` is rejected
nats bench js consume --stream S --consumer C …          # binds an existing durable only (10014 consumer not found otherwise)
```

- `nats kv add` has `--mirror` and `--mirror-domain`; `nats object add` has neither, and `nats
  stream add` sets a mirror's `external` and transform only interactively or through `--config`.
- `nats kv ls` is a `last_per_subject`, `headers_only` push consumer filtered on `$KV.<bucket>.>`;
  on a **file mirror** with a hot key space that is the slow path — 1.533 s against 0.427 s on the
  origin for 400,000 keys ([[consumer-slow-on-a-sparse-stream]]).
- `nats object put` into a mirror bucket answers `nats: error: nats: no response from stream`;
  `nats stream purge` on a `KV_` stream asks for a confirmation the KV warning explains, and refuses
  without a terminal.


## The core-NATS commands, from `--help` on 0.4.0

Defaults and flags read from the binary (source: [[s-nats-cli-core-commands]]); the outputs from the
runs on 2.14.6 (source: [[s-nats-server-core-delivery-observed]]):

```
nats reply orders.inventory.check '{"in_stock":true}'           # joins queue group NATS-RPLY-22 by default (-q/--queue)
nats reply orders.inventory.check --echo                        # reflects the request, headers copied, NATS-Reply-Counter added
nats reply 'weather.>' --command "curl -s wttr.in/{{1}}?format=3"   # {{1}} = first token after the literal prefix; NATS_REQUEST_BODY in the env
nats request orders.inventory.check '{}' --replies 0 --timeout 2s --reply-timeout 300ms   # scatter-gather: every reply until the timeout
nats sub '>' --headers-only                                     # wire tap, metadata only; --subjects-only still prints one line per message
nats sub orders.created --count 3 --wait 10s                    # take exactly three, or give up after 10 s idle
nats pub orders.created '{…}' -H 'Content-Type:application/json' -H 'Acme-Request-Id:req_7f3c9a'
nats trace orders.us.created                                    # who would receive it, nothing delivered; needs nats-server 2.11+, no system user
nats trace orders.us.created --deliver                          # …and deliver it, with Nats-Trace-Dest and Accept-Encoding: snappy headers
nats server mappings "orders.created.*" "orders.created.{{partition(3, 1)}}.{{wildcard(1)}}" orders.created.ord_8w2k   # no server needed
nats sub orders.created --trace --connection-name warehouse     # >>> Connected / Disconnected due to: EOF / Setting reconnect delay / Reconnected lines
```

Two checks the CLI makes for you: a subject with whitespace fails at once with `nats: error: nats: invalid
subject` (the server would misroute it — [[subjects-and-wildcards]]), and a payload over the server's
`max_payload` fails with `nats: error: nats: maximum payload exceeded` (the server would close the
connection — [[core-nats-delivery]]). `nats server request subscriptions` needs a system-account user;
`nats server request connections` answers without one, for your own account only.


The chapter's own use of these commands — the `>` wire tap, `nats sub --count 3`, `nats pub -H`, `nats rtt
--connection-name`, the `nats server mappings` dry runs and the partition demo — is in
[[s-docs-core-nats-publish-subscribe]] and [[s-docs-core-nats-subjects-and-mapping]].


## `nats request` and `nats reply`, as run on 0.4.0

- **Three outcomes, one exit code.** A served request prints the reply; no responders prints `No
  responders are available` in ~37 ms; a timeout prints **nothing** after `Sending request on "…"` —
  and all three **exit 0** (runs B6–B8; `req_command.go:143–150`, `:205`). A script has to read the
  output.
- **A gather ends on any empty reply.** `--replies N` stops at the N-th reply *or* at the first reply
  with an empty body (`:179–181`); `--wait-for-empty` merely sets `--replies` to 32767 (`:222–224`).
  With `--replies 0` the wait is the remaining `--timeout` and `--reply-timeout` is not read; with
  `--replies N` each further wait is the average reply time so far plus `--reply-timeout` — three
  responders answered `--replies 3` in 41 ms, two responders held it 364 ms, `--replies 0` always the
  full 2 s (run D).
- **`nats reply` is one callback.** `--sleep` (random up to the value) and `--command` (run
  synchronously, `NATS_REQUEST_SUBJECT` and `NATS_REQUEST_BODY` in its environment, combined output
  as the body) hold every later request on that member; a `--command` with no output answers an
  empty body, which is how a sentinel responder is made. With no body, no command and no `--echo` the
  command switches to echo mode and says so.
- **The default group is `NATS-RPLY-22`.** Independent responders need distinct `--queue` names; a
  group of one behaves like a plain subscriber (run A).

Source: [[s-nats-cli-request-reply-source]] for the lines, [[s-nats-server-request-reply-observed]] for
the runs; the flags as the docs describe them — `--replies 0` as deadline mode, `--reply-timeout` as the
gap, `--wait-for-empty` as the sentinel, `nats sub --queue` — in [[s-docs-core-nats-request-reply]] and
[[s-docs-core-nats-queue-groups]]; the three stop conditions are ADR-47's ([[s-adr-47-request-many]]);
the mechanics on [[request-reply]] and [[queue-groups]].


## What bites you — the connection the CLI opens is not the library's

Read from `natscli` at **v0.4.0** (source: [[s-nats-cli-reconnect]]) and measured on nats-server
2.14.6 (source: [[s-nats-server-client-lifecycle-observed]]). The full comparison is in
[[client-defaults]].

- **The CLI reconnects forever and never aborts on a repeated auth error** — `MaxReconnects(-1)` and
  `IgnoreAuthErrorAbort()` (`cli/util.go:246–247`). An application on the library defaults would
  spend a 60-attempt budget per server and close, and would abort on the second identical auth
  error. **A failover watched with `nats sub` is therefore not a witness for what your service will
  do.**
- **`--trace` is not optional when watching a client.** Only two of the eight `>>>` lines print
  without it — the disconnect line and the closed line. `>>> Connected`, `>>> Reconnected`,
  `>>> Discovered new servers`, `>>> Reconnect error` and `>>> Setting reconnect delay to …` are all
  trace-gated (and the last is not in the documentation at all).
- **A client-side slow consumer under `nats sub` is silent.** `nats.ErrorHandler(...)` is registered
  twice (`:280` and `:288`), the second registration is trace-gated, and the later one wins — so
  `>>> Unexpected NATS error` never prints without `--trace`. The CLI has replaced nats.go's
  `defaultErrHandler`, which would have written it to stderr, with one that logs nothing.
- **`nats reply` exits before its own drain finishes.** Ctrl-C runs `Drain()` then
  `log.Fatalf("Exiting")` (`cli/reply_command.go:226–228`), and nats.go's `Drain()` returns as soon
  as the background drain starts. Measured with a one-second handler and eight requests in flight:
  **four answered, four abandoned**, and the process exited with code **1**. The documentation says
  as much — it "shows where the drain belongs rather than a finished drain".
- **A closed connection kills the process** one second later, through `log.Fatalf` in the
  `ClosedHandler` (`:277–279`).
- **The reconnect backoff is a 44-step table**, 500 ms to 20 s, saturating, each step jittered to
  half-to-one-and-a-half times its value. Because nats.go increments its sweep counter before calling
  the delay callback, the first wait actually used comes from the **750 ms** step — the table's
  500 ms entry is never reached (measured; docs issue #91).
- **`nats sub` on Ctrl-C just exits**, abandoning in-flight messages; only `nats reply` calls
  `Drain()` at all. The CLI has no drain-timeout flag.
- Useful when watching a failover: `nats sub … --trace`, `nats rtt` (five round trips per server),
  and `nats server check connection` with `--connect-warn 500ms --connect-critical 1s --rtt-warn
  500ms --rtt-critical 1s` and `--format nagios|json|prometheus|text`.


## Related

[[nsc]] · [[nk]] · [[nats-box]] · [[nats-top]] · [[jsm-go]] · [[monitoring-endpoints]] ·
[[defaults-and-limits]] · [[prometheus-nats-exporter]] · [[nats-server]] · [[operator-mode]] ·
[[set-up-operator-mode]] · [[rotate-tls-certificates]] · [[tls-in-nats]] · [[account]] ·
[[leafnode]] · [[gateway]] · [[cross-domain-sourcing]] · [[jetstream-domain]] · [[replicas]]

## Sources

[[s-docs-ecosystem]] · [[s-github-repo-facts]] · [[s-docs-getting-started]] ·
[[s-docs-prometheus-and-dashboards]] · [[s-natscli-account-tls]] ·
[[s-docs-authentication-basics]] · [[s-docs-operator-mode]] · [[s-docs-decentralized-auth]] ·
[[s-natscli-stream-external]] · [[s-docs-putting-it-together]] · [[s-docs-jetstream-in-a-cluster]] ·
[[s-natscli-backup-restore]] · [[s-docs-publishing]] ·
[[s-docs-altering-stream-state]] · [[s-docs-subject-mapping]] · [[s-docs-kv-ttl-and-limits]] ·
[[s-docs-kv-your-first-bucket]] · [[s-docs-accounts-and-multitenancy]] · [[s-docs-authorization]] ·
[[s-docs-config-and-jwt-backup]] · [[s-docs-forming-a-cluster]] · [[s-docs-kubernetes]] ·
[[s-docs-single-server]] · [[s-docs-stream-backup-restore]] · [[s-docs-your-first-cluster]] ·
[[s-gh-6605-which-consumer-is-slow]] · [[s-gh-7684-certificate-expiry]] ·
[[s-gh-7854-jwt-push-timeout]] · [[s-nats-server-snapshot-restore]] · [[s-nats-server-mirrors-observed]] · [[s-nats-go-kv-object-mirror]] · [[s-issue-5106-object-store-mirror-list]] · [[s-nats-server-system-subjects-observed]] · [[s-nats-cli-help-0.4.0]] · [[s-natscli-auth-exports-imports]] · [[s-nats-cli-core-commands]] · [[s-nats-server-core-delivery-observed]] · [[s-docs-core-nats-publish-subscribe]] · [[s-docs-core-nats-subjects-and-mapping]] · [[s-nats-cli-request-reply-source]] · [[s-nats-server-request-reply-observed]]
- [[s-docs-core-nats-request-reply]] · [[s-docs-core-nats-queue-groups]] · [[s-adr-47-request-many]] — the
  gather flags as the docs and ADR-47 describe them, for the `nats request` section. · [[s-nats-cli-reconnect]] · [[s-nats-server-client-lifecycle-observed]] · [[s-docs-resilient-clients-drain-and-shutdown]] · [[s-docs-resilient-clients-connecting]] · [[s-docs-resilient-clients-reconnection-and-events]]
