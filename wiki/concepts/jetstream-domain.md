---
title: JetStream domain
type: concept
area: [jetstream, topology, security]
verified-against: nats-server 2.14.6
verified-on: 2026-09-01
tags: [jetstream-domain, domain, default_js_domain, js-domain, mapping, external, api-prefix, leafnode]
aliases: [domain, js domain, js-domain, jetstream domains, "$JS.<domain>.API", default_js_domain]
sources: [s-nats-server-leafnode-js-domains, s-docs-leaf-nodes, s-gh-7438-multi-region-availability, s-gh-7881-cross-domain-sourcing, s-gh-7834-leafnode-same-js-domain, s-nats-server-object-store-leafnode, s-docs-mqtt-auth-and-clustering, s-natscli-stream-external, s-nats-server-jetstream-cluster, s-issue-5106-object-store-mirror-list]
created: 2026-08-31
updated: 2026-09-02
---

# JetStream domain

**A name that makes one JetStream system separately addressable from another across a leafnode
link.** Set `jetstream { domain: … }` and the server installs a subject mapping into every
non-system account, so clients elsewhere can reach *this* JetStream by prefix instead of colliding
with their own (source: [[s-nats-server-leafnode-js-domains]]).

A domain is the unit of JetStream independence. Two domains are two meta groups, two sets of streams,
two failure boundaries — which is why the multi-region shape a maintainer recommends is "leaf nodes,
each one with their own JS domain name" (source: [[s-gh-7438-multi-region-availability]]).

## How it behaves

**The domain is a subject mapping.** When `domain` is set and JetStream is on, the server adds
`generateJSMappingTable(domain)` to every non-system account (`leafnode.go:2114–2121`). The table
(`jetstream_api.go:326–352`):

```
$JS.<domain>.API.INFO       -> $JS.API.INFO
$JS.<domain>.API.STREAM.>   -> $JS.API.STREAM.>
$JS.<domain>.API.CONSUMER.> -> $JS.API.CONSUMER.>
$JS.<domain>.API.DIRECT.>   -> $JS.API.DIRECT.>
$JS.<domain>.API.META.>     -> $JS.API.META.>
$JS.<domain>.API.SERVER.>   -> $JS.API.SERVER.>
$JS.<domain>.API.ACCOUNT.>  -> $JS.API.ACCOUNT.>
$JS.<domain>.API.$KV.>      -> $KV.>
$JS.<domain>.API.$OBJ.>     -> $OBJ.>
```

Everything a domain does follows from that: there is no separate protocol, only a prefix that the
receiving server rewrites.

**The default domain is the one you are connected to.** "By default the domain name of the specific
server the client is connected to is used" — reaching another domain means naming it
(source: [[s-gh-7438-multi-region-availability]]).

**Core NATS is unaffected.** A domain scopes the **JetStream API**, not subjects in general.
Publishing to a subject that a remote region's stream captures still lands in that stream, because
the message crosses as ordinary interest-based traffic.

**Across a leafnode, the domain decides which of three things happens.** Combined with whether the
connection is the system account (source: [[s-nats-server-leafnode-js-domains]]):

| domains | account | outcome |
|---|---|---|
| **match** | system account | **extends** — one JetStream; the leaf's meta controller goes to observer mode and `meta.Reset()` discards its local metagroup state |
| **match** | any other | `denyAllClientJs` merged both ways — nothing crosses |
| **differ** | system account | `JetStream not extended, domains differ`; `denyAllJs` both ways |
| **differ** | any other | `denyAllClientJs` both ways — and each side is addressable by its own `$JS.<domain>.API.>` prefix |

The last row is the supported cross-domain path, not a workaround. Two **identical** domains without
a shared system account are actively guarded against: the server also denies publishing
`$JS.<domain>.API.>` outward over that link, with a source comment saying the guard "will only cover
some forms of this issue, not all of them" — see [[streams-not-visible-across-a-leafnode]].

