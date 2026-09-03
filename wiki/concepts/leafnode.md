---
title: Leafnode
type: concept
area: [topology, security, jetstream]
verified-against: nats-server 2.14.6
verified-on: 2026-08-31
tags: [leafnode, hub, spoke, remotes, 7422, deny_exports, deny_imports, jetstream-domain, account]
aliases: [leaf node, leaf nodes, leafnodes, leaf, hub and spoke, spoke, "nats-leaf"]
sources: [s-docs-leaf-nodes, s-nats-server-topology, s-gh-5941-restrict-leafnode-subjects, s-gh-4823-leafnode-supercluster-duplicates, s-gh-6328-jetstream-behind-gateways, s-nats-server-leafnode-js-domains, s-docs-putting-it-together, s-gh-7438-multi-region-availability, s-nats-server-tls-reload, s-nats-server-object-store-leafnode, s-docs-websocket-leaf-nodes-over-websocket, s-gh-7505-auth-callout-nkey, s-gh-7881-cross-domain-sourcing, s-relnotes-2.10, s-relnotes-2.11, s-relnotes-2.12]
created: 2026-08-31
updated: 2026-09-03
---

# Leafnode

**A NATS server that dials *out* to another NATS system and bridges subject interest across the one
connection** (source: [[s-docs-leaf-nodes]]). The direction is the whole point: the hub never dials
the leaf, so a leaf runs anywhere with egress — behind a firewall, on a factory network, on a laptop.

It is also the only layer in NATS that can draw a boundary. Routes and gateways widen where a message
can go; a leaf bound to its own [[account]] narrows it (source: [[s-docs-putting-it-together]]).

## How it behaves

**One connection, however many clients.** A client of the leaf "never appears on the hub as a
connection. The hub sees one thing: the leaf link." Add a thousand machines behind the leaf and the
hub still sees one. That is the scaling property — and the reason the hub cannot authenticate or
count those clients.

**The bridge is by interest, in both directions.** A hub subscriber's interest flows down the link
and the leaf forwards matching messages up; a leaf subscriber's interest flows up and hub traffic
comes down. Only subjects with interest on the far side cross.

**Isolation is an account decision, not a leaf one.** In the default account there is no subject
boundary at all: "interest flows across the leaf the way it flows across a cluster's routes". Bind
both ends to a named account and only that account's imports and exports cross — the property the
docs call **address-space isolation**.

**Leaves compose into trees.** A leaf can hold several `remotes`, each dialing a different system,
and can itself run a `leafnodes { listen }` block to become a hub for leaves further out.

**A leaf remote's `urls` list is a reconnect pool for *one* system.** Every URL is an alternative way
to reach the same NATS system. Listing servers from two clusters of the same supercluster creates two
bridges into one system and the traffic loops — see
[[duplicate-messages-across-a-leafnode]] (source: [[s-gh-4823-leafnode-supercluster-duplicates]]).

**JetStream over the link is a separate question**, governed by the [[jetstream-domain]] and by
whether the connection shares the system account. Matching domains plus a shared system account
*extends* the hub's JetStream onto the leaf; anything else denies the JetStream API across the link
(source: [[s-nats-server-leafnode-js-domains]]). See
[[streams-not-visible-across-a-leafnode]].

## What configures it

Which block you write tells you which end you are. There is no symmetric form.

### The hub — accept connections

```
leafnodes {
  listen: 0.0.0.0:7422
  authorization {
    users = [
      { user: "factory-1", password: "…", account: "FACTORY" }
    ]
  }
}
```

### The leaf — dial out

```
leafnodes {
  remotes: [
    {
      urls: [ "nats-leaf://hub-1:7422", "nats-leaf://hub-2:7422", "nats-leaf://hub-3:7422" ]
      account: "FACTORY"
      credentials: "/etc/nats/factory.creds"
    }
  ]
}
```

