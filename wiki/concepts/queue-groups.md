---
title: Queue groups
type: concept
area: [core, clients, topology]
since: [2.10]   # present at 2.10, the oldest line this wiki covers; not the arrival
verified-against: nats-server 2.14.6
verified-on: 2026-09-03
tags: [queue-group, --queue, load-balancing, random-selection, readiness, cluster, leafnode, gateway, geo-affinity, at-most-once, subsz, qgroup, NATS-RPLY-22]
aliases: [queue group, queue groups, queue subscription, queue subscriber, queue subscribe, QueueSubscribe, --queue, qgroup, load balancing in core NATS, geo-affinity for queue groups, "which member gets the message"]
sources: [s-docs-core-nats-queue-groups, s-nats-server-request-reply, s-nats-server-request-reply-observed, s-docs-core-nats-request-reply, s-nats-cli-request-reply-source, s-relnotes-2.10, s-docs-super-clusters, s-nats-server-core-delivery-observed]
created: 2026-09-03
updated: 2026-09-03
---

# Queue groups

**A queue group is a name that several subscriptions on one subject share; for each message the server
picks one member at random and delivers to it alone.** It is core NATS's whole load-balancing
mechanism — no configuration, no coordinator, no memory of who got what — and its promise is
[[core-nats-delivery]]'s: at most once, to a member that was there.

## What it is

A subscription joins a group by naming it as it subscribes: `nats sub orders.created --queue
packers`, `nc.QueueSubscribe(subject, "packers", …)` in Go, `{ queue: "packers" }`, `queue="packers"`,
`.subscribe(subject, "packers")`, `queue_subscribe`, `queueGroup:`, `natsConnection_QueueSubscribe`
in the others (source: [[s-docs-core-nats-queue-groups]]). "There's nothing to configure on the
server … The server learns a group exists the moment its first member subscribes." Membership is the
exact name on the exact subject; a member leaves by unsubscribing or disconnecting — including when
the server disconnects it as a slow consumer ([[slow-consumer-detected]]). The only server view of a
group is `/subsz?subs=1&acc=$G`, one row per member with `qgroup` and a `msgs` counter — **per
server**: a member on a peer never appears there (run E; source:
[[s-nats-server-request-reply-observed]]).

## How it behaves

### The pick: random, not round-robin, not readiness-aware