**"Nothing crosses" is not literally true, and the exception is the [[object-store]].** The deny list
is `["$JS.API.>", "$KV.>", "$OBJ.>"]` (`jetstream_api.go:323`, v2.14.6), but an object bucket's
subjects are `$O.<bucket>.C.>` and `$O.<bucket>.M.>` — **`$OBJ.>` matches neither**. Measured on
2.14.6 across a hub/leaf pair with differing domains: `$KV.TEST.key1` and `$OBJ.TEST.thing` were both
denied, and `$O.TEST.C.abc` and `$O.TEST.M.abc` both crossed. With a same-named object bucket on each
side of the link, a put on one landed the object, chunks and metadata, in **both** streams; a KV
bucket in the same position did not (source: [[s-nats-server-object-store-leafnode]]). A domain is
therefore an isolation boundary for streams, consumers and KV — and not for object-store data.

## What configures it

```
jetstream {
  domain: "leaf01a"
  store_dir: "/var/lib/nats/js"
}
```

| key | what it does | default | reload |
|---|---|---|---|
| `jetstream.domain` | the JetStream domain this server belongs to | – | restart |
| `default_js_domain` | account-to-domain map: which domain a given account's clients get by default | – | restart |
| `mqtt.js_domain` | the domain MQTT sessions and messages use | – | restart |
| `leafnodes.remotes[].jetstream_cluster_migrate` (alias `js_cluster_migrate`) | – **the reference gives no description at all** | `true` | restart |

`default_js_domain` is documented in full as "Account to domain name mapping"
(`reference/config/default_js_domain.md`) — a `{ string: string }` with no example anywhere in the
docs tree.

On the client side the domain is a per-call option; the CLI spells it `--js-domain`:

```
nats --js-domain leaf01a stream ls
```

## What it does not do

- **A domain is not an account.** It scopes the JetStream API subject space; it does not isolate
  subjects, users or data. [[account]] does that.
- **A domain does not move data.** Getting messages from one domain into another is
  [[mirrors-and-sources]] with an `external` block — see [[cross-domain-sourcing]]. In that block the
  domain is not named as a domain: it is carried as the API prefix **`$JS.<domain>.API`**, which the
  `nats` CLI composes for you from the domain name alone
  (`mirror.External.ApiPrefix = fmt.Sprintf("$JS.%s.API", domainName)`), and which the server reads
  back the same way — `ExternalStream.Domain()` returns `tokenAt(ext.ApiPrefix, 2)`, the second token
  (`stream.go:432–437` at v2.14.6). **For a domain the delivery prefix is optional**, because the
  mapping above already routes it; for a *different account* both prefixes are required and both are
  **your local import subjects**, not the remote's (source: [[s-natscli-stream-external]]).
- **A domain is not a cluster.** A domain can be one server or a whole cluster; what it delimits is
  the JetStream meta group, not the route mesh.

## Mirroring a bucket across the boundary

A KV or object bucket crosses a domain the way a stream does — a mirror with `external.api =
$JS.<domain>.API` — and each kind has one extra rule: a KV mirror built with `nats kv add --mirror
--mirror-domain` is readable by its own name, an object-store mirror must be built by hand with the
transform `$O.<origin>.>` → `$O.<mirror>.>` or it lists as empty (source:
[[s-issue-5106-object-store-mirror-list]]; the recipe is on [[object-store]], the runbook is
[[cross-domain-sourcing]]).


## Observer mode, and what `extension_hint` does

