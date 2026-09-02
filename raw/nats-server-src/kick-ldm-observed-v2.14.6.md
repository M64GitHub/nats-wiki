<!-- source: nats-server v2.14.6 binary, nats CLI 0.4.0, macOS, 2026-09-01 · run against the three-node cluster of jetstream-cluster-observed-v2.14.6.md -->
# nats-server v2.14.6 — the per-client KICK and LDM system requests, observed

The behavioural half of `kick-ldm-and-mqtt-session-v2.14.6.md`, for question-bank **Q40**
(`raw/gh-discussions/gh-6892.md`). Cluster `east` (n1–n3) from `jetstream-cluster-observed-v2.14.6.md`,
with the `$SYS` user `sys`. The victim is `nats sub kick.test` connected to n1; it is found on the
servers through `/connz?subs=1` by its `subscriptions_list`. Server ids are shortened to `<n1 id>`.

## 1 · LDM: the server sends the client an INFO and nothing else

```
$ nats --server nats://sys:sys@127.0.0.1:4291 req '$SYS.REQ.SERVER.<n1 id>.LDM' '{"cid":54}' --timeout 3s
22:10:08 Received with rtt 196.833µs
{"server":{"name":"n1","host":"127.0.0.1","id":"<n1 id>","cluster":"east","ver":"2.14.6",
 "feature_flags":{"js_ack_fc_v2":false,"js_raft_delete_range":false},"jetstream":true,"flags":7,
 "seq":289,"time":"2026-09-01T20:10:08.827528Z"}}
```

Two seconds later the victim was still cid 54 on n1 and had printed nothing. `LDMClientByID`
(`server.go:4768–4790`) enqueues a client INFO with `ldm: true`; whether a client leaves is the
client library's decision, and nats CLI 0.4.0 (nats.go) did not. A previous attempt on cid 50 behaved
the same.

## 2 · KICK: the client is disconnected and reconnects elsewhere

```
$ nats --server nats://sys:sys@127.0.0.1:4291 server request kick 54 <n1 id>
{
  "server": { "name": "n1", …, "seq": 296, "time": "2026-09-01T20:10:10.952697Z" }
}
```

The victim printed, three seconds after subscribing:

```
22:10:07 Subscribing on kick.test
22:10:10 >>> Disconnected due to: EOF, will attempt reconnect
```

and in an earlier run of the same test reappeared on **n2** as cid 43 within 2.5 s (its INFO-learned
peer list; see `how-clients-reach-a-cluster`). `DisconnectClientByID` (`server.go:4753–4766`) closes
the connection outright.

## 3 · An unknown cid

```
$ nats server request kick 999999 <n1 id>
{
  "server": { … },
  "error": { "code": 500, "description": "no such client or leafnode id" }
}
```

## 4 · What exists, and what does not

Every request above is subscribed **by the server whose id is in the subject**
(`events.go:1499–1510`), so it is executed by that server or not at all. The per-server request
subjects at v2.14.6 (`events.go:52–75`) are `$SYS.REQ.SERVER.<id>.KICK`, `.LDM`, `.RELOAD` and the
monitoring `z` endpoints via `$SYS.REQ.SERVER.<id>.<VARZ|CONNZ|ROUTEZ|…>`; nothing addresses a client by
IP, nothing kicks every client of a server, and nothing tells *other* servers to drop a route. nats
CLI 0.4.0 exposes `nats server request kick <client> <server>`; it has no `ldm` subcommand, so the LDM
request was sent raw.

## Not tested

A client library that honours the LDM INFO (nats.go's `LameDuckModeHandler` is a callback, not a
reconnect); the requests against a server that is actually saturated, which is the situation gh#6892
describes and the one in which they are least likely to be processed.
