---
title: Priority groups
type: concept
area: [jetstream]
since: [2.11]   # overflow and pinned_client; the prioritized policy is 2.12
verified-against: nats-server 2.14
verified-on: 2026-08-31
tags: [priority-groups, overflow, pinned_client, prioritized, unpin, 423]
aliases: [priority group, pinned client, overflow policy, PriorityPolicy]
sources: [s-adr-42-priority-groups, s-docs-policies, s-nats-server-constants-2.14.6, s-docs-upgrade-to-2.12]
created: 2026-08-31
updated: 2026-08-31
---

# Priority groups

Priority groups let the server decide **which client of a pull [[consumer]] gets served**, rather
than serving pulls round-robin as they arrive. Introduced for **nats-server 2.11**
(source: [[s-adr-42-priority-groups]]).

## What configures it

Two `ConsumerConfig` fields turn it on:

```
PriorityGroups: ["jobs"]
PriorityPolicy: "overflow" | "pinned_client" | "prioritized"
```

Hard rules:

- **Pull consumers only.** Configuring it on a push consumer is an error.
- **`PriorityGroups` needs at least one entry**, and the initial implementation allows **exactly
  one group per consumer** — more is an error.
- Group names must match `limited-term` (`A-Z a-z 0-9 - _ / =`) and are **capped at 16 characters**.
- **Every pull request must carry `"group": "<name>"`.** A pull outside a valid group errors.
- **You cannot add groups to a consumer that has none, remove them, or switch policy.** Only
  `PriorityTimeout` is updatable. Treat the policy as create-time, like the fixed policies on
  [[consumer]].

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