A server that **solicits** a leafnode connection sharing the system account assumes it is extending
the hub's JetStream domain rather than forming its own: it starts its meta node as an **observer** —
it follows the hub's meta group and never campaigns (its election timer is set to 48 h) — and logs
how to turn that off. `jetstream { extension_hint: no_extend }` forces an independent meta group;
`extension_hint: will_extend` is the opposite override for a *standalone* server, which otherwise
refuses to extend. The choice is remembered in the meta group's `peers.idx` so a restart does not wait
for first contact again. The docs' reference page for `extension_hint` documents neither its purpose
nor these two values (docs issue #46). When extension does begin, `meta.Reset()` discards the leaf's
own meta state — leadership, every queued entry, the whole snapshots directory, the log, the peer set
and the term — which is why a domain must be decided before a leaf holds data
([[meta-layer]]; sources: [[s-nats-server-jetstream-cluster]], [[s-nats-server-leafnode-js-domains]]).


## Limits and failure modes

- **Setting a domain is a restart, and on an existing leaf it is destructive to metagroup state.**
  Where a connection previously extended the hub, `meta.Reset()` has already discarded the leaf's own
  metagroup state; changing the domain changes which branch runs. Treat a domain as fixed at design
  time.
- **The mapping is installed into every non-system account** — so `$JS.<domain>.API.>` is reachable
  from any account on that server, subject to that account's own permissions and to
  [[subject-permissions]].
- **Cross-account plus cross-domain needs exports and imports as well as the prefix.** Without them
  you get, verbatim from a public thread:
  `Error adding service import "$JS.leaf01a.API.CONSUMER.CREATE.tank": service import not authorized`
  (source: [[s-gh-7881-cross-domain-sourcing]]).
- The docs tree contains **no worked example** of cross-domain sourcing, and `external`, `api` and
  `deliver` appear nowhere in its 861 pages (`inbox/docs-issues.md` #21).

## What you can observe

`JetStream using domains: local %q, remote %q` at INFO on every leafnode connection that is **not**
extending (`leafnode.go:2084`). `local ""` means this server has no domain set. If you expected one
JetStream and see this line, you have two.

## Related

[[leafnode]] · [[cross-domain-sourcing]] · [[multi-region-jetstream]] · [[mirrors-and-sources]] ·
[[account]] · [[js-api-subjects]] · [[streams-not-visible-across-a-leafnode]] ·
[[choosing-a-topology]] · [[key-value]]

## `mqtt { js_domain }` — the one other place a domain is selected

[[mqtt]] stores sessions, retained messages and in-flight QoS 1/2 deliveries in JetStream, and
`js_domain` in the `mqtt {}` block chooses **which domain** that state goes to. On a leaf close to the
devices, pointing it at the leaf's own domain keeps sessions and retained messages local, so devices
keep working when the link to the hub is down (source: [[s-docs-mqtt-auth-and-clustering]]).

```
mqtt {
  listen: 127.0.0.1:1883
  js_domain: "factory"
}
```

Two consequences worth carrying. **The domain is part of the session's storage identity**, which is
what keeps sessions in different domains from colliding — the same client id can hold a session in two
domains without either evicting the other. And **a leaf serving MQTT need not run JetStream itself**:
the standalone `mqtt requires JetStream to be enabled` check does not apply once a `leafnodes` block
exists, because the leaf can reach JetStream through the hub.

## Sources

[[s-nats-server-leafnode-js-domains]] · [[s-docs-leaf-nodes]] ·
[[s-gh-7438-multi-region-availability]] · [[s-gh-7881-cross-domain-sourcing]] ·
[[s-gh-7834-leafnode-same-js-domain]] · [[s-nats-server-object-store-leafnode]] ·
[[s-docs-mqtt-auth-and-clustering]] ·
[[s-natscli-stream-external]] · [[s-nats-server-jetstream-cluster]] · [[s-issue-5106-object-store-mirror-list]]

## To verify

- `default_js_domain` is documented in four words and has no example in `raw/`. Its precedence
  against a client's explicit domain, and its behaviour for an account not listed in the map, are
  **unverified**.
- `leafnodes.remotes[].jetstream_cluster_migrate` defaults to `true` and the generated reference
  gives it **no description**. What it migrates, and when, is unverified — recorded as
  `inbox/docs-issues.md` #26.
- Whether a domain may be changed on a running deployment without losing stream state has not been
  established from any source.
