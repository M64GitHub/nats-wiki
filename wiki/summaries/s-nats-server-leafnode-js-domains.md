---
title: "nats-server v2.14.6 — JetStream over a leafnode: domains and the system account"
type: summary
area: [topology, jetstream, security]
source-url: https://github.com/nats-io/nats-server/tree/v2.14.6/server
source-path: raw/nats-server-src/leafnode-js-domains-v2.14.6.md
author: nats-io/nats-server contributors
article: "server/leafnode.go and server/jetstream_api.go at v2.14.6"
date: 2026-08-31
version: "2.14.6"
tags: [leafnode, jetstream-domain, system-account, extending-jetstream, denyAllClientJs, mapping]
aliases: []
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# nats-server v2.14.6 — the three outcomes of a leafnode carrying JetStream

Read to settle why a stream created on one side of a leafnode is invisible on the other, and why
giving the two sides **different** domains can make things start working. Every claim is a line of
`nats-server` at tag **v2.14.6**; the quoted ranges are in
`raw/nats-server-src/leafnode-js-domains-v2.14.6.md`.

## Key claims

### One function decides, and there are exactly three outcomes

`Server.addLeafNodeConnection` (`leafnode.go:1951`) runs per leafnode connection, per account. Its
comment states the rule before any code (`leafnode.go:2034–2035`):

> "Deny (non domain) JetStream API traffic unless system account is shared and domain names are
> identical and extending is not disabled"

The branch at `leafnode.go:2063` is the decision:

```go
if opts.JetStreamDomain != myRemoteDomain || (!opts.JetStream && (opts.JetStreamDomain == _EMPTY_ &&
    opts.JetStreamExtHint != jsWillExtend)) || sysAcc == nil || acc == nil || forceSysAccDeny {
```

| condition | log line | effect |
|---|---|---|
| domains **differ**, account **is** the system account | `System account connected from …` then `JetStream not extended, domains differ` | `denyAllJs` merged both ways |
| domains **differ**, any other account | `JetStream using domains: local %q, remote %q` | `denyAllClientJs` merged both ways |
| domains **match**, account **is** the system account | `Extending JetStream domain %q as System Account connected from server %s` | **extends** — the meta controller goes into observer mode and `meta.Reset()` discards local metagroup state |
| domains **match**, any other account | (debug) `Adding deny %+v for account %q` | `denyAllClientJs` merged both ways |

`denyAllClientJs` is `["$JS.API.>", "$KV.>", "$OBJ.>"]` and `denyAllJs` adds `"$JSC.>"` and `"$NRG.>"`
(`jetstream_api.go:323–324`). The last row is the one people trip over: **matching domains alone
extend nothing.** The source comment says why the deny is needed even then — to avoid duplicate
delivery through both the system account and the real one.

### The domain is a subject mapping, installed into every non-system account

When `domain` is set and JetStream is on, the server adds `generateJSMappingTable(domain)` to every
non-system account (`leafnode.go:2114–2121`). The table (`jetstream_api.go:326–352`) maps

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

The source's own comment on this table is worth knowing before designing around it: "This set of
mappings is very very very ugly", because `$KV` and `$OBJ` were made independent subject spaces
rather than living under `$JS.API`.

This is why **different** domains work: each side owns a distinct `$JS.<domain>.API.>` prefix, so a
client can address the other domain explicitly (`nats --js-domain <name> …`).

### The server explicitly guards against two identical domain names

When the connection did **not** extend (`blockMappingOutgoing`), the server also denies **publishing**
`$JS.<domain>.API.>` outwards over that leafnode (`leafnode.go:2122–2131`), with the comment:

> "make sure that messages intended for this domain, do not leave the cluster via this leaf node
> connection. This is a guard against a miss-config with two identical domain names and will only
> cover some forms of this issue, not all of them. This guards against a hub and a spoke having the
> same domain name. But not two spokes having the same one and the request coming from the hub."

So identical domains without a shared system account are not merely unsupported — the server actively
stops the traffic, and knows it only catches some of the cases.

### The observable line

`c.Noticef("JetStream using domains: local %q, remote %q", …)` at `leafnode.go:2084` prints at INFO on
every leafnode connection that is **not** extending. `local ""` means this server has no domain set.
The remote's domain arrives in the leafnode INFO protocol (`leafnode.go:1696`).

## Practical takeaways

- Extending JetStream over a leafnode needs **both** halves: the leafnode remote connecting **as the
  system account**, and **identical** `jetstream { domain }` on both ends. Either alone gives you a
  deny.
- If you do not want one JetStream, give the two sides **different** domains and address across with
  `$JS.<domain>.API.>`. That is the supported cross-domain path, not a workaround.
- `JetStream using domains: local "x", remote "y"` in the log is the server telling you it is not
  extending, on that connection, for that account.

## Relevance to the wiki

The authority behind [[streams-not-visible-across-a-leafnode]], and the explanation of every
observation in [[s-gh-7834-leafnode-same-js-domain]] — including the one the reporter called "really
weird".

## Questions it answers

- **Q42** — why aren't my streams visible on both ends of a leafnode connection.

## Pages touched

[[streams-not-visible-across-a-leafnode]] · [[account]] · [[js-api-subjects]] · [[key-value]] ·
[[object-store]]
