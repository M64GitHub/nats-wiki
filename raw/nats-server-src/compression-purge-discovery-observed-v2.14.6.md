<!-- source: run locally against nats-server v2.14.6 (`nats-server --version` -> v2.14.6) and
     nats CLI 0.4.0 · observed 2026-08-31 · configs and output verbatim below.
     The machine's LAN address is written as <host-ip> throughout; nothing else is edited. -->

# Observed on nats-server v2.14.6 — stream compression, purge, discard-new, client discovery

Three experiments, run to settle claims that the sources state differently or do not state at all.
Every command and every line of output below was run on **nats-server v2.14.6** with **nats CLI
0.4.0** on darwin/arm64, 2026-08-31. Source line references are into the v2.14.6 release tarball
(`server/`), not into a working tree.

---

## 1 · Changing `compression` on a live stream does not affect new blocks until the store restarts

**Why this was run.** ADR-35 (*JetStream Filestore Compression*) says: "The compression algorithm
can be updated after the stream has been created. Newly minted blocks will use the newly selected
compression algorithm". `learn/jetstream/policies.md` says the opposite: "the new setting waits
until the stream's store restarts, on a server restart or a leader change". The source says the
docs are right — `fs.fcfg.Compression` is written once, at store creation
(`server/stream.go:994`, inside `addStreamWithAssignment` -> `setupStore`, `stream.go:1004`), and
`fileStore.UpdateConfig` (`server/filestore.go:686`) never touches it. The three reads of
`fs.fcfg.Compression` are `filestore.go:4971`, `:7769` and `:7848`.

### Setup

```
port: 4223
http_port: 8223
jetstream {
  store_dir: "<scratch>/store"
  max_file_store: 1GB
}
```

The stream is created with `--max-bytes=100000` so that the auto-tuned block size is the floor,
`FileStoreMinBlkSize` = 32000 bytes (`filestore.go:380`; the arithmetic is
`autoTuneFileStorageBlockSize`, `stream.go:1413`, and `dynBlkSize`, `filestore.go:816`). Blocks
therefore seal after ~31 KB instead of the 8 MB a default limits stream would use, which is what
makes this experiment cheap.

```
nats stream add CMP2 --subjects='c2.>' --storage=file --retention=limits --discard=old \
  --max-bytes=100000 --max-msgs=-1 --max-msgs-per-subject=-1 --max-age=-1 --max-msg-size=-1 \
  --dupe-window=2m --replicas=1 --compression=none --no-allow-rollup --deny-delete --no-deny-purge
```

Payload: 40 x 1000 bytes of `ABCDEFGHIJ` repeated — highly compressible, so a compressed block is
unmistakable by size alone.

A compressed block is identified by its first four bytes: `63 6d 70` (`cmp`) followed by the
algorithm byte, written by `CompressionInfo.MarshalMetadata` (`filestore.go:13982`). An
uncompressed block starts with a message record header, here `0a 04 00 00`.

### Phase 1 — `compression: none`, 40 KB published

```
1.blk size=31020 magic=0a040000
2.blk size=10340 magic=0a040000
```

### Phase 2 — `nats stream edit CMP2 --compression=s2 -f`, then 40 KB more

The edit is accepted and the stream reports the new value:

```
Differences (-old +new):
- 	Compression:      s"None",
+ 	Compression:      s"S2 Compression",
Stream CMP2 was updated
                  Compression: S2 Compression
```

`nats stream info CMP2 --json` -> `config.compression = s2`.

Blocks after publishing another 40 KB — **2.blk sealed after the edit and is not compressed**:

```
1.blk size=31020 magic=0a040000
2.blk size=31020 magic=0a040000
3.blk size=20680 magic=0a040000
```

### Phase 3 — restart the server (same config, same store), then 45 KB more

Immediately after the restart, before publishing anything, nothing has changed on disk:

```
1.blk size=31020 magic=0a040000
2.blk size=31020 magic=0a040000
3.blk size=20680 magic=0a040000
```

After publishing 45 KB:

```
1.blk size=31020 magic=0a040000
2.blk size=31020 magic=0a040000
3.blk size=801   magic=636d7001
4.blk size=790   magic=636d7001
5.blk size=5170  magic=0a040000
```

### What this shows

- The `compression` value on a **live** stream is accepted, persisted and reported, but the running
  store keeps writing with the algorithm it was created with. 2.blk sealed after the edit and is
  byte-for-byte the size of an uncompressed block.
- After the store is re-created (here: a server restart), newly sealed blocks are compressed —
  4.blk, 790 bytes for the same ~31 KB of content.
- The block that was the **tail** when the store re-opened is compressed as soon as it stops being
  the tail: 3.blk went from 20680 to 801 bytes without being rewritten by a publisher. This is
  `recompressOnDiskIfNeeded` (`filestore.go:7763`) called from the new-block path
  (`filestore.go:4978`, in a goroutine — hence "asynchronously").
