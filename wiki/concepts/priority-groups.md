---
title: Priority groups
type: concept
area: [jetstream]
since: [2.11]   # overflow and pinned_client; the prioritized policy is 2.12
verified-against: nats-server 2.14.6
verified-on: 2026-09-01
tags: [priority-groups, overflow, pinned_client, prioritized, unpin, 423]
aliases: [priority group, pinned client, overflow policy, PriorityPolicy]
sources: [s-adr-42-priority-groups, s-docs-policies, s-nats-server-constants-2.14.6, s-docs-upgrade-to-2.12, s-docs-worker-pool, s-relnotes-2.11, s-relnotes-2.12]
created: 2026-08-31
updated: 2026-09-03
---

# Priority groups

Priority groups let the server decide **which client of a pull [[consumer]] gets served**, rather
than serving pulls round-robin as they arrive. Introduced for **nats-server 2.11**
(source: [[s-adr-42-priority-groups]]).

**Why you would reach for them**, in the docs' own words on the plain worker pool they replace: a
pool sharing one consumer distributes by demand, so a redelivered message can arrive at a second
worker and nothing decides *which* worker gets what. Priority groups are the answer to that — "send
everything to one worker until it fails, or keep a standby worker idle until the pool falls behind"
(source: [[s-docs-worker-pool]]). Those two sentences are `pinned_client` and `overflow` respectively,
described from the problem rather than from the mechanism. See [[worker-pool]].

## What configures it

Two `ConsumerConfig` fields turn it on:

```
PriorityGroups: ["jobs"]
PriorityPolicy: "overflow" | "pinned_client" | "prioritized"
```

Hard rules:

- **Pull consumers only.** Configuring it on a push consumer is an error.
- **`PriorityGroups` needs at least one entry.** ADR-42 says the initial implementation allows
  **exactly one group per consumer** and that more is an error; **at 2.14.6 that is not what
  happens.** Two groups are accepted at creation and both are stored and reported back
  (`priority_groups=['g1', 'g2']`, observed 2026-09-01 —
  `raw/nats-server-src/priority-groups-observed-v2.14.6.md`), which matches
  `learn/jetstream/priority-groups.md`: `--overflow-groups` and `--pinned-groups` take a
  comma-separated list, "so passing two looks legal, and the server accepts it, but it uses only the
  first group and ignores the rest" (spot-checked 2026-08-31 — that page has not been ingested).
  **The run confirmed acceptance, not the "uses only the first" half**, so the docs' warning stands
  unverified and is the safer assumption. To split work by region or tier today, run **separate
  consumers** on the same stream, each with its own group. The sources disagree: recorded as
  `inbox/docs-issues.md` #37.
- Group names must match `limited-term` (`A-Z a-z 0-9 - _ / =`) and are **capped at 16 characters**.
- **Every pull request must carry `"group": "<name>"`.** A pull outside a valid group errors.
- **The policy is editable, whatever ADR-42 says.** The ADR states "You cannot update a consumer
  from having groups to not having them, or vice versa, and you cannot switch between policies. Only
  `PriorityTimeout` is updatable today." **All three transitions are accepted at 2.14.6**, with no
  error and immediate effect: `overflow` → `pinned_client`, groups removed from a consumer that had
  them, and groups given back to one that had none (observed 2026-09-01 with nats CLI 0.4.0 —
  `raw/nats-server-src/priority-groups-observed-v2.14.6.md`). `learn/jetstream/policies.md` agrees
  with the server and lists priority policy under *can change*, noting that `nats consumer edit` has
  no flag for it, so you pass a config file with `--config`. The disagreement is
  `inbox/docs-issues.md` #37; prefer the server. Unlike the genuinely fixed policies on [[consumer]],
  this one does **not** cost you a recreate.
- **`priority_timeout` defaults to 2 minutes** when `pinned_client` is set with no explicit value
  (`120000000000` ns, observed 2026-09-01), and it is updatable — the one part of the ADR's sentence
  that holds.

## The three policies

### `overflow` — serve only when backed up

Pulls are served only when the consumer is above a threshold; otherwise they sit idle exactly as if
no messages were available, heartbeats included.

| pull field | meaning |
|---|---|
| `min_pending` | deliver only when the consumer's `num_pending` is ≥ this |
| `min_ack_pending` | deliver only when `ack_pending` is ≥ this |
| `failover` | seconds with **no pull requests at all** after which this pull is served regardless |

If both `min_pending` and `min_ack_pending` are set, **either one being satisfied delivers**
(boolean OR). `AckPolicy` must be `explicit`.

> **`failover` does not work on 2.14.** The ADR carries an explicit note: *"As of NATS Server 2.14
> the `failover` option is not implemented; the server silently ignores the field and does not
> enforce the bounds described above."* Its documented range (minimum 5, maximum 3600) is
> unenforced. A design that nominates standby regions with `failover` will behave as plain
> `overflow` — with no error to tell you.

### `pinned_client` — one active client, the rest on standby

The server sends every message for the group to one **pinned** client, stamped with a
**`Nats-Pin-Id: <id>`** header. That client must echo the value as `"id"` on every subsequent pull.

`PriorityTimeout` (**2 minutes by default** — `consumer.go:582`) is the liveness window: if the pinned client
issues no pull inside it, the server picks another. **The timeout only resets when the pinned client
starts a new pull**, so a new pull request doubles as the client's heartbeat.

