---
title: Leafnode
type: concept
area: [topology, security, jetstream]
verified-against: nats-server 2.14.6
verified-on: 2026-08-31
tags: [leafnode, hub, spoke, remotes, 7422, deny_exports, deny_imports, jetstream-domain, account]
aliases: [leaf node, leaf nodes, leafnodes, leaf, hub and spoke, spoke, "nats-leaf"]
sources: [s-docs-leaf-nodes, s-nats-server-topology, s-gh-5941-restrict-leafnode-subjects, s-gh-4823-leafnode-supercluster-duplicates, s-gh-6328-jetstream-behind-gateways, s-nats-server-leafnode-js-domains, s-docs-putting-it-together, s-gh-7438-multi-region-availability]
created: 2026-08-31
updated: 2026-08-31
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

## Related

[[gateway]] · [[choosing-a-topology]] · [[jetstream-domain]] · [[account]] ·
[[cross-account-sharing]] · [[multi-region-jetstream]] · [[cross-domain-sourcing]] ·
[[streams-not-visible-across-a-leafnode]] · [[duplicate-messages-across-a-leafnode]] ·
[[subject-permissions]] · [[build-a-3-node-cluster]]

## Sources

[[s-docs-leaf-nodes]] · [[s-docs-putting-it-together]] · [[s-nats-server-topology]] ·
[[s-nats-server-leafnode-js-domains]] · [[s-gh-5941-restrict-leafnode-subjects]] ·
[[s-gh-4823-leafnode-supercluster-duplicates]] · [[s-gh-6328-jetstream-behind-gateways]] ·
[[s-gh-7438-multi-region-availability]]

## To verify

- `leafnodes.reconnect` is documented as "interval in seconds"; `DEFAULT_LEAF_NODE_RECONNECT` is
  `1 * time.Second` (`const.go:162`). Whether an explicitly configured value is read as seconds or as
  a duration string has not been checked against the parser.
- **No `since:` on this page.** No source in `raw/` states which nats-server release introduced
  leafnodes, so the frontmatter leaves it out rather than guess. `leafnodes.min_version` must be at
  least `2.8.0` (`reference/config/leafnodes/min_version.md`), which is a floor on the *option*, not
  on the feature.
