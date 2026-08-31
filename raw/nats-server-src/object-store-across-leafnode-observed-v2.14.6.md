<!-- source: run locally against nats-server v2.14.6 (`nats-server --version` -> v2.14.6) and
     nats CLI 0.4.0 · observed 2026-08-31 · configs and output verbatim below. -->

# Observed on nats-server v2.14.6 — object-store subjects cross a leafnode where KV subjects do not

Run after reading `server/jetstream_api.go:323–324` at v2.14.6, where the leafnode JetStream deny
lists are defined:

```go
var denyAllClientJs = []string{jsAllAPI, "$KV.>", "$OBJ.>"}
var denyAllJs = []string{jscAllSubj, raftAllSubj, jsAllAPI, "$KV.>", "$OBJ.>"}
```

and the domain mapping table at `:347`, `"$OBJ.>": "$OBJ.>"`.

**`$OBJ` is not the object store's subject space.** ADR-20, `learn/object-store/under-the-hood.md`
and the running server all use **`$O.<bucket>.C.>`** and **`$O.<bucket>.M.>`** (see
`object-store-observed-v2.14.6.md` in this directory, section 1). `grep -rn '\$OBJ' raw/nats-docs/`
returns nothing — the string appears in the server and nowhere in the documentation. `$OBJ.>` is a
literal first token and does not match `$O.…`.

These four experiments test whether that matters.

### Setup — a hub and a leaf with **different** JetStream domains

`hub.conf`:

```
port: 4251
http: 8251
server_name: hub
jetstream { domain: hub, store_dir: "<scratch>/leaflab/hub" }
accounts {
  APP: { jetstream: enabled, users: [ {user: a, password: p} ] }
  SYS: { users: [ {user: sys, password: p} ] }
}
system_account: SYS
leafnodes { port: 7451 }
```

`leaf.conf`:

```
port: 4252
http: 8252
server_name: leaf
jetstream { domain: leaf, store_dir: "<scratch>/leaflab/leaf" }
accounts {
  APP: { jetstream: enabled, users: [ {user: a, password: p} ] }
  SYS: { users: [ {user: sys, password: p} ] }
}
system_account: SYS
leafnodes { remotes: [ { url: "nats://a:p@localhost:7451", account: APP } ] }
```

Both servers log the branch that matters — domains differ, non-system account, so
**`denyAllClientJs` is merged both ways**:

```
[INF] [::1]:7451 - lid:6 - Leafnode connection created for account: APP
[INF] [::1]:7451 - lid:6 - JetStream using domains: local "leaf", remote "hub"
```

The first attempt at this setup omitted `jetstream: enabled` on the `APP` account and every
JetStream call failed with `could not pick a Stream to operate on: context deadline exceeded`.
With accounts configured explicitly, a top-level `jetstream {}` block does not by itself give an
account JetStream. Recorded because it is an easy hour to lose.

## 1 · Which subjects actually cross

`nats sub '>'` on the **hub** (account APP), five publishes from the **leaf** (account APP):

```
nats -s nats://a:p@localhost:4252 pub 'plain.subject'   '…'
nats -s nats://a:p@localhost:4252 pub '$KV.TEST.key1'   '…'
nats -s nats://a:p@localhost:4252 pub '$OBJ.TEST.thing' '…'
nats -s nats://a:p@localhost:4252 pub '$O.TEST.C.abc'   '…'
nats -s nats://a:p@localhost:4252 pub '$O.TEST.M.abc'   '…'
```

What arrived on the hub:

```
[#1] Received on "plain.subject"
[#2] Received on "$O.TEST.C.abc"
[#3] Received on "$O.TEST.M.abc"
```

| subject | crossed? | why |
|---|---|---|
| `plain.subject` | **yes** | ordinary account traffic |
| `$KV.TEST.key1` | no | matches `$KV.>` in `denyAllClientJs` |
| `$OBJ.TEST.thing` | no | matches `$OBJ.>` in `denyAllClientJs` |
| **`$O.TEST.C.abc`** | **yes** | `$OBJ.>` does not match `$O.…` |
| **`$O.TEST.M.abc`** | **yes** | same |

## 2 · The consequence: a same-named object bucket on both sides is silently mirrored

An `OBJ_SHARED` bucket created on each server, in the `APP` account on both, then **one put on the
leaf only**:

```
nats -s nats://a:p@localhost:4251 object add SHARED     # hub
nats -s nats://a:p@localhost:4252 object add SHARED     # leaf
nats -s nats://a:p@localhost:4252 object put SHARED payload.bin --no-progress   # 600 KiB, LEAF only
```

`nats stream info OBJ_SHARED` on each server:

| | before | after the leaf-side put |
|---|---|---|
| leaf | 0 msgs / 0 bytes | 6 msgs / 615,040 bytes |
| **hub** | 0 msgs / 0 bytes | **6 msgs / 615,040 bytes** |

And the hub lists an object nobody put there:

```
nats -s nats://a:p@localhost:4251 object ls SHARED

│ payload.bin │ 600 KiB │ 2026-08-31 23:39:15 │
```

```
nats -s nats://a:p@localhost:4251 stream subjects OBJ_SHARED

│ $O.SHARED.M.cGF5bG9hZC5iaW4=       │ 1     │
│ $O.SHARED.C.kVUgvDAOdPXVz64dqECKBD │ 5     │
```

The hub's stream captured the chunk messages **and** the metadata message, so the object is not
merely leaked bytes — it is a complete, gettable object on a server that was never asked to store it.

## 3 · Control — the same test with a KV bucket

Same servers, same account, same procedure:

```
nats -s nats://a:p@localhost:4251 kv add CONF        # hub
nats -s nats://a:p@localhost:4252 kv add CONF        # leaf
nats -s nats://a:p@localhost:4252 kv put CONF k1 "value-from-leaf"    # LEAF only
```

| | after the leaf-side put |
|---|---|
| leaf `KV_CONF` | 1 msg |
| **hub `KV_CONF`** | **0 msgs** |

```
nats -s nats://a:p@localhost:4251 kv get CONF k1
nats: error: nats: key not found
```

So the deny list is working — for KV.

## 4 · Control — the account really does span the leafnode

```
nats -s nats://a:p@localhost:4251 sub 'demo.>'      # hub
nats -s nats://a:p@localhost:4252 pub demo.x hello  # leaf
[#1] Received on "demo.x"
```

The leafnode is up and the account is shared, so the KV result in experiment 3 is the deny list
acting, not a broken link.

## What this does and does not establish

**Established, reproducibly:** at v2.14.6, with two JetStream domains joined by a leafnode in a
non-system account, `$KV.>` traffic is denied across the link and `$O.<bucket>.>` traffic is not,
because the deny list names `$OBJ.>`. Two same-named object buckets in the same account on either
side of such a link converge.

**Not established:** whether this is a defect or an intended asymmetry. No public issue, discussion
or ADR read so far mentions `$OBJ` versus `$O`, and the docs never state what happens to either store
across a domain boundary. The source comment at `jetstream_api.go:330–337` explains why `$KV` and
`$OBJ` are independent subject spaces but does not say which prefix the object store uses.

**Not tested:** the same-domain case, the system-account (`denyAllJs`) case, gateways, and whether a
client library other than the `nats` CLI behaves differently. All four use the same subjects, so the
result should not depend on the client, but that is reasoning rather than observation.
