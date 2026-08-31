---
title: "ADR-61 — unsafe meta group quorum rescue for disaster recovery"
type: summary
area: [jetstream, topology, deploy]
source-url: https://github.com/nats-io/nats-architecture-and-design/blob/main/adr/ADR-61.md
source-path: raw/adr/ADR-61.md
author: "@MauriceVanVeen"
article: ADR-61 Unsafe meta group quorum rescue for disaster recovery
date: 2026-07-07
version: "2.15"
tags: [meta-group, raft, quorum, disaster-recovery, peer-remove, 10224, advisory, jsz, 2.15]
aliases: [ADR-61, meta rescue, "$JS.API.META.RESCUE"]
sources: []
created: 2026-08-31
updated: 2026-08-31
---

# ADR-61 — the way out of a wedged meta layer

Status **Implemented**, tagged **2.15** — and 2.15 exists only as a preview
(`v2.15.0-preview.1`, 2026-08-24, `raw/release-notes/_tags-and-dates.md`). **None of this is in
2.14.6**: `$JS.API.META.RESCUE`, `meta_rescue`, `quorum_needed` and error `10224` appear nowhere in
the v2.14.6 source. Read it as what is coming, and as an accurate description of the trap it
addresses — which is entirely present today.

## Key claims

### The trap

"Like any Raft group, its quorum is computed from the configured peer set, not from the set of
currently live peers. A peer that is shut down and intended to not come back, without being
explicitly peer-removed still counts toward the quorum requirement."

The worked example is a normal operational sequence: a 3-node cluster grown to 5 for a migration,
then the two extras switched off without a peer-remove. The meta group still needs 3 of 5. One more
failure among the survivors leaves 2 reachable peers, no meta leader — "and with no quorum there is
no leader to process a peer-remove either, so the meta layer stalls."

The remedy before 2.15: bring **every** previously configured peer back at once, under the same
server names, and then run `$JS.API.SERVER.REMOVE`. "In real disaster recovery scenarios that is
frequently hard to achieve: hosts are gone, the previous server names are unknown, or the lost peers
are simply unrecoverable."

### The rescue is a broadcast on the system account

`$JS.API.META.RESCUE`, subscribed by every JetStream-enabled clustered server, each evaluating and
applying it locally — deliberately, "because … the full set of surviving server ids may not be known
up-front and the meta layer cannot be queried through its normal APIs". Request:
`{"quorum_needed": 3}`.

**A request on any account other than the system account is silently ignored** — no reply at all.
"An operator should therefore read a missing response from a given server as 'not JetStream-enabled,
not on the system account, or offline,' not as a rejection."

The API **does not rewrite the peer set**. It only lowers how many votes count as a majority;
dropping the dead peers is still `$JS.API.SERVER.REMOVE` afterwards — now possible because a leader
can be elected.

### Five checks, three of which are the safety gate

A server applies the rescue only if: the request arrived on the system account; `quorum_needed` is
≥ 1 and **no larger than its current effective quorum**; **this server is a voting member**; **it
knows of no meta leader** ("a healthy meta layer must not be reconfigured through this API"); and
**its own Raft log is not empty**. The last exists because "a lowered quorum could let it be elected
on empty votes alone while the lost peers holding the only copies of the data remain unreachable".

While a rescue is active, votes from empty-log peers do count — but only for a candidate that itself
has data, "so empty-log servers can still never form quorum purely among themselves".

### Finding the right number, per server, from `/jsz`

The ADR requires `meta_cluster.replicas` to be populated **on every server**, not just the meta
leader — "in the disaster recovery scenario this API targets there is, by definition, no meta
leader, so that field is empty on exactly the servers an operator needs to inspect." Two new fields
join it, also on every server: **`quorum_needed`** (always present, the server's current effective
quorum) and **`rescue`** (present and `true` only while a rescue is active).

### It expires after 5 minutes, and that is the safety net

The rescued quorum is held for **5 minutes**, during which the usual recomputation on a peer-set
change is suppressed — with one exception: if a change would recompute quorum to a value **at or
below** the rescued one, it is applied and **the rescue is cancelled immediately**. A peer-remove
that would compute a *higher* quorum neither disturbs the rescued value nor extends the timeout.

At expiry the server recomputes normally. "If some lost peers still remain in the peer set at expiry,
quorum returns to the natural value for the current peer set, which may differ from both the rescued
value and the original pre-rescue value. The operator may need to issue another rescue."

A second rescue is judged like the first — still no known leader, still only downward — and resets
the 5 minutes. "A rescue can only ever lower the value, never raise it back."

### It announces itself, loudly and durably

Every server that applies one logs a `WARN` and publishes
`$JS.EVENT.ADVISORY.SERVER.META_RESCUE` (`io.nats.jetstream.advisory.v1.meta_rescue`) carrying
`server`, `server_id`, `prev_quorum`, `new_quorum`, `cluster` and `domain` (only when one is
configured). "Advisories are ordinary published messages and do not depend on the meta leader, so
they are delivered even while the meta layer has no quorum" — which is what makes them usable here at
all.

### The rejection is per server, and typed

Each online server replies independently with
`io.nats.jetstream.api.v1.meta_rescue_response`. A rejection carries **`10224`**, HTTP 400,
`JetStream system rescue not applied: {err}` — the reason being a known leader, not a voting member,
an empty log, `quorum_needed` out of bounds, or a closed node. `prev_quorum` and `new_quorum` are
omitted on a rejection.

### The ADR's own warning

"The API is intentionally unsafe. Lowering the meta quorum weakens the guarantees Raft relies on to
prevent divergent logs; misuse against a not-actually-wedged meta layer can split-brain the meta
group."

## Practical takeaways

- **The trap is live today.** Peer-remove a node when you retire it; a 5-peer set with 3 live
  machines is one failure from a stalled meta layer, on every version.
- **On 2.15, the recovery becomes: read `quorum_needed` and `replicas` from `/jsz` on the
  survivors → publish one `$JS.API.META.RESCUE` on the system account → elect a leader →
  `$JS.API.SERVER.REMOVE` the dead peers**, all inside 5 minutes.
- **Subscribe to `$JS.EVENT.ADVISORY.SERVER.META_RESCUE`.** A rescue applied without a matching
  incident is the signature of a mistake or a misuse.
- **Silence is not rejection** when you broadcast the request; count the replies against the servers
  you believe are alive.

## Relevance to the wiki

Answers the precondition [[disaster-recovery]] states as design-time only, and gives
[[raft-in-nats]] the concrete failure the meta group has. Because it is 2.15-only, every page states
that the recovery path does not exist on 2.14.

## Questions it answers

Q36 in part (why a cluster reports no quorum and stalls) — the configured-versus-live peer set is the
mechanism behind it.

## Pages touched

[[disaster-recovery]] · [[raft-in-nats]] · [[js-api-subjects]] · [[advisories]] · [[error-codes]]