- Blocks sealed **before** the restart stay uncompressed: 1.blk and 2.blk are unchanged at 31020
  bytes. ADR-35 says the same ("this will not result in existing blocks being proactively
  compressed or decompressed").
- The current tail block is never compressed: 5.blk, 5170 bytes, magic `0a040000`.

`magic=636d7001` decodes as `c` `m` `p` + algorithm byte `01` = `S2Compression`
(`filestore.go:111-114`, the `iota` block).

---

## 2 · A full `DiscardNew` stream refuses publishes silently

**Why this was run.** To capture what an operator actually sees when a stream at its limit stops
accepting writes, and whether the server says anything about it.

```
nats stream add FULL --subjects='full.>' --storage=file --retention=limits --discard=new \
  --max-msgs=3 --max-bytes=-1 --max-msgs-per-subject=-1 --max-age=-1 --max-msg-size=-1 \
  --dupe-window=2m --replicas=1 --no-allow-rollup --deny-delete --no-deny-purge
```

After three messages, the fourth JetStream publish is refused. The `PubAck` reply:

```
{"error":{"code":503,"err_code":10077,"description":"maximum messages exceeded"},"stream":"FULL","seq":0}
```

Through the CLI:

```
$ nats pub -J full.a "msg6"
08:43:15 Published 4 bytes to "full.a"
nats: error: maximum messages exceeded (10077)
```

**The server log says nothing.** At the default log level the file contains no line about the
refusal; `grep -ic 'failed to store' server.log` -> `0`. The message exists only as
`RateLimitDebugf` (`server/stream.go:7063`), so it needs `-D`. The error strings are `ErrMaxMsgs`,
`ErrMaxBytes` and `ErrMaxMsgsPerSubject` (`server/store.go:48-53`), wrapped as
`JSStreamStoreFailedF` = **10077** (`jetstream_errors_generated.go:877`, `stream.go:7078`).

A core (non-JetStream) publish reports success either way, because it never waits for the `PubAck`:

```
$ nats pub full.a "msg4"
08:42:58 Published 4 bytes to "full.a"
```

### Recovering with purge

```
$ nats stream purge FULL --force --keep=1
                     Messages: 1
               First Sequence: 3 @ 2026-08-31 08:42:58
                Last Sequence: 3 @ 2026-08-31 08:42:58
```

`--keep=1` kept the **newest** message and did not reset the stream sequence: first and last are
both 3.

`nats stream purge` exposes exactly the three ADR-10 options:

```
      --subject=SUBJECT  Limits the purge to a specific subject
      --seq=SEQUENCE     Purge up to but not including a specific message
      --keep=MESSAGES    Keeps a certain number of messages after the purge
```

`seq` and `keep` together are rejected by the server (`jetstream_api.go:3726`):

```
$ nats req '$JS.API.STREAM.PURGE.FULL' '{"seq":10,"keep":1}'
{"type":"io.nats.jetstream.api.v1.stream_purge_response","error":{"code":400,"err_code":10003,"description":"bad request"},"purged":0}
```

Both the discard policy and the limit can be changed on a live stream:

```
$ nats stream edit FULL --discard=old -f
- 	Discard:    s"New",
+ 	Discard:    s"Old",
Stream FULL was updated

$ nats stream edit FULL --max-msgs=10 -f
Stream FULL was updated
             Maximum Messages: 10
```

Neither a KV bucket nor an Object Store bucket sets `deny_purge` in 2.14.6 — both report
`deny_purge: false` from `nats stream info --json`; KV sets `deny_delete: true` instead. `deny_purge`
is a stream config field the creator chooses, not something the server applies to KV or OBJ.

---

## 3 · What a client is told about the other nodes (`connect_urls`)

**Why this was run.** ADR-40's *Servers discovery* section is two paragraphs plus a `**TODO**: Add
more in-depth explanation how topology discovery works`, so there is no public statement of what a
server actually advertises. The `INFO` line was read straight off the client port with `nc`.

### A standalone server advertises nothing

```
$ (printf ''; sleep 0.4) | nc 127.0.0.1 4223   # INFO ...
connect_urls: null
```

### A 2-node cluster, defaults

`n1` on 4231 and `n2` on 4232, `cluster { name: ADV, listen: 127.0.0.1:623x, routes: [...] }`,
client `port` bound to the default `0.0.0.0`. `n1`'s `INFO`:

```
{
 "server_name": "n1",
 "host": "0.0.0.0",
 "port": 4231,
 "connect_urls": [
  "<host-ip>:4231",
  "<host-ip>:4232"
 ],
 "cluster": "ADV"
}
```

The advertised URLs are the host's **routable** address, not `0.0.0.0` and not `127.0.0.1`, and the
list includes the server's own client URL as well as its peer's.

### `cluster { no_advertise: true }` on one node of three

`m1`, `m2`, `m3` on 4231/4232/4233, `no_advertise: true` on `m1` only:

```
m1: None
m2: ['<host-ip>:4232', '<host-ip>:4233']
m3: ['<host-ip>:4233', '<host-ip>:4232']
```

`m1` tells its clients nothing, and — the part that is not obvious — **`m1` disappears from the
lists its peers advertise too**, because `no_advertise` stops this server sending its client URLs
over the route (`route.go:2764`) as well as suppressing its own client `INFO` list
(`server.go:4596`).

In the 2-node version of the same test, `no_advertise` on `n1` left **both** nodes with
`connect_urls: null`: `n2` had learned no peer URL, and a node that has learned none omits the
field entirely rather than advertising only itself.

### `client_advertise` on one node of three

`client_advertise: "nats.example.internal:4222"` on `m1`, no `no_advertise` anywhere:

```
m1: ['nats.example.internal:4222', '<host-ip>:4232', '<host-ip>:4233']
m2: ['<host-ip>:4232', 'nats.example.internal:4222', '<host-ip>:4233']
m3: ['<host-ip>:4233', '<host-ip>:4232', 'nats.example.internal:4222']
```

The override replaces that node's URL **everywhere in the cluster**, not just in its own `INFO`.
The value is advertised as written: the server does not resolve or verify it.
