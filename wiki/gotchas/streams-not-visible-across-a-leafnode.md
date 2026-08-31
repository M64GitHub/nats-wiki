---
title: "streams are not visible across a leafnode"
type: gotcha
area: [topology, jetstream, security]
verified-against: nats-server 2.14.6
verified-on: 2026-08-31
tags: [leafnode, jetstream-domain, system-account, extending-jetstream, verify_and_map, mapping]
aliases: ["JetStream using domains", "JetStream not extended domains differ", "leafnode streams not visible", "extending JetStream", "js-domain"]
sources: [s-gh-7834-leafnode-same-js-domain, s-nats-server-leafnode-js-domains, s-gh-5859-unexpected-nats-timeout, s-docs-accounts-and-multitenancy]
created: 2026-08-31
updated: 2026-08-31
---

# Streams are not visible across a leafnode

The leafnode connects, the log looks healthy, and a stream created on one side does not exist on the
other. Then someone gives the two sides **different** JetStream domains and it starts working, which
feels backwards.

## Symptom

Four observations, from the thread this page is built on
(source: [[s-gh-7834-leafnode-same-js-domain]]):

> "a) If I create a jetstream stream on the cluster, it doesn't show up on the leafnode.
> b) If I create a jetstream stream on the leafnode, it doesn't show up on the cluster.
> c) If I do a 'server report jetstream' on the leafnode, it only lists the leafnode.
> d) If I do a 'server report jetstream' on the cluster, it only lists the cluster nodes.
> e) If I change the jetstream domain to be e.g. "nlx000013" on the cluster nodes and "notnlx000013"
> on the leafnode … it shows up in both places. That is really weird."

In the log, on the leafnode connection:

```
- lid:3 - JetStream using domains: local "", remote "myjsdomain"
```

or, when the system account is the one connecting:

```
- lid:3 - System account connected from ...
- lid:3 - JetStream not extended, domains differ
```

## The rule

Sharing one JetStream across a leafnode ("extending") needs **two** things at once, and the server's
own comment states them together (`leafnode.go:2034–2035`):

> "Deny (non domain) JetStream API traffic unless system account is shared and domain names are
> identical and extending is not disabled"

So:

| the leafnode connects as… | domains | what happens |
|---|---|---|
| the **system account** | identical | **extends** — one JetStream. Log: `Extending JetStream domain "x" as System Account connected from server …` |
| the **system account** | different | denied (`$JSC.>`, `$NRG.>`, `$JS.API.>`, `$KV.>`, `$OBJ.>`). Log: `JetStream not extended, domains differ` |
| **any other account** | identical | denied (`$JS.API.>`, `$KV.>`, `$OBJ.>`) — matching domains alone extend nothing |
| **any other account** | different | denied, plus the cross-domain mapping. Log: `JetStream using domains: local "…", remote "…"` |

(source: [[s-nats-server-leafnode-js-domains]], `leafnode.go:2063–2110`, v2.14.6)

**The third row is the one people land on.** Setting the same `domain` on both ends looks like the
way to join two JetStreams. It is not; without the system account on that connection, it is just two
JetStreams that now collide on one subject prefix.

## Why different domains made it work

When `domain` is set and JetStream is on, the server installs a mapping table into **every
non-system account** (`leafnode.go:2114–2121`):

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

With **distinct** domains each side owns a distinct prefix, so a client can address the other side
explicitly — `nats --js-domain <name> stream ls`. That is the supported cross-domain path, and it is
what observation (e) was seeing. It is *not* one merged JetStream: the two remain separate, and each
stream still lives on exactly one side.

With **identical** domains the prefix is ambiguous, and the server adds a deliberate guard — it denies
publishing `$JS.<domain>.API.>` **outward** over that leafnode, with this comment
(`leafnode.go:2124–2129`):

> "This is a guard against a miss-config with two identical domain names and will only cover some
> forms of this issue, not all of them. This guards against a hub and a spoke having the same domain
> name. But not two spokes having the same one and the request coming from the hub."