| key | what it does | default | reload |
|---|---|---|---|
| `leafnodes.listen` / `port` | accept inbound leaf connections | **none** — see below | restart |
| `leafnodes.host` | interface to listen on | `0.0.0.0` (only once a port is set) | restart |
| `leafnodes.write_deadline` | how long a leaf write may block before the connection is stalled | `10s` | restart |
| `leafnodes.min_version` | minimum server version of a connecting leaf; must be ≥ `2.8.0` | – | restart |
| `leafnodes.isolate_leafnode_interest` | do not propagate interest learned from one leaf to the others on this server | `false`, since **2.12** | restart |
| `leafnodes.remotes[].urls` / `url` | where to dial; scheme `nats-leaf` or `ws` | – | reload |
| `leafnodes.remotes[].account` (alias `local`) | the **local** account whose traffic this remote carries | – | reload |
| `leafnodes.remotes[].credentials` (alias `creds`) | `.creds` file proving the leaf's identity to the hub | – | reload |
| `leafnodes.remotes[].nkey` | an NKey **seed** proving the leaf's identity instead of a creds file — the form a device fleet uses, one seed per leaf (source: [[s-gh-7505-auth-callout-nkey]]) | – | reload |
| `leafnodes.remotes[].deny_exports` | subjects this leaf will **not publish** to the hub | – | restart\* |
| `leafnodes.remotes[].deny_imports` | subjects this leaf will **not subscribe** for on the hub | – | restart\* |
| `leafnodes.remotes[].no_randomize` | try `urls` in order instead of shuffled | `false` | restart |
| `leafnodes.remotes[].ignore_discovered_servers` | use only the configured URLs, not the ones the hub advertises | `false` | restart |
| `leafnodes.remotes[].first_info_timeout` | how long to wait for the remote's `INFO` | `1s` | restart |
| `leafnodes.remotes[].disabled` | keep the remote configured without connecting | `false` | reload |
| `leafnodes.reconnect` | reconnect attempt interval, seconds | `1s` (`DEFAULT_LEAF_NODE_RECONNECT`) | restart |
| `jetstream.domain` | the JetStream domain this server belongs to — see [[jetstream-domain]] | – | restart |

\* The generated reference notes that on 2.11/2.12 "the reload returns success; the new
deny\_exports take effect only after a restart" (source: `reference/config/leafnodes/remotes/deny_exports.md`).

### Rotating a remote's certificate

The same reference carries a stronger version of that caveat on six keys under
`leafnodes { remotes[].tls { … } }` — *"On 2.11/2.12 the reload succeeds but the old certificate keeps
being used"* (`cert_file`), and *"…but nothing changes"* on `ca_file`, `key_file`, `cipher_suites`,
`curve_preferences` and `insecure`. None of the six says whether it still holds on the current
release, and taken at face value it means a leaf's certificate can only be rotated by restarting the
leaf.

**On 2.14.6 it does not hold for the three that matter.** Tested against a hub that accepts exactly
one certificate identity, so the hub reports which certificate the leaf presented: replacing
`cert_file` and `key_file` **in place**, and repointing them at new **paths** in the config, both make
the leaf present the new certificate; repointing `ca_file` at a CA that did not sign the hub makes
the leaf reject the hub with `x509: certificate signed by unknown authority`. Both controls — a hub
restart with no reload, and a reload with no change — leave the leaf connected
(source: [[s-nats-server-tls-reload]]). `cipher_suites`, `curve_preferences` and `insecure` were not
tested.

**The catch is the one long-lived connection.** A leaf holds a single connection to its hub, and it
keeps the certificate it handshook with; immediately after the reload the hub still saw the *old*
identity. The rotation only reaches the hub when that connection re-establishes. See
[[rotate-tls-certificates]].

The full 621-key table is `inbox/config-keys-table.md`; the operator-facing subset is [[config-keys]].

