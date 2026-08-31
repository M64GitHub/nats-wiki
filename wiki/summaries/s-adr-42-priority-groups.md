---
title: "ADR-42 — Pull Consumer Priority Groups"
type: summary
area: [jetstream]
source-url: https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-42.md
source-path: raw/adr/ADR-42.md
author: "@ripienaar (rev 1); @jarema, @MauriceVanVeen later revisions"
article: "ADR-42: Pull Consumer Priority Groups"
date: 2024-05-14          # revision 8 dated 2026-04-29
version: "2.11"           # ADR tags: jetstream, server, 2.11
tags: [priority-groups, overflow, pinned_client, prioritized, unpin, advisories]
aliases: [ADR-42, priority groups, pinned client]
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# ADR-42 — Pull Consumer Priority Groups

Status **Approved**, tagged `2.11`, eight revisions to 2026-04-29. Adds server-side steering of
*which* client of a pull consumer gets served.

## Key claims

### Configuration

Two `ConsumerConfig` fields activate the feature: **`PriorityGroups`** (a list, at least one entry)
and **`PriorityPolicy`**.

- **Pull consumers only** — configuring it on a push consumer must raise an error.
- **The initial implementation allows exactly one group per consumer**; more than one is an error.
- Group names must match `limited-term` from ADR-6 (`A-Z a-z 0-9 - _ / =`) and **may not exceed 16
  characters**.
- **You cannot update a consumer from having groups to not having them, or vice versa, and you
  cannot switch between policies.** Only `PriorityTimeout` is updatable today.
- Every pull request must then carry **`"group": "<name>"`**; a pull outside a valid group errors.

### The three policies

**`overflow`** — serve a pull only when the consumer is backed up. Pull fields:

| field | meaning |
|---|---|
| `min_pending` | deliver only when the consumer's `num_pending` is ≥ this |
| `min_ack_pending` | deliver only when `ack_pending` is ≥ this |
| `failover` | seconds with no pull requests at all after which this pull is served anyway |

If both `min_pending` and `min_ack_pending` are given, **either being satisfied delivers** (boolean
OR). Unserved pulls "sit idle in the same way that they would if no messages were available",
heartbeats included. `AckPolicy` must be `explicit`.

`failover`'s stated range is **minimum 5, maximum 3600** — but the ADR carries an explicit note:

> **"As of NATS Server 2.14 the `failover` option is not implemented; the server silently ignores
> the field and does not enforce the bounds described above."**

**`pinned_client`** — one client receives everything, others stand by.

- The server picks a pinned client and sends every message to it with a **`Nats-Pin-Id: <id>`**
  header; the client must echo that value as **`"id"`** on every subsequent pull for the group.
- **`PriorityTimeout`** (default 2 minutes in the ADR's example) — if the pinned client issues no
  pull within it, the server switches. The timeout only resets when the pinned client starts a new
  pull inside the window.
- The switch flow: stop delivering for the group → wait for in-flight messages → pick the new
  client → store the new pinned nuid → deliver with the ID set → **raise an advisory** → answer
  **`423`** to any pull carrying a non-matching `id`.
- A pull that **omits** `id` while another client is pinned is **not** rejected — it waits as a
  standby candidate. `423` is reserved for the "stale or wrong ID" case.
- The ADR is emphatic: **"We should not describe this in terms of exclusivity as there is no such
  guarantee, there will be times when one client thinks it is pinned while processing messages when
  it isn't anymore because the server switched."**
- Recommended sizing: keep `PriorityTimeout` well above the pull's `Expires` — with the 2-minute
  default, a maximum `Expires` of about 1 minute.
- Admin API: **`$JS.API.CONSUMER.UNPIN.<STREAM>.<CONSUMER>`**, payload `{"group": "groupName"}`.
- Consumer state gains `PriorityGroups`, a list of
  `{group, pinned_client_id, pinned_ts}`.

**`prioritized`** — pulls carry **`"priority": N`**, an integer **0–9**; a pull with no priority is
`0`. **Lower priorities are always served first**; within a priority, round-robin. Out-of-bounds or
invalid values error. Unlike `overflow` there is no delay before a lower-priority client is served,
so work is picked up immediately at the cost of "some flip-flop in work moving between regions".

### Advisories

| event | subject |
|---|---|
| a group switched to a new pinned client | `$JS.EVENT.ADVISORY.CONSUMER.PINNED` |
| a pin was lost | `$JS.EVENT.ADVISORY.CONSUMER.UNPINNED` |

Types `io.nats.jetstream.advisory.v1.consumer_group_pinned` and `…consumer_group_unpinned`. The
unpinned advisory carries a **`reason`** field, "one of `admin` or `timeout`".

## Why an operator cares

- **`failover` looks configured and does nothing on 2.14.** A design that leans on standby regions
  via `failover` will silently behave as plain `overflow`.
- **A `423` in the logs or client metrics is normal during a pin switch**, not an error to alert on.
- Priority policy **cannot be changed on a live consumer**, and neither can adding or removing
  groups — so this is a create-time decision, like the fixed policies on [[consumer]].

## Relevance to the wiki

The source for [[priority-groups]] and for the `priority_policy` values that [[consumer]] lists.
The `failover`-not-implemented note is the kind of fact that only exists in the ADR.

## Questions it answers

None in the bank yet — no row asks about priority groups. The 2.14 `failover` gap is worth a row if
a public thread is found asking about it.

## Pages touched

[[priority-groups]] · [[consumer]] · [[advisories]]