For each message the server takes the group's member list, draws a random start index, and delivers
to the first member from there that can take it (`client.go:5516–5519`; source:
[[s-nats-server-request-reply]]). So "the same packer can be chosen twice in a row, and over a
handful of messages the split can look lopsided" (the docs), and — measured, run C — **a busy member
keeps receiving its share**: two members, one running `sleep 1` before every reply, under 20
concurrent requests split 12 / 8 and then 8 / 12; the slow one answered its eight one per second while
the fast one sat idle, and the requests took 8.6 s and 12.3 s to complete. The services chapter's
"the server delivers each message to whichever queue-group member is ready" is not what the server
does (`inbox/docs-issues.md` #86). A member stops receiving only when its subscription or connection
is gone; nothing looks at its backlog. Size a pool on that: the requester's timeout, not the group,
is what bounds a slow member, and [[worker-pool]] is where demand-based distribution lives.

### Coexistence, one subject, wildcards, typos

- A plain subscriber and a group on the same subject are independent: the plain one gets every
  message, the group one copy (run E5: a plain subscriber on a third node received all 200 while the
  group split 98 / 102).
- Membership is evaluated **after** subject matching: two members with the same name on different
  subjects share nothing. A group may subscribe with a wildcard and then balances everything it
  matches.
- A typo makes a second group — `packers` and `packer` each receive one copy, both subscriptions
  succeed, nothing warns. Byte-identical names (source: [[s-docs-core-nats-queue-groups]]).

### In a cluster: every member counts once, wherever it sits

A peer announces its members with `RS+ <account> <subject> <queue> <weight>`, and the sublist expands
that one entry to its weight before the pick (`sublist.go:741–747`; source:
[[s-nats-server-request-reply]]). Measured on the lab (run E): one member on the publisher's server
and three on a peer split **90 / 97 / 106 / 107** over 400 publishes — a quarter each; one and one
split 92 / 108; two local and one remote 100 / 104 / 96. **There is no preference for the publisher's
own server inside a cluster**; the docs' "a cluster adds a locality preference" refers to the
super-cluster case below (`inbox/docs-issues.md` #88). A message that arrived over a route is delivered
only to that server's own members and never routed again; the publisher's server sends it once.

### Across a leafnode: the publisher's side wins, and the hub's split skews

A member behind a leafnode connection is only a fallback: with one member on the hub and one on the
leaf, 200 publishes on the hub went **200 / 0** and 200 on the leaf went **0 / 200**; members only on
the far side receive everything (93 / 107 across two of them) — run H, source:
[[s-nats-server-request-reply-observed]]. The rule is the same in the source for a spoke and a hub
("Remember that leaf in case we don't find any other candidate", `client.go:5547–5552`), and
2.10.22 / 2.10.23 changed how a leaf's members balance when the message comes *from* the leaf side
(#5982, #6043; source: [[s-relnotes-2.10]]).

The surprise: **a leaf holding members skews the hub's own split.** Two members on the hub and two on
the leaf, publishing on the hub, split the hub's two **148 / 52**, then 89 / 311, 297 / 103, 302 / 98
over three repeats; two and one gave 137 / 263; three hub members and two leaf members gave
70 / 75 / 255; the control with no leaf member, 196 / 204. The leaf's *n* entries sit side by side in
the match list, the random walk skips them and lands on the *next* local member, which gets its own
share plus the leaf's *n* (`inbox/server-issues.md` SI-8). Until that is settled upstream, keep a
group's members on one side of a leafnode, or expect the member after the leaf's entries to carry a
multiple of the others' load.

### Across a gateway: an exclusion list

Between clusters the preference is real and it is implemented as an exclusion: the publisher's
cluster delivers to its own members and tells the remote clusters which group names it served, and
they skip those — the message crosses at all only for plain interest or for a group the local cluster
could not serve ([[gateway]] quotes the lines; source: [[s-docs-super-clusters]] for the docs' form).

### With request-reply

A group of responders answers each request once, which is what `nats reply`'s default group
`NATS-RPLY-22` gives you; a group of one behaves like a plain subscriber, so independent responders
need distinct names ([[request-reply]] — scatter-gather; source: [[s-docs-core-nats-request-reply]]).

### At-most-once

"If the server picks a packer and it dies *after* delivery, that message is gone — the server won't
retry it with another member." Duplicates come only from a publisher's own retries. Work that must
survive a member's crash is a JetStream consumer shared by workers — [[worker-pool]] — whose
distribution is by demand and whose redelivery is [[ack-and-redelivery]]'s.

## What configures it

| where | what | default | governs |
|---|---|---|---|
| the subscription | the group name (`--queue`, `QueueSubscribe`, …) | none — a plain subscription | membership; exact string, per subject |
| server | nothing | — | there is no server-side setting for a group |
| server | `max_pending` / `write_deadline` | 64 MB / `10s` | when a member that stops reading is cut from the group as a slow consumer — [[slow-consumer-detected]] |
| CLI | `nats reply --queue=NATS-RPLY-22` | as shown | the responders' group |
| monitoring | `/subsz?subs=1&acc=$G` → `qgroup`, `msgs`, `cid` | — | this server's members; `nats server request subscriptions` with a system user for every server ([[monitoring-endpoints]]) |

The `_sys_` group that also appears in `/subsz` belongs to the server's own direct-get responders
([[direct-get]]).

## Limits and failure modes

- **No fairness, no readiness.** A member with a slow handler drags its random share behind it;
  the group does not route around it. Keep handlers fast or bound the requester's wait.
- **No delivery guarantee.** A member that dies after delivery, or that is cut as a slow consumer
  with messages in its buffer, loses them.
- **A leaf's members skew the hub's split** (SI-8) and never receive while the hub has a member.
- **A peer's members are invisible on this server's `/subsz`**; a group that looks under-subscribed
  on one node may be fine cluster-wide.
- **The name is the group.** A typo, a trailing space or a different case is a second group and a
  second copy of every message.
- **No ordering across members.** Order per publisher connection holds for each member's slice, not
  across the group ([[core-nats-delivery]]).

## Related

[[core-nats-delivery]] · [[request-reply]] · [[worker-pool]] · [[slow-consumer-detected]] ·
[[gateway]] · [[leafnode]] · [[monitoring-endpoints]] · [[direct-get]] · [[ack-and-redelivery]] ·
[[supercluster-slows-when-a-remote-subscriber-joins]] · [[nats-cli]]

## Sources

- [[s-docs-core-nats-queue-groups]] — the definition, the random pick, coexistence, the typo, the
  docs' locality sentence, the primer's slow-consumer line.
- [[s-nats-server-request-reply]] — the selection loop, the weight expansion, the leaf fallback, at
  v2.14.6 with lines.
- [[s-nats-server-request-reply-observed]] — runs C, E and H: the busy member, the cluster split,
  the leafnode rule and its skew.
- [[s-docs-core-nats-request-reply]] — `NATS-RPLY-22` and the group of one.
- [[s-nats-cli-request-reply-source]] — why a `nats reply` member serialises its requests.
- [[s-relnotes-2.10]] — the 2.10.22 / 2.10.23 leafnode load-balancing lines.
- [[s-docs-super-clusters]] — the docs' statement of geo-affinity.
- [[s-nats-server-core-delivery-observed]] — the `qgroup` field in `/subsz` (run D).
