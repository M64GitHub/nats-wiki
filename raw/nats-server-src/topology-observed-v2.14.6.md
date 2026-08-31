<!-- source: nats-server v2.14.6 (Homebrew bottle, arm64), run locally · 2026-08-31 -->
# nats-server v2.14.6 — the topology checks, re-run on the tagged release

`raw/nats-server-src/topology-v2.14.6.md` reads the source at tag **v2.14.6** but recorded its
behavioural observations against the **v2.14.5** binary, which was what the machine had. This file
re-runs the same five checks on **v2.14.6** so the observations and the source ranges name the same
release. Nothing here supersedes the source quotes in that file; only its *Observed* section.

Both files are kept: the earlier one is what was actually run first, and this one is the confirmation.

```
$ brew upgrade nats-server
nats-server 2.14.5 -> 2.14.6
$ nats-server --version
nats-server: v2.14.6
```

**Result: all five reproduce identically**, down to the configuration file checksums `-t` prints.

---

## 1 · The docs' composed topology config does not start

`learn/topologies/putting-it-together.md`, *One server, three roles*, typed verbatim.

```
$ cat n1-east.conf
server_name: n1-east
listen: 127.0.0.1:4222

cluster {
  name: east
  listen: 127.0.0.1:6222
  routes: [
    nats://127.0.0.1:6223
  ]
}

gateway {
  name: east
  listen: 127.0.0.1:7222
  gateways: [
    { name: west, urls: ["nats://127.0.0.1:7322", "nats://127.0.0.1:7323", "nats://127.0.0.1:7324"] }
  ]
}

leafnodes {
  listen: 127.0.0.1:7422
}

jetstream {
  store_dir: "./js/n1-east"
}

$ nats-server -c n1-east.conf -t
nats-server: configuration file n1-east.conf is valid (sha256:ddbe986aa9531262de2a5a88b79818e203cd2ae564edda74fdb1c1e9dd7c4431)
  exit=0
$ nats-server -c n1-east.conf
nats-server: leaf nodes and gateways (both being defined) require a system account to also be configured
```

The sha256 is the same value the v2.14.5 run printed, so this is the identical file.

## 2 · `-t` passes a `validateOptions` failure

```
$ cat ld.conf
listen: 127.0.0.1:4222
lame_duck_duration: "30s"
lame_duck_grace_period: "60s"

$ nats-server -c ld.conf -t
nats-server: configuration file ld.conf is valid (sha256:bcaec34820d43463e9ab192bdee9482b4b1d594be80c335e5dde470f691d780c)
  exit=0
$ nats-server -c ld.conf
nats-server: lame duck grace period (1m0s) should be strictly lower than lame duck duration (30s)
```

## 3 · `gateway.port` has no default

```
$ cat gw.conf
listen: 127.0.0.1:4222
gateway {
  name: east
  gateways: [ { name: west, urls: ["nats://127.0.0.1:7322"] } ]
}

$ nats-server -c gw.conf -t
nats-server: configuration file gw.conf is valid (sha256:4d532db436b5a14eb313988ae01a8774b1b72e8fa85516634dc3e14e88d6e6f2)
  exit=0
$ nats-server -c gw.conf
nats-server: gateway "east" has no port specified (select -1 for random port)
```

## 4 · `leafnodes { }` and `cluster { name }` open no listener

```
$ cat lf.conf
listen: 127.0.0.1:4222
leafnodes { }

$ cat cl.conf
listen: 127.0.0.1:4222
cluster { name: east }
```

Each started, then every listening socket held by that pid:

```
--- lf.conf (pid 73113) ---
[73113] 2026/08/31 07:38:55.876704 [INF] Listening for client connections on 127.0.0.1:4222
listening sockets:
  nats-serv 127.0.0.1:4222
--- cl.conf (pid 73214) ---
[73214] 2026/08/31 07:38:58.978651 [INF] Listening for client connections on 127.0.0.1:4222
listening sockets:
  nats-serv 127.0.0.1:4222
```

One socket each. No 7422, no 6222.

## 5 · gh#5941 — the leafnode user's permissions

### 5a · The deny in the global `authorization` block is not applied

```
$ cat hub.conf
server_name: hub
listen: 127.0.0.1:4222
leafnodes {
  listen: 127.0.0.1:7422
  authorization { user: "leafuser", password: "test" }
}
authorization {
  users = [
    { user: default_user, permissions: { publish: ">", subscribe: ">" } }
    { user: leafuser, password: "test", permissions: { publish: { deny: ">" }, subscribe: { allow: ">" } } }
  ]
}
no_auth_user: default_user

$ cat leaf.conf
server_name: leaf
listen: 127.0.0.1:4300
leafnodes {
  remotes = [ { urls: [ "nats-leaf://leafuser:test@127.0.0.1:7422" ] } ]
}
```

```
$ nats pub cli.demo "hello from leaf node" --server nats://127.0.0.1:4300
07:39:18 Published 20 bytes to "cli.demo"

$ nats sub cli.demo --server nats://127.0.0.1:4222
07:39:17 Subscribing on cli.demo
[#1] Received on "cli.demo"
hello from leaf node
```

`publish: { deny: ">" }` on that user has no effect on the leafnode connection.

### 5b · `permissions` inside `leafnodes.authorization` is a parse error

```
$ cat hub2.conf
server_name: hub
listen: 127.0.0.1:4222
leafnodes {
  listen: 127.0.0.1:7422
  authorization {
    users = [
      { user: "leafuser", password: "test",
        permissions: { publish: { deny: ">" }, subscribe: { allow: ">" } } }
    ]
  }
}

$ nats-server -c hub2.conf
nats-server: hub2.conf:8:9: unknown field "permissions"
```

Matching `parseLeafUsers` (`opts.go:3005–3064`), which accepts `user`/`username`, `pass`/`password`,
`account` and `proxy_required`, and nothing else.

## Environment

```
$ nats-server --version
nats-server: v2.14.6
$ nats --version
0.4.0
$ sw_vers -productVersion    # Darwin 25.6.0, arm64
```
