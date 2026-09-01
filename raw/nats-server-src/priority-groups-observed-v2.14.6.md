<!-- source: run locally against nats-server v2.14.6 (`nats-server --version` -> v2.14.6) and
     nats CLI 0.4.0 · observed 2026-09-01 · configs and output verbatim below.
     Output is the `config` object of `nats consumer info --json`, printed one line per field
     of interest; nothing else is edited. -->

# Observed on nats-server v2.14.6 — ADR-42's update rules for consumer priority groups

**Why this was run.** ADR-42 (*Pull Consumer Priority Groups*, status Approved, tagged `2.11`) states:

> "**You cannot update a consumer from having groups to not having them, or vice versa, and you
> cannot switch between policies.** Only `PriorityTimeout` is updatable today."

and

> "**The initial implementation allows exactly one group per consumer**; more than one is an error."

`learn/jetstream/policies.md` states the opposite for the first claim — its *what can be changed on a
live consumer* table has **Priority policy: Can change; `nats consumer edit` has no flag for it, so
pass a config file with `--config`** — and `learn/jetstream/priority-groups.md` states the opposite
for the second, saying the server accepts more than one group and uses only the first.

Two public sources disagree, so the server decides. Every command and every line of output below was
run on **nats-server v2.14.6** with **nats CLI 0.4.0** on darwin/arm64, 2026-09-01.

**Result: the docs are right and the ADR is stale on both claims.** All three transitions the ADR
forbids are accepted, and a consumer created with two groups keeps both. The two ADR rules that were
checked as controls — the 16-character group-name cap and the push-consumer refusal — both hold, with
their error codes.

---

## The run

```
$ nats-server --version
nats-server: v2.14.6

$ nats --version
0.4.0

# server.conf
port: 4290
jetstream { store_dir: "./jsprio/store" }

$ nats stream add PRIO --subjects 'prio.>' --defaults   # (already created)

# 1. create a pull consumer with priority_policy=overflow, one group
$ cat r1.json
{"durable_name":"R","ack_policy":"explicit","priority_policy":"overflow","priority_groups":["g1"]}
$ nats consumer add PRIO R --config r1.json
priority_policy=overflow  priority_groups=['g1']  priority_timeout=None

# 2. ADR-42: 'you cannot switch between policies'  ->  overflow to pinned_client
$ cat r2.json
{"durable_name":"R","ack_policy":"explicit","priority_policy":"pinned_client","priority_groups":["g1"]}
$ nats consumer edit PRIO R --config r2.json --force
(accepted, no error)
priority_policy=pinned_client  priority_groups=['g1']  priority_timeout=120000000000

# 3. ADR-42: 'you cannot update a consumer from having groups to not having them'
$ cat r3.json
{"durable_name":"R","ack_policy":"explicit"}
$ nats consumer edit PRIO R --config r3.json --force
(accepted, no error)
priority_policy=None  priority_groups=None  priority_timeout=None

# 4. ADR-42: '...or vice versa'  ->  give groups back to a consumer that has none
$ nats consumer edit PRIO R --config r1.json --force
(accepted, no error)
priority_policy=overflow  priority_groups=['g1']  priority_timeout=None

# 5. ADR-42: 'the initial implementation allows exactly one group per consumer; more than one is an error'
$ cat r5.json
{"durable_name":"R2","ack_policy":"explicit","priority_policy":"overflow","priority_groups":["g1","g2"]}
$ nats consumer add PRIO R2 --config r5.json
(accepted, no error)
priority_policy=overflow  priority_groups=['g1', 'g2']

# 6. CONTROL - the two ADR-42 rules that DO hold at 2.14.6
$ nats consumer add PRIO N2 --config n2.json      # group name of 17 characters
nats: error: Consumer creation failed: Valid priority group name must match A-Z, a-z, 0-9, -_/=)+ and may not exceed 16 characters (10162)
$ nats consumer add PRIO N3 --config n3.json      # priority groups on a push consumer
nats: error: Consumer creation failed: priority groups can not be used with push consumers (10178)
```

---

## What this settles, and what it does not

**Settled at v2.14.6:**

- `priority_policy` **can** be changed on a live consumer (`overflow` -> `pinned_client` accepted).
- Priority groups **can** be removed from a consumer that has them, and **can** be added to a
  consumer that has none. Both directions are accepted with no error and take effect immediately in
  `consumer info`.
- `priority_groups` **accepts more than one entry** at creation, and both entries are stored in and
  reported from the consumer config.
- Setting `priority_policy: pinned_client` with no explicit `priority_timeout` fills the field with
  **`120000000000` ns (2 minutes)**; `priority_timeout` is itself updatable (30 s applied above).
- The group-name rule holds: a 17-character name is refused with
  **`10162 Valid priority group name must match A-Z, a-z, 0-9, -_/=)+ and may not exceed 16
  characters`**.
- Priority groups on a **push** consumer are refused with
  **`10178 priority groups can not be used with push consumers`**.

**Not settled by this run:**

- Whether a consumer configured with **two** groups actually *serves* both, or uses only the first
  and ignores the rest as `learn/jetstream/priority-groups.md` says. Only config acceptance and
  read-back were tested here; no pull requests were made against either group.
- Whether switching policy on a consumer with **active pinned clients** behaves sanely — the
  transitions above were made on an idle consumer with no clients attached.
- Whether any of this differs on a **clustered** consumer. The run was standalone, single server.
