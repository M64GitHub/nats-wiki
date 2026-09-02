# The lab — the scratch cluster behind the wiki's observed runs

Every file named `raw/nats-server-src/*-observed-v2.14.6.md` records what the `nats-server` binary
did when a page's claim was checked against it: election timings, `/jsz` fields, log lines, CLI
output. Most of those runs were made against one scratch cluster described in prose ("n1–n3,
cluster `east`, ports 4291–4293 …"). This directory is that cluster as a script, so a run can be
repeated by whoever clones the repo, and so a new run starts from the same shape rather than a
re-derived one.

```
bash tools/lab/cluster.sh up 3      # three nodes, JetStream on, healthy, meta leader printed
bash tools/lab/cluster.sh status    # one line per node
bash tools/lab/cluster.sh down      # stop them, keep the stores
```

Needs `nats-server` on `PATH` (or `NATS_SERVER=/path/to/binary`), `curl`, `python3` and bash 3.2 or
newer, which is what macOS ships. Nothing else. The `nats` CLI is not required by the script but is
what every recorded run uses; `cluster.sh url k` prints the URL to hand it.

## What it starts

| node | client | routes | monitoring | server_name |
|---|---|---|---|---|
| n1 | `127.0.0.1:4291` | `6291` | `http://127.0.0.1:8291` | `n1` |
| n2 | `127.0.0.1:4292` | `6292` | `http://127.0.0.1:8292` | `n2` |
| n3 | `127.0.0.1:4293` | `6293` | `http://127.0.0.1:8293` | `n3` |
| n4 | `127.0.0.1:4294` | `6294` | `http://127.0.0.1:8294` | `n4` |

Node `k` listens on `429k`, `629k`, `829k`. The cluster is named `east`; each node's config lists
every peer in `routes`. JetStream is enabled with `store_dir` under the scratch directory. The
system account has one user, **`sys` / `sys`**, so `nats server report jetstream`,
`nats server cluster step-down` and the `$SYS.REQ.SERVER.*` requests work:

```
nats --server nats://sys:sys@127.0.0.1:4291 server report jetstream
```

That is the whole configuration — `tools/lab/conf/node.conf.tmpl` is short enough to read. No
`meta_compact*`, no `domain`, no `extension_hint`, no TLS, no `max_payload`: the observed files were
run without them, and a run that adds something should say so in its header.

`up 1` renders `standalone.conf.tmpl` instead: the same server with no `cluster {}` block, the shape
n4 had before it joined in §10 of `jetstream-cluster-observed-v2.14.6.md`. `up 4` is the four-node
cluster the same file uses from §10 on. Any count 1–9 works; the wiki's runs used 1, 3 and 4.

## Commands

| command | what it does |
|---|---|
| `up [n]` | render the configs, start `n` nodes (default 3), wait until `/healthz` — and for a cluster `/healthz?js-meta-only=true` — answers 200 on every node, print the meta leader. Exits 1 if that takes longer than `NATS_LAB_WAIT` seconds (default 30). |
| `down [--purge]` | SIGTERM every node (immediate shutdown, not lame duck). Stores are kept unless `--purge`, which deletes the whole scratch directory. |
| `status` | per node: pid, alive, ports, `/healthz` and `/healthz?js-meta-only=true` status codes, `meta_cluster.leader` and `cluster_size` from `/jsz`. |
| `logs k [tail args]` | the log of node `k`, last 50 lines by default; `logs 1 -f` follows. |
| `conf k` | the rendered config of node `k`, with its path. |
| `stop k [-9]` | SIGTERM one node (SIGKILL with `-9`); its store and config stay. |
| `start k` | start one node again on its rendered config and existing store — a rejoin. |
| `url [k]` | prints `nats://sys:sys@127.0.0.1:429k`. |

Environment: `NATS_LAB_DIR` (scratch directory, default `${TMPDIR:-/tmp}/nats-lab`),
`NATS_LAB_VERSION` (default `v2.14.6`), `NATS_SERVER` (the binary), `NATS_LAB_FLAGS` (extra flags for
every node, e.g. `-DV` for the debug lines §10 of the meta-layer run quotes), `NATS_LAB_WAIT`.

## Where things live

```
${TMPDIR:-/tmp}/nats-lab/
  count            the node count of the last `up`
  n1/
    n1.conf        rendered from tools/lab/conf/*.tmpl
    n1.log         the server log (`-l`), with microsecond timestamps
    n1.pid         written by the server (`-P`)
    store/         jetstream { store_dir }: store/jetstream/$G/streams/…, store/jetstream/$SYS/_js_/_meta_/
  n2/ …
```

Never inside the repository. `down` keeps the stores on purpose: `down` followed by `up 3` is the
"restart all three with data" experiment (§2 of the meta-layer run), and `stop k -9` followed by
`start k` is a crash and rejoin (§7). `up` prints a note when it finds existing stores. `up` also
re-renders every config, so a config edited by hand (to join a standalone server to the cluster, say)
survives `start k` but not `up`.

## The version gate

`up` and `start` print `nats-server --version` and **refuse to run a binary that is not
`NATS_LAB_VERSION`** (default `v2.14.6`). Every `verified-against` in the wiki names one release,
and `CLAUDE.md` requires the binary a run is made on to be that release, so that "observed" means
observed on the version the page cites. To run another release deliberately, set the variable and
write the version in the run's header — the refusal is there to stop the accidental case, a Homebrew
upgrade that moved the binary ahead of the pages.

## The runs this reproduces

Files under `raw/nats-server-src/`, and what each was run against:

| file | shape |
|---|---|
| `jetstream-cluster-observed-v2.14.6.md` | **this cluster**: `up 3` for §1–§9, `up 4` (n4 standalone first, then joined) for §10–§13 |
| `kick-ldm-observed-v2.14.6.md` | **this cluster**, `up 3`; the victim is a `nats sub` on n1 |
| `mqtt-websocket-observed-v2.14.6.md` | §14 is this cluster's shape with an `mqtt { listen }` block added by hand and n1's `routes` list shortened to two entries; §1–§13 a single server on `4261` |
| `topology-observed-v2.14.6.md` | its own shapes: routes, gateway and leafnode blocks on `4222` / `4300` |
| `object-store-across-leafnode-observed-v2.14.6.md` | a hub on `4251` and a leaf on `4252`, each with a JetStream domain |
| `tls-reload-observed-v2.14.6.md` | a single server on `4322`; a hub `4400` / leaf `4401` pair for the leafnode TLS section |
| `defaults-observed-v2.14.6.md` | single servers and hub/leaf pairs on `4222`–`4227` |
| `filestore-observed-v2.14.6.md` | one server, `fslab`, on `4232` |
| `object-store-observed-v2.14.6.md` | one server, `objlab`, on `4241` |
| `compression-purge-discovery-observed-v2.14.6.md` | one server on `4223` |
| `priority-groups-observed-v2.14.6.md` | one server on `4290` |
| `nak-backoff-observed-v2.14.6.md` | one server, `nak-probe`, on `14222` |
| `message-schedules-observed-v2.14.6.md` | one JetStream server; the file records the stream and the CLI transcript, not the server config — `up 1` is the equivalent starting point |
| `monitoring-observed-v2.14.6.md` | one server on `4281` / `8281`, JetStream on file storage |

`up 1` gives the single-server files their starting point (a JetStream server with a `$SYS` user on
`4291`); their configs differ in port and name only, unless the file says otherwise.

## Recording a run

A run that settles a claim goes into `raw/nats-server-src/<topic>-observed-v2.14.6.md`, verbatim,
with the header line the existing files use (binary version from `nats-server --version`, CLI
version, date), the exact config or the `cluster.sh` command it started from, and the output —
store paths shortened to `<store>`, nothing else edited. Then a row in `raw/sources.md` under
`nats-server-src`, and the page cites the file. Behaviour that surprises goes to
`inbox/server-issues.md` as an observation with the reproduction; a doc page the run contradicts goes
to `inbox/docs-issues.md`. `CLAUDE.md` → *Operation: record a docs issue* says which is which.