So the configuration is not merely unsupported: the server recognises it and stops the traffic, and
says openly that the guard is incomplete.

## Quick triage

```
nats server list                                   # is the leafnode even in the same JetStream?
nats --js-domain <hub-domain> stream ls            # can you reach the other side explicitly?
grep -E 'JetStream (using domains|not extended)|Extending JetStream' <log>
```

Then check the leafnode `remotes` block for which **account** it connects as. That single field
decides three of the four rows in the table.

## Causes, ranked

### 1. The leafnode remote is not connecting as the system account

The usual cause, and the one in the thread: the remote specified `account: SENTINEL`, an ordinary
application account. Extension was never possible, so observations (a)–(d) are the expected result.

**How to confirm.** Look for `Extending JetStream domain … as System Account connected from server …`
in the hub's log. If it is absent, you are not extending.

**The fix.** Point the leafnode remote at the **system account** on both ends, or accept two
JetStreams and use domains to address across.

### 2. Both sides carry the same `domain`, without a shared system account

Row three above. This is the configuration that produces the guard.

**The fix.** Pick one: either share the system account **and** keep the domains identical (one
JetStream), or give the two sides **different** domains (two JetStreams, addressable across). Never
identical domains without the system account.

### 3. `verify_and_map` makes the system-account user look impossible

The thread's other complaint:

> "it seems impossible to be able to specify a password for a user on the system_account when using
> TLS."

With `verify_and_map: true` the **certificate is the identity**, so a system-account user has no
password for the remote to present. That is the design, not a limitation: the leafnode remote
authenticates with its client certificate and is mapped to a user in the system account. See
[[tls-in-nats]] for the mapping order and [[account]] for what `$SYS` is.

### 4. The connection is fine and the *client* is asking the wrong side

`nats stream ls` on the leafnode asks the leafnode's JetStream. With two domains that is correct
behaviour, not a fault — add `--js-domain`.

## What the extension actually does to the leafnode

Worth knowing before choosing it: when a leafnode extends a hub's JetStream, the leaf's meta
controller is put into **observer mode** and `meta.Reset()` discards any metagroup state it had
accumulated (`leafnode.go:2088–2100`). Leadership is pinned to the servers the remote connects to.
The leaf is not a peer of the hub's meta group; it is a participant in the hub's JetStream. The
thread's unanswered follow-up — "does it then have disk persistency on the leafnode if the connection
to the cluster is lost?" — is the right question, and the wiki does not yet have a sourced answer.

## Prevention

- Decide **one JetStream or two** before configuring anything. One JetStream means the system account
  crosses the leafnode; two means distinct domains and explicit `--js-domain` addressing.
- Grep the hub's log for `Extending JetStream domain` after every leafnode change. It is the only
  positive confirmation.
- Do not reuse a domain name. A domain is a namespace; two of them with the same name is the one
  configuration the server actively guards against.

## To verify

- Whether a leafnode that extends a hub's JetStream retains any **local** durability when the link
  drops. The thread asks; no public source read so far answers it.
- The docs' leafnode chapter (`raw/nats-docs/learn/topologies/leaf-nodes.md`) has not been ingested —
  that is plan step 6, and [[leafnode]] and [[gateway]] remain wanted pages.

## Related

[[account]] · [[tls-in-nats]] · [[cross-account-sharing]] · [[js-api-subjects]] · [[key-value]] ·
[[object-store]] · [[nats-timeout]] · [[build-a-3-node-cluster]]

## Sources

- [[s-gh-7834-leafnode-same-js-domain]] — the thread, its full configuration, and the four
  observations.
- [[s-nats-server-leafnode-js-domains]] — the decision function, the mapping table and the guard, read
  at v2.14.6 with file and line.
- [[s-gh-5859-unexpected-nats-timeout]] — an independent log showing
  `JetStream using domains: local "", remote "myjsdomain"` per leafnode connection.
- [[s-docs-accounts-and-multitenancy]] — what `$SYS` is and why it is the account that crosses.
