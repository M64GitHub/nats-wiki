---
title: "no suitable peers for placement"
type: gotcha
area: [topology, jetstream]
verified-against: nats-server 2.14.6
verified-on: 2026-09-01
tags: [10005, placement, server_tags, replicas, debug-logs]
aliases: ["no suitable peers", 10005, "JSClusterNoPeersErrF", "cannot increase replicas"]
sources: [s-gh-7982-no-suitable-peers, s-docs-placement, s-docs-sizing-and-resources, s-adr-7-server-error-codes, s-nats-server-mqtt-websocket-observed, s-nats-server-jetstream-cluster]
created: 2026-08-31
updated: 2026-09-01
---

# "no suitable peers for placement"

Creating a stream, or raising an existing stream's replica count, fails immediately — on a cluster
that looks healthy and creates other streams without complaint.

## Symptom

```
nats: error: could not create Stream: no suitable peers for placement, tags not matched ['disk:sdd'] (10005)
```

or, on an edit:

```
could not edit Stream <name>: no suitable peers for placement (10005)
```

Error **`10005`** is `JSClusterNoPeersErrF` (source: [[s-adr-7-server-error-codes]]). Note that the
edit form often carries **no bracketed detail at all** — that is the harder case, and the one
gh#7982 was about.

## Quick triage

```
nats server info <server>          # the Tags line — what this server actually advertises
nats stream info <stream>          # current replicas, cluster, and where the copies are now
nats account info                  # the account's Storage / Streams ceilings
```

Then, if none of those explains it, **turn on debug logging on the servers** and retry. The peer
selection is logged per rejected candidate, with the reason
(source: [[s-gh-7982-no-suitable-peers]]):

```
[DBG] Peer selection: discard ** reason: not target cluster **
```

**This is the only published way to see the server's reasoning.** The `10005` response names, at
most, an unmatched tag; it never says which peers were considered or why each was rejected.

## Causes, ranked

### 1. A requested tag no server carries

Placement tags are an **intersection** — a server qualifies only if it has *every* tag listed.
Matching **folds case** (`disk:ssd` = `disk:SSD`) but **spelling is exact**, so `disk:sdd` matches
nothing (source: [[s-docs-placement]]).

*Confirm:* the error names the tag in brackets. Otherwise read the tags back with
`nats server info <server>` for each server — **a typo in `server_tags` is silent** until a
placement asks for it.

*Fix:* correct the spelling to match what the servers advertise, or add the tag to enough servers.

### 2. The placement names the wrong cluster

The one that produced gh#7982. The servers were healthy, storage was verified on every node, and
new streams were being created fine — but the stream's placement pointed at a **cluster the
candidate peers were not in**. The client-side error is indistinguishable from cause 1
(source: [[s-gh-7982-no-suitable-peers]]).

*Confirm:* the debug line above, `reason: not target cluster`.

*Fix:* correct the `cluster` in the stream's placement, or the cluster name in the servers' config.

### 3. Fewer qualifying servers than the replica count asks for

Placement **does not relax the constraint to fit the replica count** — it fails so you notice. Ask
for `--replicas 3` when only two servers carry the required tags and you get the same error
(source: [[s-docs-placement]]).

*Confirm:* count the servers whose `Tags` line satisfies the whole intersection, and compare with
the replica count.

*Fix:* tag another server, or lower the replica count — remembering that even counts buy nothing
([[replicas]]).

### 4. The account's storage ceiling, not the node's disk

On an **un-tiered** account an R3 stream counts as **`replicas × bytes`** against `MaxStore`, so a
stream that fits comfortably on every node's disk can still have nowhere to place its third replica
(source: [[s-docs-sizing-and-resources]]).

*Confirm:* `nats account info` — compare `Storage` against the stream's size **times the replica
count**. Note that in operator mode the ceiling comes from the account JWT, not server config.

*Fix:* raise the account's `MaxStore` (which means editing and **pushing the JWT** in operator
mode), move to a tiered account, or shrink the stream. [[jetstream-sizing]] works the arithmetic
through.

### 5. Genuinely no capacity

The straightforward case, and the one people check first — which is why it is last here.

*Confirm:* `df -h` on each candidate's `store_dir`, against `max_file_store`.

## Why "new streams work" proves nothing

gh#7982's cluster created new streams without complaint the whole time. A new stream may be placed
with no constraint, or with a different one, or at a lower replica count — so it exercises none of
the causes above. **Do not treat a successful create as evidence that placement is configured
correctly.**

## Prevention

- **Read tags back before placing against them.** `nats server info <server>` on each server, then
  place against exactly what they advertise.
- **Size the account, not just the node** — see [[jetstream-sizing]] step 3.
- Keep the `cluster` value in stream placements under the same review as the servers' `cluster
  { name: … }`; nothing cross-checks them.

## Known gap

The reporter's closing request in gh#7982 is still open:

> "it would be nice to somehow receive this error when trying to mutate"

**The API response does not carry the per-peer rejection reasons.** Until it does, debug logging is
the diagnostic, and it must be enabled and the operation retried — you cannot get the reason for a
failure that already happened.

## Explained by

[[stream-placement]] — how the meta leader selects peers, and why the constraint fails loudly rather
than falling back.

## It can also arrive as "MQTT clients cannot connect"

`10005` is a JetStream error, but [[mqtt]] stores its state in JetStream streams it creates for
itself, so an MQTT connection can fail on placement with nothing MQTT-shaped in the symptom.

Reproduced on 2.14.6: a two-node cluster with `mqtt { stream_replicas: 3 }` refuses every MQTT
connection, and **the device gets the TCP connection closed with no CONNACK at all** — not a return
code, nothing an MQTT client can report or log. The whole diagnosis is server-side
(source: [[s-nats-server-mqtt-websocket-observed]]):

```
[INF] Creating MQTT streams/consumers with replicas 3 for account "$G"
[ERR] 127.0.0.1:50068 - mid:25 - "cluster-probe3" - unable to connect: create sessions stream
      for account "$G": no suitable peers for placement (10005)
```

The cause is the ordinary one — more replicas asked for than the cluster has peers — but the request
was never written by an operator: unset, `mqtt.stream_replicas` is **derived from the number of
addresses in the server's own `routes` list**. The related failure, before a meta leader exists, times
out instead:

```
[ERR] ... unable to connect: lookup sessions stream for account "$G": timeout after 5.000369875s:
      request type "SL" on "$JS.API.STREAM.INFO.$MQTT_sess"
```

That timeout is the meta layer, not placement: a JetStream API request that reaches a server which is
**not** the meta leader is dropped without a reply, and a server answers `10008 JetStream system
temporarily unavailable` only once it *knows* the group is leaderless — so while a leader is still
being elected the only symptom is the client's own timeout ([[meta-layer]]; source:
[[s-nats-server-jetstream-cluster]]).

**How to confirm**: grep the server log for `Creating MQTT streams/consumers with replicas`, and
compare that number against `/jsz`'s `meta_cluster.cluster_size`.

## Related

[[stream-placement]] · [[replicas]] · [[jetstream-sizing]] · [[raft-in-nats]] · [[error-codes]] ·
[[streams-deleted-when-clustering-a-standalone-server]]

## Sources

[[s-gh-7982-no-suitable-peers]] · [[s-docs-placement]] · [[s-docs-sizing-and-resources]] ·
[[s-adr-7-server-error-codes]] ·
[[s-nats-server-mqtt-websocket-observed]] · [[s-nats-server-jetstream-cluster]]