The switch sequence: stop delivering for the group → wait for in-flight messages to complete →
pick the new client → store the new pinned nuid → deliver with the ID set → raise an advisory →
answer **`423`** to any pull carrying a non-matching `id`.

Two details that matter in practice:

- **A pull that omits `id` while someone else is pinned is not rejected.** It waits as a standby
  candidate and becomes eligible when the pin clears. `423` is reserved for the unambiguous
  "stale or wrong ID" case.
- **This is not exclusivity.** Quoting the ADR: *"there will be times when one client thinks it is
  pinned while processing messages when it isn't anymore because the server switched."* Do not
  build a mutual-exclusion guarantee on it — see [[key-value]] for a CAS-based alternative.

Sizing: keep `PriorityTimeout` comfortably above the pull's `Expires`. With the 2-minute default,
the ADR suggests a maximum `Expires` of about 1 minute, so the client has time to pull, receive or
expire, process, and pull again before the pin lapses.

Admin unpin: **`$JS.API.CONSUMER.UNPIN.<STREAM>.<CONSUMER>`** with payload `{"group": "groupName"}`.

Consumer state gains a `PriorityGroups` list of `{group, pinned_client_id, pinned_ts}` — visible in
`ConsumerInfo`, see [[consumer]].

### `prioritized` — served in priority order

**Added in nats-server 2.12**, not 2.11 with the other two policies
(source: [[s-docs-upgrade-to-2.12]]) — ADR-42 describes all three together and is tagged `2.11`, so
the ADR alone will mislead you about what a 2.11 server supports.

Each pull carries **`"priority": N`**, an integer **0–9**; a pull with no priority is `0`.
**Lower priorities are always served first**, round-robin within a priority. Out-of-bounds or
non-numeric values error.

Unlike `overflow` there is **no delay** before a lower-priority client is served, so work is always
picked up promptly — at the cost, in the ADR's words, of "some flip-flop in work moving between
regions".

## What you can observe

| event | subject |
|---|---|
| a group switched to a new pinned client | `$JS.EVENT.ADVISORY.CONSUMER.PINNED.<stream>.<consumer>` |
| a pin was lost | `$JS.EVENT.ADVISORY.CONSUMER.UNPINNED.<stream>.<consumer>` |

**Not** `GROUP_PINNED` / `GROUP_UNPINNED`, which is what the docs' advisory reference says — those
subjects do not exist and a subscription to them receives nothing. ADR-42 and the server agree on
the values above; see [[advisories]] and issue 2–3 in `inbox/docs-issues.md`.

Types `io.nats.jetstream.advisory.v1.consumer_group_pinned` and `…consumer_group_unpinned`. The
unpinned advisory carries a **`reason`** of **`admin`** or **`timeout`**, which is what separates a
deliberate unpin from a client that went quiet. See [[advisories]].

**A `423` during a pin switch is normal**, not an incident — clients are expected to clear their
stored ID and keep pulling.

## Version notes

- **2.11.0**: "Pull consumer priority groups with pinning and overflow (#5814, #6078, #6081) …
  The `PriorityGroups` and `PriorityPolicy` options in the consumer configuration control the
  policy" (source: [[s-relnotes-2.11]]) — the body, like the ADR, names pinning and overflow only.
- **2.11.2**: "Consumer priority groups will no longer get stuck in a tight-loop if there are
  multiple requests from different clients but some are not receiving due to the priority policy"
  (#6749) — a 2.11.0/2.11.1 hazard.
- **2.11.7**: a push consumer configured with priority groups now returns an error (#7053).


- **2.12.0**: "Prioritised mode for consumer priority groups (#7113) — Allows for low-latency
  switching between clients based on the priority set" — the `prioritized` policy's release body
  (source: [[s-relnotes-2.12]]). **2.12.5**: unpin responses include pending messages and bytes
  (#7815); unpinning is handled on step-down and "allows the next client to pick up the next pin
  without waiting for new messages" (#7819); an overflowed pull with `min_pending` or
  `min_ack_pending` above the threshold handled (#7795). **2.12.8**: setting the pinned headers
  simplified (#8032).


## To verify

- The ADR's status is **Approved**, not *Implemented*, even though it is tagged `2.11` and the
  server behaviour is described in the present tense. Only the `failover` gap is explicitly called
  out as unimplemented; nothing read so far confirms the rest is complete on 2.14.
- ~~Whether `PriorityTimeout` has a server-side default~~ — **it does: 2 minutes**
  (`JsDefaultPinnedTTL`, `server/consumer.go:582` at v2.14.6, described there as "the default grace
  period for the pinned consumer to send a new request before a new pin is picked by a server").
  So the ADR's example value is the real default (source: [[s-nats-server-constants-2.14.6]]).
- "Delivery stats per group" and multiple groups per consumer are named as **future** iterations.

## Related

[[consumer]] · [[ack-and-redelivery]] · [[worker-pool]] · [[advisories]] · [[stream]] ·
[[nats-server-2.11]] · [[nats-server-2.12]]

## Sources

[[s-adr-42-priority-groups]] · [[s-docs-policies]] · [[s-docs-upgrade-to-2.12]] ·
[[s-nats-server-constants-2.14.6]]

Run directly, not read: `raw/nats-server-src/priority-groups-observed-v2.14.6.md` — nats-server
v2.14.6 with nats CLI 0.4.0, 2026-09-01. Behind `inbox/docs-issues.md` #37. ·
[[s-docs-worker-pool]] · [[s-relnotes-2.11]] · [[s-relnotes-2.12]]