**`leafnodes { }` with no port opens no listener.** The reference documents `port` with a default of
`7422`; the server has none. `DEFAULT_LEAFNODE_PORT = 7422` (`const.go:206`) is used in exactly one
place — filling in a missing port on a *remote's* URL (`opts.go:6096`) — never to open a listener.
An empty block starts a server that silently accepts no leaves
(source: [[s-nats-server-topology]]; `inbox/docs-issues.md` #23).

**A server with both a leafnode listener and a gateway must set `system_account`**, or it refuses to
start:

```
nats-server: leaf nodes and gateways (both being defined) require a system account to also be configured
```

`nats-server -t` reports the same file valid (source: [[s-nats-server-topology]];
`inbox/docs-issues.md` #24).

### Compression is on by default

A leafnode connection compresses unless you say otherwise: `setBaselineOptions` gives both the
listener and **every remote** the mode `s2_auto` (`opts.go:6082–6089` and `6099–6106`, v2.14.6),
which picks an S2 level from the measured RTT and sends uncompressed while the link is fast. The
generated config reference states the default is `accept` — it is not; `accept` is the **cluster**
default. Recorded as `inbox/docs-issues.md` #27.

You can see it on a link that has nothing configured:

```
$ curl -s http://127.0.0.1:8222/leafz | grep compression
      "compression": "s2_uncompressed"
```

The same pair with `compression: accept` written on both ends reports `"compression": "off"` — so
the difference is real, not cosmetic. On a fast LAN link this costs CPU for nothing; on a WAN link
it is usually what you want. Set it explicitly either way:

```
leafnodes {
  port: 7422
  compression: off          # or s2_fast / s2_better / s2_best / accept
}
```

`on` is a synonym for `s2_auto`, and `s2_auto`'s ladder is governed by
`rtt_thresholds` (`[10ms 50ms 100ms]` per the reference) (source:
[[s-nats-server-defaults-sweep]]).

## Restricting what crosses

This is the question people actually ask (Q48), and the obvious answer is a trap.

**`deny_exports` is a publish deny; `deny_imports` is a subscribe deny** (`leafnode.go:473–481`).
Both are deny-only — there is no `allow` counterpart — so "deny everything, then allow one subject"
is **not expressible** with these keys.

**A leafnode user cannot carry permissions in config mode.** `parseLeafUsers` is "a trimmed down
version of parseUsers" and accepts exactly `user`, `pass`, `account` and `proxy_required`
(`opts.go:3005–3064`). `permissions` inside `leafnodes.authorization` is a parse error. And a
same-named user in the *global* `authorization.users` block governs client connections, not this one:
its denies are simply not applied — reproduced on v2.14.6
(source: [[s-nats-server-topology]], [[s-gh-5941-restrict-leafnode-subjects]]).

So:

- **Config mode** — the boundary is the **account**. Bind the remote with `account`, bind the hub-side
  user with `account`, and let [[cross-account-sharing]] decide what crosses. `deny_imports` /
  `deny_exports` trim on top of that.
- **Operator mode** — put the permissions in the leaf user's JWT. They reach the connection, are
  reversed on the hub because data flows the other way (`leafnode.go:2307–2318`), and are pushed back
  to the leaf for local enforcement (`leafnode.go:2423–2424`). This is what the maintainer answer in
  [[s-gh-5941-restrict-leafnode-subjects]] describes.
- The two ends **compose**: the hub's permissions arrive in the INFO and the remote's local denies are
  merged on top (`leafnode.go:1715–1735`).

**If the hub mints those permissions with auth callout, verify the NKey yourself.** The pattern is a
natural one — each leaf holds a unique seed, dials with `nkey:`, and the hub's callout service "looks
up a device id corresponding to the incoming public key in a database and returns JWT claims giving
the leafnode permission to publish on e.g. `devices.${id}.foo`". The trap is that **the server
verifies nothing the client presented**: every field of `connect_opts`, `nkey` included, is copied
straight from the connection. Treating it as an identity is a spoofing bug, and a quiet one — the
connection succeeds and the wrong device gets the wrong permissions. The challenge-response is still
available, but the *service* has to do it: when the client supplied a signature the server puts the
nonce it issued into `client_info.nonce`, so the service can verify `connect_opts.signed_nonce` over
that nonce against `connect_opts.nkey` (source: [[s-gh-7505-auth-callout-nkey]]). Both maintainer
replies on the thread point at a hardened callout library rather than a hand-rolled handler. See
[[auth-callout]].

## Dialling the hub over WebSocket

A leaf can reach its hub through the `websocket {}` listener instead of the leafnode port, which is
the answer when an HTTPS ingress is the only published way into the network. Nothing about the leaf
model changes — same account, same interest propagation, same behaviour when the link drops — only the
transport (source: [[s-docs-websocket-leaf-nodes-over-websocket]]).

The hub needs **both** blocks, and one of them is never dialled:

- `leafnodes { port: 7422 }` is "the switch that makes this server willing to accept leaf nodes **at
  all**". Drop it, or write it empty, and the branch's connection is accepted by the WebSocket
  listener and then closed.
- `websocket {}` is the door the branch arrives through.

So **7422 stays open and unused** — a real listener reachable by whatever can get to it, and a
firewall item easy to miss precisely because nothing connects to it.

The branch side is one URL:

```
leafnodes { remotes [ { urls: ["wss://nats.example.com:443"] } ] }
```

Four things that bite:

- **Clients and leaves are told apart by the request path** — a leaf asks for `/leafnode`, a client
  for `/`. You never write it; the server appends `/leafnode` to whatever path the remote URL carries,
  which a path-routing proxy must account for ([[run-nats-behind-a-proxy]]).
- **Write the port.** A leafnode URL without one gets `:7422` appended *whatever the scheme*, so
  `wss://host` quietly dials the leafnode port and then fails, because it does not speak WebSocket.
- **One scheme per remote**, enforced at startup (confirmed on 2.14.6, exit 1):
  `remote leaf node configuration cannot have a mix of websocket and non-websocket urls`. You cannot
  offer the ingress and a direct leafnode port as alternatives to each other.
- **The connection type is `LEAFNODE_WS`, not `LEAFNODE`.** Granting `LEAFNODE` refuses the branch —
  the transport is part of what the value names ([[subject-permissions]]).

Two WebSocket-only remote settings exist: `ws_compression` and `ws_no_masking` (aliases
`websocket_compression`, `websocket_no_masking`). Masking exists to stop a browser poisoning
intermediary caches, which does not apply to a server-to-server link; both are requests the hub may
decline, and the link works either way. See [[websocket]].

## Limits and failure modes

- **A `urls` list spanning two clusters of one supercluster loops.** One bridge per NATS system;
  reach a supercluster through DNS (a CNAME per cluster, a geo-aware record over the whole thing) —
  [[duplicate-messages-across-a-leafnode]].
- **Reversing the ends produces nothing at all.** `listen` on the egress-only side, expecting the hub
  to dial in, connects nothing and logs nothing useful.
- **A leaf in the default account is not isolated.** The `Account` column of
  `nats server report leafnodes` reading `$G` is the audit that catches this.
- **Enabling JetStream on a leaf that shares the hub's system account with a matching domain extends
  the hub's JetStream**, so a stream created on the leaf may land on the hub —
  [[streams-not-visible-across-a-leafnode]].
- **The JetStream deny list does not cover the [[object-store]].** When domains differ, the server
  merges `["$JS.API.>", "$KV.>", "$OBJ.>"]` both ways — but an object bucket's subjects are
  `$O.<bucket>.C.>` and `$O.<bucket>.M.>`, which `$OBJ.>` does not match. Measured on 2.14.6: `$O.…`
  publishes crossed the link while `$KV.…` did not, and a same-named object bucket on both sides ended
  up holding the same object, chunks and metadata (source:
  [[s-nats-server-object-store-leafnode]]). Until that changes, the mitigation on this page's own
  terms is a `deny_exports` / `deny_imports` entry for `$O.>` on the remote — one of the few cases
  where the deny-only keys are exactly the right tool, because there is nothing to allow.
- **Cross-domain JetStream over a leaf fails as a missing *export*, and the error names the subject.**
  Sourcing a stream from the hub's JetStream domain needs the hub account to export `$JS.API.>` and
  the leaf account to import it under a prefix; without the matching export the leaf logs

  ```
  Error adding service import "$JS.leaf01a.API.CONSUMER.CREATE.tank": service import not authorized
  ```

  Read the subject to learn which of the three prefixes is missing. **`CONSUMER.CREATE` is
  request/reply, so the export must be a `service` export, not a stream export** — getting that type
  wrong is one of the two silent failures on [[mirrors-and-sources]]. Config-file (non-JWT)
  cross-domain sourcing with TLS has **no public worked example**
  (source: [[s-gh-7881-cross-domain-sourcing]]); [[cross-domain-sourcing]] writes it from the server
  source and says which steps are unverified.
- **No public source describes converting a leaf region into a non-leaf cluster**, or what happens if
  a leaf outgrows its hub. Both were asked in [[s-gh-7438-multi-region-availability]] and neither was
  answered. Treat the choice of hub as hard to reverse.

## What you can observe

```
nats server report leafnodes
```

```
╭──────────────────────────────────────────────────────────────────╮
│                         Leafnode Report                            │
├─────────┬───────────┬─────────┬──────────────────┬──────┬─────────┤
│ Server  │ Name      │ Account │ Address          │ RTT  │ Spoke   │
├─────────┼───────────┼─────────┼──────────────────┼──────┼─────────┤
│ n1-east │ factory-1 │ $G      │ 203.0.113.7:...  │ 18ms │ false   │
╰─────────┴───────────┴─────────┴──────────────────┴──────┴─────────╯
```

Needs the system account. `Spoke` is a property of **where you ran the command**, not of the link:
`false` on the hub that accepted it, `true` on the leaf that dialed
(source: [[s-docs-putting-it-together]]). `/leafz` is the HTTP equivalent — see
[[monitoring-endpoints]].

## Version notes: the 2.10 line

- **Compression is since 2.10.0**, "where the default now is `s2_auto` to compress relative to the
  RTT of the hub" (#4167, #4230); the S2 writer concurrency was set to 1 in 2.10.2 (#4570) (source:
  [[s-relnotes-2.10]]).
- `handshake_first` on a remote — 2.10.0 (#4119); remotes from the same server may bind the same hub
  account — 2.10.0 (#4259); reconnect jitter — 2.10.0 (#4398); `first_info_timeout` — **2.10.26**
  (#5424, "connection may fail on slow link"); leafnode authorization accepts nkeys — 2.10.8 (#4940).
- Behaviour: 2.10.12 fixes loop detection on daisy-chained leafnodes (#5126); **2.10.19 rejects a
  leafnode whose cluster name contains spaces** (#5732); 2.10.22 and 2.10.23 load-balance queue groups
  over leafnode connections (#5982, #6043); 2.10.25 fixes interest propagation when the hub user has
  subscribe permission on a literal subject (#6291) and queue interest dropped over gateways after a
  leafnode drop (#6377); 2.10.26 authenticates leafnode credentials through auth callout (#6492).
  The duplicate-delivery fixes are on [[duplicate-messages-across-a-leafnode]].


### The 2.11 line

- **2.11.0**: `handshake_first` on the leafnode listener accepts a duration (#5783) — the fallback
  form; see [[tls-in-nats]] and `inbox/docs-issues.md` #55 (source: [[s-relnotes-2.11]]).
- **2.11.5**: leafnodes with restrictive permissions route replies correctly when the request came
  from a supercluster (#6931); sourcing resyncs faster after a connection failure (#6981).
  **2.11.9**: subject interest propagated when daisy-chaining imports and exports (#7255) and no
  longer lost on a spoke (#7259); mirroring and sourcing speed up after a reconnect (#7265).
- **Security, 2026**: **CVE-2026-29785** — "systems with leafnode compression enabled" (2.11.14: a
  subscription received before compression was negotiated could panic the server);
  **CVE-2026-33246** (leafnodes and service imports) and **CVE-2026-33218** (2.11.15: a loop-detection
  error before `CONNECT`, request-info headers for non-shared imports, and a back-off "on receiving a
  minimum version required error, no longer requiring blocking the readloop", #7970); **2.11.16**:
  pre-`CONNECT` guards, ACLs "correctly enforced for inbound leaf messages in all cases", duplicate
  `INFO` permission updates accepted only on solicited connections, **`max_payload` enforced on
  leafnode connections**; **2.11.17**: a panic negotiating compression fixed.


### The 2.12 line

- **2.12.0**: **`leafnodes { isolate_leafnode_interest }`** — "suppressing east-west traffic and
  reducing subscription overheads when there are many leafnodes" (#7238, #7243, #7277); `disabled` on
  a remote, reloadable (#7054); **a leafnode without auth no longer lands in the global account**
  (#7116) (source: [[s-relnotes-2.12]]).
- **2.12.1**: `leafnodes { write_deadline }` (#7405); WebSocket leafnodes through an HTTP proxy
  (`remotes [ { proxy { url, username, password, timeout } } ]`, #7242) — plain leafnodes through
  HTTP CONNECT from 2.12.6 (#7781). **2.12.2**: a regression parsing token authentication in
  leafnode URLs fixed (#7452); proxy validation (#7444). **2.12.5**: a crash when a leafnode with
  bad credentials went through auth callout (#7844). **2.12.7**: a panic on connect when an account
  fails to resolve (#7991). **2.12.8**: solicited leafnodes send the connect advisory they lacked
  (#8015). **2.12.9**: no compression negotiation over already-compressed WebSockets (#7969); lock
  contention between leafnodes and clients (#8139, #8159).


## Related

[[gateway]] · [[choosing-a-topology]] · [[jetstream-domain]] · [[account]] ·
[[cross-account-sharing]] · [[multi-region-jetstream]] · [[cross-domain-sourcing]] ·
[[streams-not-visible-across-a-leafnode]] · [[duplicate-messages-across-a-leafnode]] ·
[[subject-permissions]] · [[build-a-3-node-cluster]]

## Sources

[[s-docs-leaf-nodes]] · [[s-docs-putting-it-together]] · [[s-nats-server-topology]] ·
[[s-nats-server-leafnode-js-domains]] · [[s-gh-5941-restrict-leafnode-subjects]] ·
[[s-gh-4823-leafnode-supercluster-duplicates]] · [[s-gh-6328-jetstream-behind-gateways]] ·
[[s-gh-7438-multi-region-availability]] · [[s-nats-server-tls-reload]] ·
[[s-nats-server-object-store-leafnode]] ·
[[s-docs-websocket-leaf-nodes-over-websocket]] ·
[[s-gh-7505-auth-callout-nkey]] · [[s-gh-7881-cross-domain-sourcing]] · [[s-relnotes-2.10]] · [[s-relnotes-2.11]] · [[s-relnotes-2.12]]

## To verify

- `leafnodes.reconnect` is documented as "interval in seconds"; `DEFAULT_LEAF_NODE_RECONNECT` is
  `1 * time.Second` (`const.go:162`). Whether an explicitly configured value is read as seconds or as
  a duration string has not been checked against the parser.
- The three leafnode-remote TLS keys **not** tested for reload — `cipher_suites`,
  `curve_preferences` and `insecure` — which the generated reference says reload without effect on
  2.11/2.12.
- **No `since:` on this page.** No source in `raw/` states which nats-server release introduced
  leafnodes, so the frontmatter leaves it out rather than guess. `leafnodes.min_version` must be at
  least `2.8.0` (`reference/config/leafnodes/min_version.md`), which is a floor on the *option*, not
  on the feature.
