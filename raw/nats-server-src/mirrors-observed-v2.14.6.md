<!-- source: run locally against nats-server v2.14.6 (`nats-server --version` -> v2.14.6) and
     nats CLI 0.4.0 · observed 2026-09-02 · configs, commands and output verbatim below; store paths
     shortened to <lab> (tools/lab/cluster.sh's directory) and <scratch>. The python client the runs
     use is `mirrorlab.py` in this directory. -->

# Observed on nats-server v2.14.6 — mirrors: file versus memory storage, catch-up under a reader, and a mirrored object bucket across two domains

Three runs for step 2 of `inbox/plan-the-runnable-scouts-2026-09-02.md` (question-bank rows 76, 91,
105), made after reading `server/stream.go` and `server/filestore.go` at v2.14.6 (`mirror-v2.14.6.md`
in this directory) and the three threads (`raw/gh-discussions/gh-8417.md`, `gh-8444.md`,
`raw/gh-issues/issue-5106.md`).

- **Run A** — the same KV bucket mirrored on file and on memory storage, timed four ways.
  `bash tools/lab/cluster.sh up 1` (one server, `127.0.0.1:4291`, monitoring `8291`).
- **Run B** — the mirror's initial catch-up alone and with readers scanning it, in three forms; the
  third form is the one that answers the question.
- **Run C** — an object-store bucket on a leaf mirrored into a hub with a different JetStream domain:
  the hub/leaf pair of `object-store-across-leafnode-observed-v2.14.6.md`, started by hand from its
  two configs (hub `4251`, leaf `4252`, leafnode port `7451`, account `APP`, user `a`/`p`).

Every number below is one laptop (Apple silicon, loopback, both sides of every mirror on the same
host or the same machine). They are evidence of a **mechanism** and of a **ratio**, never of a limit.

## Run A · a KV mirror on file storage and on memory storage

### A1 · The source bucket, and a flood the server dropped

`nats kv add DNS --history 1 --storage file` on the lab server, then the python client publishing
400,000 keys once and 2,000,000 overwrites on a hot 100,000 of them (100-byte values). The first
attempt published without waiting for any acknowledgement, and the server **dropped most of it**:
the stream ended with 337,733 messages and a last sequence of 616,769 after 2,400,000 publishes.


```
$ python3 mirrorlab.py fill 4291 DNS 400000 100000 2000000 100
fill: 400000 keys written once in 0.25s
fill: 2000000 overwrites on the hot 100000 keys in 1.31s (PONG received, so the server has processed them)

$ nats stream info KV_DNS
Information for Stream KV_DNS created 2026-09-02 22:08:48

                     Subjects: $KV.DNS.>
                     Replicas: 1
                      Storage: File

Options:

                    Retention: Limits
              Acknowledgments: true
               Discard Policy: New
             Duplicate Window: 2m0s
                   Direct Get: true
  Allows Atomic Batch Publish: false
    Allows Fast Batch Publish: false
              Allows Counters: false
            Allows Msg Delete: false
       Allows Per-Message TTL: false
                 Allows Purge: true
             Allows Schedules: false
               Allows Rollups: true

Limits:

             Maximum Messages: unlimited
          Maximum Per Subject: 1
                Maximum Bytes: unlimited
                  Maximum Age: unlimited
         Maximum Message Size: unlimited
            Maximum Consumers: unlimited

State:

                 Host Version: 2.14.6
           Required API Level: 0 hosted at level 4
                     Messages: 337,733
                        Bytes: 47 MiB
               First Sequence: 1 @ 2026-09-02 22:08:48
                Last Sequence: 616,769 @ 2026-09-02 22:08:50
             Deleted Messages: 279,036
             Active Consumers: 0
           Number of Subjects: 337,733
```

The server's log has one line for it:

```
[26305] 2026/09/02 22:08:48.642796 [WRN] Dropping messages due to excessive stream ingest rate on '$G' > 'KV_DNS': IPQ len limit reached
```

That is the stream's inbound queue at its default cap — `streamDefaultMaxQueueMsgs = 100_000` and
`streamDefaultMaxQueueBytes = 128 * 1024 * 1024` (`stream.go:441–442`), applied to the stream's `msgs`
ipQueue at `stream.go:924–926`. A core-NATS publish into a stream subject has no back-pressure, so a
publisher that never waits for a `PubAck` can outrun the store and lose data with one `[WRN]` line as
the only evidence. Not the topic of this run, but recorded because it cost one attempt.

The second attempt kept at most 4,000 publishes un-acked (every `PubAck` counted; none returned an
error). It ran **on top of** the first attempt's messages, which is why the first sequence is
740,055 rather than 1: every key of the first fill was overwritten, and the blocks that held only
dead records were removed whole.


```
$ python3 mirrorlab.py fill 4291 DNS 400000 100000 2000000 100   # now with a 4000-message ack window
fill: 400000 keys written once in 1.99s (200548 msg/s, every PubAck received, 0 errors)
fill: 2000000 overwrites on the hot 100000 keys in 9.42s (212331 msg/s, every PubAck received, 0 errors)

$ nats stream info KV_DNS
State:

                 Host Version: 2.14.6
           Required API Level: 0 hosted at level 4
                     Messages: 400,000
                        Bytes: 56 MiB
               First Sequence: 740,055 @ 2026-09-02 22:09:41
                Last Sequence: 3,140,054 @ 2026-09-02 22:09:52
             Deleted Messages: 2,000,000
             Active Consumers: 0
           Number of Subjects: 400,000
```

So the source is **400,000 live messages over 2,400,000 sequences — 2,000,000 interior deletes,
83 % of the sequence space**, the ratio gh#8417 reported (9.9 M deleted of 11.9 M).

### A2 · The two mirrors, and their initial sync, timed

`nats kv add DNS_FILE --mirror DNS --storage file`, then the same with `--storage memory`, each with
a poller reading `$JS.API.STREAM.INFO` every 250 ms from before the `kv add` until `mirror.lag`
reached 0. Then the mirrors' configs and states, the internal consumers as `/jsz` shows them, and
the on-disk footprint of the source against the file mirror.


```
$ python3 mirrorlab.py lagwait 4291 KV_DNS_FILE &   (polls $JS.API.STREAM.INFO.KV_DNS_FILE every 250 ms, prints once a second)
$ nats kv add DNS_FILE --mirror DNS --storage file
Information for Key-Value Store Bucket DNS_FILE created 2026-09-02 22:10:26

Configuration:
[   0.51s] msgs=0 last_seq=0 lag=0 active=-1
[   1.53s] msgs=400000 last_seq=3140054 lag=0 active=467468000
lagwait: lag 0 at 1.53s (msgs=400000 last_seq=3140054)
wall time from kv add to lag 0: 1.24s

$ python3 mirrorlab.py lagwait 4291 KV_DNS_MEM &   (polls $JS.API.STREAM.INFO.KV_DNS_MEM every 250 ms, prints once a second)
$ nats kv add DNS_MEM --mirror DNS --storage memory
Information for Key-Value Store Bucket DNS_MEM created 2026-09-02 22:10:28

Configuration:
[   0.51s] msgs=5650 last_seq=745704 lag=394347 active=15000
lagwait: lag 0 at 1.02s (msgs=400000 last_seq=3140054)
wall time from kv add to lag 0: 0.74s

$ nats stream info KV_DNS_FILE --json | jq '{config: (.config | {name, subjects, storage, max_msgs_per_subject, allow_direct, mirror_direct, mirror}), state, mirror}'
{
  "config": {
    "name": "KV_DNS_FILE",
    "subjects": null,
    "storage": "file",
    "max_msgs_per_subject": 1,
    "allow_direct": true,
    "mirror_direct": true,
    "mirror": {
      "name": "KV_DNS"
    }
  },
  "state": {
    "messages": 400000,
    "bytes": 58400000,
    "first_seq": 740055,
    "first_ts": "2026-09-02T20:09:41.322529Z",
    "last_seq": 3140054,
    "last_ts": "2026-09-02T20:09:52.735401Z",
    "num_deleted": 2000000,
    "num_subjects": 400000,
    "consumer_count": 0
  },
  "mirror": {
    "name": "KV_DNS",
    "lag": 0,
    "active": 643535000
  }
}
$ nats stream info KV_DNS_MEM --json | jq '{state, mirror}'
{
  "state": {
    "messages": 400000,
    "bytes": 52800000,
    "first_seq": 740055,
    "first_ts": "2026-09-02T20:09:41.322529Z",
    "last_seq": 3140054,
    "last_ts": "2026-09-02T20:09:52.735401Z",
    "num_deleted": 2000000,
    "num_subjects": 400000,
    "consumer_count": 0
  },
  "mirror": {
    "name": "KV_DNS",
    "lag": 0,
    "active": 386955000
  }
}
$ nats consumer ls KV_DNS
No Consumers defined
$ curl -s 'http://127.0.0.1:8291/jsz?acc=$G&streams=true&consumers=true&direct-consumers=true&config=true' | jq '.account_details[].stream_detail[] | select(.name=="KV_DNS") | {name, consumer_count: .state.consumer_count, direct: [.direct_consumer_detail[]? | {name, filter: .config.filter_subject, deliver_policy: .config.deliver_policy, ack_policy: .config.ack_policy, ack_wait: .config.ack_wait, max_deliver: .config.max_deliver, idle_heartbeat: .config.idle_heartbeat, flow_control: .config.flow_control, direct: .config.direct, sourcing: .config.sourcing, inactive_threshold: .config.inactive_threshold, metadata: .config.metadata, num_pending, delivered}]}'
{
  "name": "KV_DNS",
  "consumer_count": 0,
  "direct": [
    {
      "name": "JS_MIRROR_OQyMJ0fQ-7i1hqwDz",
      "filter": null,
      "deliver_policy": "all",
      "ack_policy": "none",
      "ack_wait": 79200000000000,
      "max_deliver": 1,
      "idle_heartbeat": 1000000000,
      "flow_control": true,
      "direct": true,
      "sourcing": true,
      "inactive_threshold": 10000000000,
      "metadata": {
        "_nats.mirror.acc": "$G",
        "_nats.mirror.stream": "KV_DNS_FILE",
        "_nats.req.level": "0"
      },
      "num_pending": 0,
      "delivered": {
        "consumer_seq": 400000,
        "stream_seq": 3140054,
        "last_active": "2026-09-02T20:10:27.325123Z"
      }
    },
    {
      "name": "JS_MIRROR_HNs8w7PP-7H9l9Nd5",
      "filter": null,
      "deliver_policy": "all",
      "ack_policy": "none",
      "ack_wait": 79200000000000,
      "max_deliver": 1,
      "idle_heartbeat": 1000000000,
      "flow_control": true,
      "direct": true,
      "sourcing": true,
      "inactive_threshold": 10000000000,
      "metadata": {
        "_nats.mirror.acc": "$G",
        "_nats.mirror.stream": "KV_DNS_MEM",
        "_nats.req.level": "0"
      },
      "num_pending": 0,
      "delivered": {
        "consumer_seq": 400000,
        "stream_seq": 3140054,
        "last_active": "2026-09-02T20:10:28.595841Z"
      }
    }
  ]
}
$ for s in KV_DNS KV_DNS_FILE; do ls <store>/$G/streams/$s/msgs | wc -l; du -sk <store>/$G/streams/$s/msgs; done
KV_DNS: blk+index files: 51
KV_DNS: du -sk msgs/: 128220
KV_DNS_FILE: blk+index files: 29
KV_DNS_FILE: du -sk msgs/: 58536
$ grep -v Healthcheck n1.log | tail -5
[26305] 2026/09/02 22:06:03.474672 [INF] -------------------------------------------
[26305] 2026/09/02 22:06:03.474883 [INF] Took 432µs to start JetStream
[26305] 2026/09/02 22:06:03.474901 [INF] Listening for client connections on 127.0.0.1:4291
[26305] 2026/09/02 22:06:03.474906 [INF] Server is ready
[26305] 2026/09/02 22:08:48.642796 [WRN] Dropping messages due to excessive stream ingest rate on '$G' > 'KV_DNS': IPQ len limit reached
```

What this settles:

- **The initial sync is not slow on file storage here.** 400,000 live messages over a 2.4 M sequence
  span in **1.24 s** on file and **0.74 s** on memory — about 320,000 live messages (1.9 M sequences)
  per second on file. gh#8417's 412 s for 855,017 messages over a leafnode did not reproduce on one
  host, and the thread never explained it either.
- **The consumer the server creates on the upstream** is named `JS_MIRROR_<id>`, has **no filter**
  (`filter: null`), `deliver_policy: all`, `ack_policy: none`, `ack_wait` 22 h, `max_deliver: 1`,
  a 1 s heartbeat, flow control, `direct: true`, `sourcing: true`, `inactive_threshold` 10 s, and
  metadata `_nats.mirror.stream` / `_nats.mirror.acc` naming the mirror that owns it. `nats consumer
  ls KV_DNS` prints `No Consumers defined` and `consumer_count` is 0 — only
  `/jsz?…&direct-consumers=true` shows them. The names are **not** the `mirror-<id>` of ADR-59
  §"Internal consumers" (see `mirror-v2.14.6.md` for the code at three tags).
- **The mirror only ever received the 400,000 live messages** — `delivered.consumer_seq` is 400,000
  against `stream_seq` 3,140,054 — and filled the 2,000,000 holes itself (`skipMsgs`), which is how a
  mirror keeps the upstream's sequence numbers.
- **A file mirror re-packs.** Same 400,000 messages: the source holds them in 51 files and
  128,220 KB (2.2× its reported 56 MiB); the mirror in 29 files and 58,536 KB (1.0×). gh#8417 saw
  81 % against 98 % live bytes for the same reason.

### A3 · Reading each mirror — the filter is the difference

Pull consumers with `ack none`, `deliver all`, read by the Go client (`nats bench js consume`, batch
500, 400,000 messages). One consumer per mirror carries `--filter '$KV.DNS.>'` — the filter gh#8417's
reporter passed, which matches every message — and one carries no filter. A fifth consumer with the
filter sits on the **source** stream, which has a subject.


```
### pull consumers, ack none, deliver all — with the everything-matching filter and without
$ nats -s nats://127.0.0.1:4291 consumer add KV_DNS_FILE C_FILE_FILTER --pull --filter $KV.DNS.> --deliver all --ack none --replicas 1 --defaults
Information for Consumer KV_DNS_FILE > C_FILE_FILTER created 2026-09-02 22:13:07





$ nats -s nats://127.0.0.1:4291 consumer add KV_DNS_FILE C_FILE_NOFILTER --pull --deliver all --ack none --replicas 1 --defaults
Information for Consumer KV_DNS_FILE > C_FILE_NOFILTER created 2026-09-02 22:13:07





$ nats -s nats://127.0.0.1:4291 consumer add KV_DNS_MEM C_MEM_FILTER --pull --filter $KV.DNS.> --deliver all --ack none --replicas 1 --defaults
Information for Consumer KV_DNS_MEM > C_MEM_FILTER created 2026-09-02 22:13:07





$ nats -s nats://127.0.0.1:4291 consumer add KV_DNS_MEM C_MEM_NOFILTER --pull --deliver all --ack none --replicas 1 --defaults
Information for Consumer KV_DNS_MEM > C_MEM_NOFILTER created 2026-09-02 22:13:07





$ nats -s nats://127.0.0.1:4291 consumer add KV_DNS C_SRC_FILTER --pull --filter $KV.DNS.> --deliver all --ack none --replicas 1 --defaults
Information for Consumer KV_DNS > C_SRC_FILTER created 2026-09-02 22:13:07





### read them with the Go client: nats bench js consume, batch 500, 400,000 msgs
$ nats bench js consume --stream KV_DNS_FILE --consumer C_FILE_FILTER --filter=$KV.DNS.> --acks none --msgs 400000 --no-progress
22:13:07 Starting JetStream durable consumer (callback) benchmark [acks=none, batch=500, clients=1, consumer=C_FILE_FILTER, double-acked=false, filter=$KV.DNS.>, msg-size=128 B, msgs=400,000, purge=false, sleep=0s, stream=KV_DNS_FILE]
22:13:07 [1] Starting JetStream durable consumer (callback), expecting 400,000 messages
NATS JetStream durable consumer (callback) stats: 267,866 msgs/sec ~ 33 MiB/sec

$ nats bench js consume --stream KV_DNS_FILE --consumer C_FILE_NOFILTER  --acks none --msgs 400000 --no-progress
22:13:08 Starting JetStream durable consumer (callback) benchmark [acks=none, batch=500, clients=1, consumer=C_FILE_NOFILTER, double-acked=false, msg-size=128 B, msgs=400,000, purge=false, sleep=0s, stream=KV_DNS_FILE]
22:13:08 [1] Starting JetStream durable consumer (callback), expecting 400,000 messages
NATS JetStream durable consumer (callback) stats: 1,740,462 msgs/sec ~ 212 MiB/sec

$ nats bench js consume --stream KV_DNS_MEM --consumer C_MEM_FILTER --filter=$KV.DNS.> --acks none --msgs 400000 --no-progress
22:13:09 Starting JetStream durable consumer (callback) benchmark [acks=none, batch=500, clients=1, consumer=C_MEM_FILTER, double-acked=false, filter=$KV.DNS.>, msg-size=128 B, msgs=400,000, purge=false, sleep=0s, stream=KV_DNS_MEM]
22:13:09 [1] Starting JetStream durable consumer (callback), expecting 400,000 messages
NATS JetStream durable consumer (callback) stats: 1,541,157 msgs/sec ~ 188 MiB/sec

$ nats bench js consume --stream KV_DNS_MEM --consumer C_MEM_NOFILTER  --acks none --msgs 400000 --no-progress
22:13:09 Starting JetStream durable consumer (callback) benchmark [acks=none, batch=500, clients=1, consumer=C_MEM_NOFILTER, double-acked=false, msg-size=128 B, msgs=400,000, purge=false, sleep=0s, stream=KV_DNS_MEM]
22:13:09 [1] Starting JetStream durable consumer (callback), expecting 400,000 messages
NATS JetStream durable consumer (callback) stats: 1,463,983 msgs/sec ~ 179 MiB/sec

$ nats bench js consume --stream KV_DNS --consumer C_SRC_FILTER --filter=$KV.DNS.> --acks none --msgs 400000 --no-progress
22:13:09 Starting JetStream durable consumer (callback) benchmark [acks=none, batch=500, clients=1, consumer=C_SRC_FILTER, double-acked=false, filter=$KV.DNS.>, msg-size=128 B, msgs=400,000, purge=false, sleep=0s, stream=KV_DNS]
22:13:09 [1] Starting JetStream durable consumer (callback), expecting 400,000 messages
NATS JetStream durable consumer (callback) stats: 1,563,531 msgs/sec ~ 191 MiB/sec
```

| consumer | store | filter | msg/s |
|---|---|---|---:|
| `C_FILE_FILTER` | file mirror | `$KV.DNS.>` | **267,866** |
| `C_FILE_NOFILTER` | file mirror | none | **1,740,462** |
| `C_MEM_FILTER` | memory mirror | `$KV.DNS.>` | 1,541,157 |
| `C_MEM_NOFILTER` | memory mirror | none | 1,463,983 |
| `C_SRC_FILTER` | the source | `$KV.DNS.>` | 1,563,531 |

**6.5× on the file mirror, no gap on the memory mirror, no gap on the source.** The source has
`subjects: ["$KV.DNS.>"]`, so `firstMatching`'s `subjs[0] == filter` test is true and it takes the
linear scan; the mirror has `subjects: null`, so the same filter takes the per-subject path
(`filestore.go:3093–3103`). The memory store has no such heuristic.

The thread's exact consumer — `deliver last-per-subject` (`--deliver subject` in CLI 0.4.0) with the
filter — read by the python client, then by the Go client (whose stats line was lost in the
transcript; `nats consumer info` afterwards showed both consumers fully delivered, 400,000 each):


```
### the thread's exact shape: deliver last-per-subject (--deliver subject) + the filter, read by the python client (its ceiling is ~100k msg/s)
$ nats consumer add KV_DNS_FILE C_FILE_LPS --pull --filter '$KV.DNS.>' --deliver subject --ack none --replicas 1 --defaults
Information for Consumer KV_DNS_FILE > C_FILE_LPS created 2026-09-02 22:15:06
          Filter Subject: $KV.DNS.>
          Deliver Policy: Last Per Subject
    Unprocessed Messages: 400,000

$ python3 <scratch>/mirrorlab.py consume 4291 KV_DNS_FILE C_FILE_LPS 400000
consume: 400000 msgs, 40000000 payload bytes in 1.70s = 234632 msg/s

$ nats consumer add KV_DNS_MEM C_MEM_LPS --pull --filter '$KV.DNS.>' --deliver subject --ack none --replicas 1 --defaults
Information for Consumer KV_DNS_MEM > C_MEM_LPS created 2026-09-02 22:15:08
          Filter Subject: $KV.DNS.>
          Deliver Policy: Last Per Subject
    Unprocessed Messages: 400,000

$ python3 <scratch>/mirrorlab.py consume 4291 KV_DNS_MEM C_MEM_LPS 400000
consume: 400000 msgs, 40000000 payload bytes in 0.52s = 769470 msg/s

### the same last-per-subject consumers read by the Go client
$ nats consumer add KV_DNS_FILE C_FILE_LPS2 --pull --filter '$KV.DNS.>' --deliver subject --ack none --replicas 1 --defaults
          Deliver Policy: Last Per Subject
$ nats bench js consume --stream KV_DNS_FILE --consumer C_FILE_LPS2 --filter '$KV.DNS.>' --acks none --msgs 400000 --no-progress


$ nats consumer add KV_DNS_MEM C_MEM_LPS2 --pull --filter '$KV.DNS.>' --deliver subject --ack none --replicas 1 --defaults
          Deliver Policy: Last Per Subject
$ nats bench js consume --stream KV_DNS_MEM --consumer C_MEM_LPS2 --filter '$KV.DNS.>' --acks none --msgs 400000 --no-progress
```

### A4 · The `nats` CLI on a mirror bucket — and what its listing consumer looks like

`nats kv ls` and `nats kv get` addressed to the mirror **by its own bucket name** find nothing,
because the client reads `$KV.DNS_FILE.>` and the mirror holds `$KV.DNS.>` — a mirror created by
`nats kv add --mirror` in the **same** domain gets no subject transform (nats.go v1.53.1
`jetstream/kv.go:695–702` and `1610–1618`; `raw/nats-go-src/kv-object-mirror-v1.53.1.md`). A
mirror hand-built with the transform `$KV.DNS.>` → `$KV.DNS_TR.>` is readable by name — and its
`nats kv ls` takes **3.6×** as long as the source's, because the listing consumer is a
`last_per_subject` push consumer filtered on the bucket's whole key space: on a file mirror, that is
the per-subject path again.


```
### the CLI addressing the mirror by its own bucket name
$ nats kv ls DNS_FILE
No keys found in bucket

$ nats -s nats://127.0.0.1:4291 kv get DNS_FILE k0000001
nats: error: nats: key not found

$ nats kv get DNS_FILE k0000001 --trace 2>&1 | grep '>>>'
22:15:10 >>> $JS.API.STREAM.INFO.KV_DNS_FILE
22:15:10 >>> Connected to nats://127.0.0.1:4291 (127.0.0.1:4291)
22:15:10 >>> $JS.API.DIRECT.GET.KV_DNS_FILE.$KV.DNS_FILE.k0000001

$ nats kv get DNS k0000001 --trace 2>&1 | grep '>>>'
22:15:10 >>> $JS.API.STREAM.INFO.KV_DNS
22:15:10 >>> Connected to nats://127.0.0.1:4291 (127.0.0.1:4291)
22:15:10 >>> $JS.API.DIRECT.GET.KV_DNS.$KV.DNS.k0000001

### a hand-built mirror with the transform the client does not add
$ cat kv-dns-tr.json
{"name":"KV_DNS_TR","retention":"limits","max_consumers":-1,"max_msgs":-1,"max_bytes":-1,"max_age":0,"max_msgs_per_subject":1,"max_msg_size":-1,"discard":"new","storage":"file","num_replicas":1,"duplicate_window":120000000000,"allow_direct":true,"mirror_direct":true,"allow_rollup_hdrs":true,"deny_delete":true,"mirror":{"name":"KV_DNS","subject_transforms":[{"src":"$KV.DNS.>","dest":"$KV.DNS_TR.>"}]}}

$ nats stream add KV_DNS_TR --config kv-dns-tr.json
Information for Stream KV_DNS_TR created 2026-09-02 22:15:11
                        Mirror: KV_DNS
  Subject Filter and Transform: $KV.DNS.> to $KV.DNS_TR.>
[   1.53s] msgs=400000 last_seq=3140054 lag=0 active=376656000
lagwait: lag 0 at 1.53s (msgs=400000 last_seq=3140054)
wall time from stream add to lag 0: 1.21s

$ nats stream info KV_DNS_TR --json | jq -c '{state: .state | {messages,first_seq,last_seq,num_deleted,num_subjects}, mirror}'
{"state":{"messages":400000,"first_seq":740055,"last_seq":3140054,"num_deleted":2000000,"num_subjects":400000},"mirror":{"name":"KV_DNS","lag":0,"active":420892000,"subject_transforms":[{"src":"$KV.DNS.>","dest":"$KV.DNS_TR.>"}]}}

$ nats stream subjects KV_DNS_TR | head -3
╭───────────────────────────────────────────────────────────╮
│            400000 Subjects in stream KV_DNS_TR            │
├─────────────────────┬───────┬─────────────────────┬───────┤

$ nats kv ls DNS_TR | wc -l
400000
  -> 1.533s wall

$ nats kv ls DNS | wc -l   (the source, for comparison)
400000
  -> 0.427s wall

$ nats -s nats://127.0.0.1:4291 kv get DNS_TR k0000001
DNS_TR > k0000001 revision: 740056 created @ 2026-09-02 22:09:41

vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv

  -> 0.026s wall

$ nats -s nats://127.0.0.1:4291 kv get DNS_TR k0399999
DNS_TR > k0399999 revision: 3105408 created @ 2026-09-02 22:09:52

vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv

  -> 0.026s wall
```

What one `nats kv ls` asks the server for (from `--trace`, on the same-domain mirror):


```
### what nats kv ls asks the server for (--trace)
22:12:08 >>> $JS.API.STREAM.INFO.KV_DNS_FILE
22:12:08 >>> $JS.API.CONSUMER.CREATE.KV_DNS_FILE.7GLNqog8.$KV.DNS_FILE.>
{"stream_name":"KV_DNS_FILE","config":{"deliver_policy":"last_per_subject","ack_policy":"none","ack_wait":79200000000000,"max_deliver":1,"filter_subject":"$KV.DNS_FILE.\u003e","replay_policy":"instant","flow_control":true,"idle_heartbeat":5000000000,"headers_only":true,"deliver_subject":"_INBOX.6Z7L301GZK0iMLsGSRm0df","num_replicas":1,"mem_storage":true}}
22:12:08 <<< $JS.API.CONSUMER.CREATE.KV_DNS_FILE.7GLNqog8.$KV.DNS_FILE.>: {"type":"io.nats.jetstream.api.v1.consumer_create_response","stream_name":"KV_DNS_FILE","name":"7GLNqog8","created":"2026-09-02T20:12:08.613586Z","config":{"name":"7GLNqog8","deliver_policy":"last_per_subject","ack_policy":"none","ack_wait":79200000000000,"max_deliver":1,"filter_subject":"$KV.DNS_FILE.\u003e","replay_policy":"instant","flow_control":true,"headers_only":true,"deliver_subject":"_INBOX.6Z7L301GZK0iMLsGSRm0df","idle_heartbeat":5000000000,"inactive_threshold":5000000000,"num_replicas":1,"mem_storage":true,"metadata":{"_nats.level":"4","_nats.req.level":"0","_nats.ver":"2.14.6"}},"delivered":{"consumer_seq":0,"stream_seq":740054},"ack_floor":{"consumer_seq":0,"stream_seq":740054},"num_ack_pending":0,"num_redelivered":0,"num_waiting":0,"num_pending":0,"push_bound":true,"ts":"2026-09-02T20:12:08.613625Z"}
22:12:08 >>> $JS.API.CONSUMER.DELETE.KV_DNS_FILE.7GLNqog8
```

## Run B · catch-up alone, and with readers scanning the mirror

The question of gh#8444: does a consumer cold-scanning the mirror slow the mirror's own catch-up?
Three forms were run; the first two are kept because they show what does **not** produce the effect.

### B1 · 400k/2.4M source, one python reader that never actually read (kept for the baselines)

The python `scan` command was meant to create an ephemeral `DeliverAll` / `AckNone` consumer and
pull to the tail in a loop. Its transcripts were empty: it created consumers but its pull requests
never got a response (found afterwards — it read 0 messages in 10 s against a full mirror). So this
form measures the mirror alone, plus the churn of one client creating and deleting a consumer, and
nothing else. Five baselines per store.


```
### run B — catch-up of the same mirror alone, and with a cold-scanning reader; three repeats per condition
## KV_DNS_FILE (file)
  DNS_FILE alone1: kv add -> lag 0 in 1.20s   (lagwait: lag 0 at 1.47s (msgs=400000 last_seq=3140054))
  DNS_FILE alone2: kv add -> lag 0 in 1.18s   (lagwait: lag 0 at 1.46s (msgs=400000 last_seq=3140054))
  DNS_FILE alone3: kv add -> lag 0 in 1.05s   (lagwait: lag 0 at 1.34s (msgs=400000 last_seq=3140054))
  DNS_FILE scan1: kv add -> lag 0 in 1.43s   (lagwait: lag 0 at 1.74s (msgs=400000 last_seq=3140054))
    scanner rounds during the run:
  DNS_FILE scan2: kv add -> lag 0 in 1.47s   (lagwait: lag 0 at 1.75s (msgs=400000 last_seq=3140054))
    scanner rounds during the run:
  DNS_FILE scan3: kv add -> lag 0 in 1.37s   (lagwait: lag 0 at 1.65s (msgs=400000 last_seq=3140054))
    scanner rounds during the run:
  DNS_FILE alone4: kv add -> lag 0 in 1.16s   (lagwait: lag 0 at 1.46s (msgs=400000 last_seq=3140054))
  DNS_FILE alone5: kv add -> lag 0 in 1.19s   (lagwait: lag 0 at 1.46s (msgs=400000 last_seq=3140054))
## KV_DNS_MEM (memory)
  DNS_MEM alone1: kv add -> lag 0 in 0.56s   (lagwait: lag 0 at 0.83s (msgs=400000 last_seq=3140054))
  DNS_MEM alone2: kv add -> lag 0 in 0.66s   (lagwait: lag 0 at 0.93s (msgs=400000 last_seq=3140054))
  DNS_MEM alone3: kv add -> lag 0 in 0.55s   (lagwait: lag 0 at 0.83s (msgs=400000 last_seq=3140054))
  DNS_MEM scan1: kv add -> lag 0 in 0.66s   (lagwait: lag 0 at 0.94s (msgs=400000 last_seq=3140054))
    scanner rounds during the run:
  DNS_MEM scan2: kv add -> lag 0 in 0.65s   (lagwait: lag 0 at 0.93s (msgs=400000 last_seq=3140054))
    scanner rounds during the run:
  DNS_MEM scan3: kv add -> lag 0 in 0.67s   (lagwait: lag 0 at 0.94s (msgs=400000 last_seq=3140054))
    scanner rounds during the run:
  DNS_MEM alone4: kv add -> lag 0 in 0.56s   (lagwait: lag 0 at 0.83s (msgs=400000 last_seq=3140054))
  DNS_MEM alone5: kv add -> lag 0 in 0.55s   (lagwait: lag 0 at 0.84s (msgs=400000 last_seq=3140054))

$ grep -v Healthcheck n1.log | tail -3
[26305] 2026/09/02 22:06:03.474901 [INF] Listening for client connections on 127.0.0.1:4291
[26305] 2026/09/02 22:06:03.474906 [INF] Server is ready
[26305] 2026/09/02 22:08:48.642796 [WRN] Dropping messages due to excessive stream ingest rate on '$G' > 'KV_DNS': IPQ len limit reached
```

### B2 · the gh#8444 shape — 1,000,000 keys, 300,000 hot, 3,000,000 overwrites — on a fresh server

`bash tools/lab/cluster.sh down --purge; up 1`, then the fill with the ack window. Source:
**1,000,000 live messages, 4,000,000 sequences, 3,000,000 interior deletes (75 %)** — the thread's
"span ≈ 4 000 000, holes ≈ 3 000 000". The readers were three copies of the same python scanner, so
again they read nothing; the baselines and the row-76 read at this scale are the useful part.


```
### a fresh single server, and the gh#8444 shape: 1,000,000 keys, a hot 300,000, 3,000,000 overwrites
binary: nats-server: v2.14.6 (/opt/homebrew/bin/nats-server)
healthy: standalone n1, /healthz ok
$ nats kv add DNS --history 1 --storage file
$ python3 mirrorlab.py fill 4291 DNS 1000000 300000 3000000 100
fill: 1000000 keys written once in 5.20s (192491 msg/s, every PubAck received, 0 errors)
fill: 3000000 overwrites on the hot 300000 keys in 13.75s (218142 msg/s, every PubAck received, 0 errors)
$ nats stream info KV_DNS --json | jq -c .state
{"messages":1000000,"bytes":146000000,"first_seq":1,"first_ts":"2026-09-02T20:30:00.422265Z","last_seq":4000000,"last_ts":"2026-09-02T20:30:19.369319Z","num_deleted":3000000,"num_subjects":1000000,"consumer_count":0}

## KV_DNS_FILE (file): alone x3, then with three cold-scanning readers x3, then alone x2
  DNS_FILE alone1: kv add -> lag 0 in 2.52s   (lagwait: lag 0 at 2.81s (msgs=1000000 last_seq=4000000))
  DNS_FILE alone2: kv add -> lag 0 in 2.52s   (lagwait: lag 0 at 2.81s (msgs=1000000 last_seq=4000000))
  DNS_FILE alone3: kv add -> lag 0 in 2.55s   (lagwait: lag 0 at 2.82s (msgs=1000000 last_seq=4000000))
<scratch>/runB2.sh: line 22: 37700 Terminated: 15          python3 $S/mirrorlab.py scan 4291 KV_DNS_$st 90 > $S/runB2/scan-$st-$i-$k.txt 2>&1
<scratch>/runB2.sh: line 22: 37701 Terminated: 15          python3 $S/mirrorlab.py scan 4291 KV_DNS_$st 90 > $S/runB2/scan-$st-$i-$k.txt 2>&1
<scratch>/runB2.sh: line 22: 37702 Terminated: 15          python3 $S/mirrorlab.py scan 4291 KV_DNS_$st 90 > $S/runB2/scan-$st-$i-$k.txt 2>&1
  DNS_FILE scan1: kv add -> lag 0 in 3.30s   (lagwait: lag 0 at 3.58s (msgs=1000000 last_seq=4000000))
    scanner 1:
    scanner 2:
    scanner 3:
<scratch>/runB2.sh: line 22: 37753 Terminated: 15          python3 $S/mirrorlab.py scan 4291 KV_DNS_$st 90 > $S/runB2/scan-$st-$i-$k.txt 2>&1
<scratch>/runB2.sh: line 22: 37754 Terminated: 15          python3 $S/mirrorlab.py scan 4291 KV_DNS_$st 90 > $S/runB2/scan-$st-$i-$k.txt 2>&1
<scratch>/runB2.sh: line 22: 37755 Terminated: 15          python3 $S/mirrorlab.py scan 4291 KV_DNS_$st 90 > $S/runB2/scan-$st-$i-$k.txt 2>&1
  DNS_FILE scan2: kv add -> lag 0 in 3.41s   (lagwait: lag 0 at 3.68s (msgs=1000000 last_seq=4000000))
    scanner 1:
    scanner 2:
    scanner 3:
<scratch>/runB2.sh: line 22: 37834 Terminated: 15          python3 $S/mirrorlab.py scan 4291 KV_DNS_$st 90 > $S/runB2/scan-$st-$i-$k.txt 2>&1
<scratch>/runB2.sh: line 22: 37835 Terminated: 15          python3 $S/mirrorlab.py scan 4291 KV_DNS_$st 90 > $S/runB2/scan-$st-$i-$k.txt 2>&1
<scratch>/runB2.sh: line 22: 37836 Terminated: 15          python3 $S/mirrorlab.py scan 4291 KV_DNS_$st 90 > $S/runB2/scan-$st-$i-$k.txt 2>&1
  DNS_FILE scan3: kv add -> lag 0 in 3.31s   (lagwait: lag 0 at 3.58s (msgs=1000000 last_seq=4000000))
    scanner 1:
    scanner 2:
    scanner 3:
  DNS_FILE alone4: kv add -> lag 0 in 2.63s   (lagwait: lag 0 at 2.91s (msgs=1000000 last_seq=4000000))
  DNS_FILE alone5: kv add -> lag 0 in 2.62s   (lagwait: lag 0 at 2.90s (msgs=1000000 last_seq=4000000))
## KV_DNS_MEM (memory): alone x3, then with three cold-scanning readers x3, then alone x2
  DNS_MEM alone1: kv add -> lag 0 in 0.98s   (lagwait: lag 0 at 1.26s (msgs=1000000 last_seq=4000000))
  DNS_MEM alone2: kv add -> lag 0 in 1.08s   (lagwait: lag 0 at 1.36s (msgs=1000000 last_seq=4000000))
  DNS_MEM alone3: kv add -> lag 0 in 0.96s   (lagwait: lag 0 at 1.24s (msgs=1000000 last_seq=4000000))
<scratch>/runB2.sh: line 22: 38016 Terminated: 15          python3 $S/mirrorlab.py scan 4291 KV_DNS_$st 90 > $S/runB2/scan-$st-$i-$k.txt 2>&1
<scratch>/runB2.sh: line 22: 38017 Terminated: 15          python3 $S/mirrorlab.py scan 4291 KV_DNS_$st 90 > $S/runB2/scan-$st-$i-$k.txt 2>&1
<scratch>/runB2.sh: line 22: 38018 Terminated: 15          python3 $S/mirrorlab.py scan 4291 KV_DNS_$st 90 > $S/runB2/scan-$st-$i-$k.txt 2>&1
  DNS_MEM scan1: kv add -> lag 0 in 1.15s   (lagwait: lag 0 at 1.44s (msgs=1000000 last_seq=4000000))
    scanner 1:
    scanner 2:
    scanner 3:
<scratch>/runB2.sh: line 22: 38049 Terminated: 15          python3 $S/mirrorlab.py scan 4291 KV_DNS_$st 90 > $S/runB2/scan-$st-$i-$k.txt 2>&1
<scratch>/runB2.sh: line 22: 38050 Terminated: 15          python3 $S/mirrorlab.py scan 4291 KV_DNS_$st 90 > $S/runB2/scan-$st-$i-$k.txt 2>&1
<scratch>/runB2.sh: line 22: 38051 Terminated: 15          python3 $S/mirrorlab.py scan 4291 KV_DNS_$st 90 > $S/runB2/scan-$st-$i-$k.txt 2>&1
  DNS_MEM scan2: kv add -> lag 0 in 1.07s   (lagwait: lag 0 at 1.34s (msgs=1000000 last_seq=4000000))
    scanner 1:
    scanner 2:
    scanner 3:
<scratch>/runB2.sh: line 22: 38101 Terminated: 15          python3 $S/mirrorlab.py scan 4291 KV_DNS_$st 90 > $S/runB2/scan-$st-$i-$k.txt 2>&1
<scratch>/runB2.sh: line 22: 38102 Terminated: 15          python3 $S/mirrorlab.py scan 4291 KV_DNS_$st 90 > $S/runB2/scan-$st-$i-$k.txt 2>&1
<scratch>/runB2.sh: line 22: 38103 Terminated: 15          python3 $S/mirrorlab.py scan 4291 KV_DNS_$st 90 > $S/runB2/scan-$st-$i-$k.txt 2>&1
  DNS_MEM scan3: kv add -> lag 0 in 1.18s   (lagwait: lag 0 at 1.46s (msgs=1000000 last_seq=4000000))
    scanner 1:
    scanner 2:
    scanner 3:
  DNS_MEM alone4: kv add -> lag 0 in 0.97s   (lagwait: lag 0 at 1.25s (msgs=1000000 last_seq=4000000))
  DNS_MEM alone5: kv add -> lag 0 in 1.06s   (lagwait: lag 0 at 1.35s (msgs=1000000 last_seq=4000000))

### the row-76 read at this scale: the file mirror with and without the everything-matching filter (Go client)
$ nats bench js consume --stream KV_DNS_FILE --consumer C_FILTER --filter '$KV.DNS.>' --acks none --msgs 1000000 --no-progress
NATS JetStream durable consumer (callback) stats: 174,117 msgs/sec ~ 21 MiB/sec
$ nats bench js consume --stream KV_DNS_FILE --consumer C_NOFILTER  --acks none --msgs 1000000 --no-progress
NATS JetStream durable consumer (callback) stats: 1,639,966 msgs/sec ~ 200 MiB/sec
$ nats bench js consume --stream KV_DNS_MEM --consumer C_FILTER --filter '$KV.DNS.>' --acks none --msgs 1000000 --no-progress
NATS JetStream durable consumer (callback) stats: 1,584,052 msgs/sec ~ 193 MiB/sec
$ nats bench js consume --stream KV_DNS_MEM --consumer C_NOFILTER  --acks none --msgs 1000000 --no-progress
NATS JetStream durable consumer (callback) stats: 1,537,846 msgs/sec ~ 188 MiB/sec

$ grep -v Healthcheck n1.log | tail -3
[37458] 2026/09/02 22:30:00.271106 [INF] Took 411.25µs to start JetStream
[37458] 2026/09/02 22:30:00.271124 [INF] Listening for client connections on 127.0.0.1:4291
[37458] 2026/09/02 22:30:00.271130 [INF] Server is ready
```

At 1 M subjects over 4 M sequences the row-76 ratio grows to **9.4×** (174,117 against 1,639,966
msg/s on the file mirror; the memory mirror unchanged at ~1.55 M either way).

After five `kv rm` / `kv add` cycles per mirror, the source carried exactly the two `JS_MIRROR_`
consumers of the two live mirrors — the best-effort delete of the previous ones worked every time
here (the id after `JS_MIRROR_` changed between creations of the same mirror name):


```
{
  "consumer_count": 0,
  "direct": [
    {
      "name": "JS_MIRROR_OQyMJ0fQ-xNfPDqDj",
      "mirror": null,
      "num_pending": 0,
      "last_active": "2026-09-02T20:30:56.597225Z"
    },
    {
      "name": "JS_MIRROR_HNs8w7PP-3T2idvAS",
      "mirror": null,
      "num_pending": 0,
      "last_active": "2026-09-02T20:31:20.255209Z"
    }
  ]
}
```

### B3 · the same source, three Go readers — the answer

The readers are three parallel shell loops of `nats bench js ordered --stream KV_DNS_<x> --msgs
1000000` — an ordered ephemeral consumer with no filter reading the stream head to tail, then again.
A loop started 0.3 s before the `kv add`; its first round therefore trails the catch-up (reading
messages as the mirror stores them) and its second round is a cold scan from the head. Two
baselines, three runs with readers, two baselines, per store.


```
### run B, third form: the same 1M-key / 4M-span source; the readers are three parallel loops of
###   nats bench js ordered --stream KV_DNS_<x> --msgs 1000000   (an ordered ephemeral consumer, no filter, head to tail, then again)
$ nats stream info KV_DNS --json | jq -c .state
{"messages":1000000,"bytes":146000000,"first_seq":1,"first_ts":"2026-09-02T20:30:00.422265Z","last_seq":4000000,"last_ts":"2026-09-02T20:30:19.369319Z","num_deleted":3000000,"num_subjects":1000000,"consumer_count":0}
## KV_DNS_FILE (file): alone x2, with three readers x3, alone x2
  DNS_FILE alone1: kv add -> lag 0 in 2.64s   (lagwait: lag 0 at 2.90s (msgs=1000000 last_seq=4000000))
  DNS_FILE alone2: kv add -> lag 0 in 2.54s   (lagwait: lag 0 at 2.81s (msgs=1000000 last_seq=4000000))
  DNS_FILE scan1: kv add -> lag 0 in 10.11s   (lagwait: lag 0 at 10.38s (msgs=1000000 last_seq=4000000))
    reader 1: rounds completed (stats lines) = 2
      NATS JetStream ordered ephemeral consumer stats: 92,211 msgs/sec ~ 11 MiB/sec
      NATS JetStream ordered ephemeral consumer stats: 533,253 msgs/sec ~ 65 MiB/sec
    reader 2: rounds completed (stats lines) = 2
      NATS JetStream ordered ephemeral consumer stats: 101,669 msgs/sec ~ 12 MiB/sec
      NATS JetStream ordered ephemeral consumer stats: 518,027 msgs/sec ~ 63 MiB/sec
    reader 3: rounds completed (stats lines) = 2
      NATS JetStream ordered ephemeral consumer stats: 101,145 msgs/sec ~ 12 MiB/sec
      NATS JetStream ordered ephemeral consumer stats: 518,767 msgs/sec ~ 63 MiB/sec
  DNS_FILE scan2: kv add -> lag 0 in 8.87s   (lagwait: lag 0 at 9.13s (msgs=1000000 last_seq=4000000))
    reader 1: rounds completed (stats lines) = 2
      NATS JetStream ordered ephemeral consumer stats: 106,624 msgs/sec ~ 13 MiB/sec
      NATS JetStream ordered ephemeral consumer stats: 524,393 msgs/sec ~ 64 MiB/sec
    reader 2: rounds completed (stats lines) = 2
      NATS JetStream ordered ephemeral consumer stats: 110,268 msgs/sec ~ 14 MiB/sec
      NATS JetStream ordered ephemeral consumer stats: 527,253 msgs/sec ~ 64 MiB/sec
    reader 3: rounds completed (stats lines) = 2
      NATS JetStream ordered ephemeral consumer stats: 109,710 msgs/sec ~ 13 MiB/sec
      NATS JetStream ordered ephemeral consumer stats: 530,928 msgs/sec ~ 65 MiB/sec
  DNS_FILE scan3: kv add -> lag 0 in 9.77s   (lagwait: lag 0 at 10.03s (msgs=1000000 last_seq=4000000))
    reader 1: rounds completed (stats lines) = 2
      NATS JetStream ordered ephemeral consumer stats: 99,089 msgs/sec ~ 12 MiB/sec
      NATS JetStream ordered ephemeral consumer stats: 536,632 msgs/sec ~ 66 MiB/sec
    reader 2: rounds completed (stats lines) = 2
      NATS JetStream ordered ephemeral consumer stats: 98,600 msgs/sec ~ 12 MiB/sec
      NATS JetStream ordered ephemeral consumer stats: 535,343 msgs/sec ~ 65 MiB/sec
    reader 3: rounds completed (stats lines) = 2
      NATS JetStream ordered ephemeral consumer stats: 102,318 msgs/sec ~ 12 MiB/sec
      NATS JetStream ordered ephemeral consumer stats: 557,828 msgs/sec ~ 68 MiB/sec
  DNS_FILE alone3: kv add -> lag 0 in 2.63s   (lagwait: lag 0 at 2.91s (msgs=1000000 last_seq=4000000))
  DNS_FILE alone4: kv add -> lag 0 in 2.64s   (lagwait: lag 0 at 2.91s (msgs=1000000 last_seq=4000000))
## KV_DNS_MEM (memory): alone x2, with three readers x3, alone x2
  DNS_MEM alone1: kv add -> lag 0 in 1.09s   (lagwait: lag 0 at 1.36s (msgs=1000000 last_seq=4000000))
  DNS_MEM alone2: kv add -> lag 0 in 1.07s   (lagwait: lag 0 at 1.34s (msgs=1000000 last_seq=4000000))
  DNS_MEM scan1: kv add -> lag 0 in 3.32s   (lagwait: lag 0 at 3.56s (msgs=1000000 last_seq=4000000))
    reader 1: rounds completed (stats lines) = 1
      NATS JetStream ordered ephemeral consumer stats: 210,585 msgs/sec ~ 26 MiB/sec
    reader 2: rounds completed (stats lines) = 1
      NATS JetStream ordered ephemeral consumer stats: 211,212 msgs/sec ~ 26 MiB/sec
    reader 3: rounds completed (stats lines) = 1
      NATS JetStream ordered ephemeral consumer stats: 210,367 msgs/sec ~ 26 MiB/sec
  DNS_MEM scan2: kv add -> lag 0 in 3.31s   (lagwait: lag 0 at 3.56s (msgs=1000000 last_seq=4000000))
    reader 1: rounds completed (stats lines) = 1
      NATS JetStream ordered ephemeral consumer stats: 207,909 msgs/sec ~ 25 MiB/sec
    reader 2: rounds completed (stats lines) = 1
      NATS JetStream ordered ephemeral consumer stats: 208,303 msgs/sec ~ 25 MiB/sec
    reader 3: rounds completed (stats lines) = 1
      NATS JetStream ordered ephemeral consumer stats: 208,675 msgs/sec ~ 26 MiB/sec
  DNS_MEM scan3: kv add -> lag 0 in 3.72s   (lagwait: lag 0 at 3.97s (msgs=1000000 last_seq=4000000))
    reader 1: rounds completed (stats lines) = 1
      NATS JetStream ordered ephemeral consumer stats: 193,345 msgs/sec ~ 24 MiB/sec
    reader 2: rounds completed (stats lines) = 1
      NATS JetStream ordered ephemeral consumer stats: 194,283 msgs/sec ~ 24 MiB/sec
    reader 3: rounds completed (stats lines) = 1
      NATS JetStream ordered ephemeral consumer stats: 193,801 msgs/sec ~ 24 MiB/sec
  DNS_MEM alone3: kv add -> lag 0 in 1.08s   (lagwait: lag 0 at 1.35s (msgs=1000000 last_seq=4000000))
  DNS_MEM alone4: kv add -> lag 0 in 1.08s   (lagwait: lag 0 at 1.35s (msgs=1000000 last_seq=4000000))
```

| store | alone | with three readers | ratio |
|---|---:|---:|---:|
| file mirror | 2.54, 2.63, 2.64, 2.64 s | **10.11, 8.87, 9.77 s** | **3.4–3.9×** |
| memory mirror | 1.07, 1.08, 1.08, 1.09 s | **3.32, 3.31, 3.72 s** | **3.1–3.4×** |

gh#8444 measured 2.89× with one reader on file storage. Here the effect is of the same order on
**both** stores, so on this host it is not specific to the file store's `fs.mu` — the one comment on
the thread argues from that lock (`SkipMsgs` plus `StoreMsg` under the exclusive lock against a
reader's `RLock` per message), and the file store's larger absolute cost is consistent with it, but
a memory mirror pays a similar ratio for the same three readers. The readers' own numbers show what
they were doing: ~100,000 msg/s each while trailing the file mirror's catch-up, ~530,000 msg/s on
the cold scan after it (the memory mirror: ~210,000 msg/s trailing).

What was not done: one reader instead of three (the thread's shape), a profile, and a leafnode
between the source and the mirror. The thread has no maintainer reply as of 2026-09-02.

## Run C · an object-store bucket on the leaf, mirrored into the hub across two domains

The pair from `object-store-across-leafnode-observed-v2.14.6.md` — different domains, shared
non-system account — started by hand: `nats-server -c hub.conf` and `nats-server -c leaf.conf` with
`store_dir` under `<scratch>/leaflab/`. Then issue #5106's procedure on nats-server 2.14.6 and CLI
0.4.0, first the way the reporter did it (no transform), then the way the maintainer prescribed.


```
### the pair: hub (domain hub, 4251, leafnodes port 7451) and leaf (domain leaf, 4252), account APP on both — the configs of object-store-across-leafnode-observed-v2.14.6.md
[31505] 2026/09/02 22:16:29.121230 [INF] [::1]:58618 - lid:6 - JetStream using domains: local "hub", remote "leaf"
[31535] 2026/09/02 22:16:29.121421 [INF] [::1]:7451 - lid:6 - JetStream using domains: local "leaf", remote "hub"

### 1 · on the leaf: a bucket and three objects
$ nats -s nats://a:p@127.0.0.1:4252 object add dms
Information for Object Store Bucket dms created 2026-09-02 22:28:34

Configuration:

          Bucket Name: dms
             Replicas: 1
                  TTL: unlimited
               Sealed: false
                 Size: 0 B
  Maximum Bucket Size: unlimited
              Storage: File
   Backing Store Kind: JetStream
     JetStream Stream: OBJ_dms

Cluster Information:

                 Name: leaf
               Leader: leaf

$ nats -s leaf object put dms f1.bin --no-progress
Object information for dms > f1.bin
               Size: 300 KiB
             Chunks: 3
             Digest: SHA-256 d2e2f117a910ab4fdc588ff8430fe1d887d4aa634a1fd3a9f9c4455020092c8a
$ nats -s leaf object put dms f2.bin --no-progress
Object information for dms > f2.bin
               Size: 700 KiB
             Chunks: 6
             Digest: SHA-256 d86c37feda24ca8f0970757174ff35ef9216d6b848d2350b8a131a85552f0fc8
$ nats -s leaf object put dms f3.bin --no-progress
Object information for dms > f3.bin
               Size: 1.5 MiB
             Chunks: 12
             Digest: SHA-256 d02824db3423549564dd64042b5cec22324b747e61747808ca1cc824a3882b20

$ nats -s nats://a:p@127.0.0.1:4252 object ls dms
╭────────────────────────────────────────╮
│             Bucket Contents            │
├────────┬─────────┬─────────────────────┤
│ Name   │ Size    │ Time                │
├────────┼─────────┼─────────────────────┤
│ f1.bin │ 300 KiB │ 2026-09-02 22:28:34 │
│ f2.bin │ 700 KiB │ 2026-09-02 22:28:34 │
│ f3.bin │ 1.5 MiB │ 2026-09-02 22:28:34 │
╰────────┴─────────┴─────────────────────╯


$ nats -s nats://a:p@127.0.0.1:4252 stream info OBJ_dms --json
{
  "config": {
    "name": "OBJ_dms",
    "subjects": [
      "$O.dms.C.\u003e",
      "$O.dms.M.\u003e"
    ],
    "retention": "limits",
    "max_consumers": -1,
    "max_msgs_per_subject": -1,
    "max_msgs": -1,
    "max_bytes": -1,
    "max_age": 0,
    "max_msg_size": -1,
    "storage": "file",
    "discard": "new",
    "num_replicas": 1,
    "duplicate_window": 120000000000,
    "sealed": false,
    "deny_delete": false,
    "deny_purge": false,
    "allow_rollup_hdrs": true,
    "allow_direct": true,
    "mirror_direct": false,
    "metadata": {
      "_nats.level": "4",
      "_nats.req.level": "0",
      "_nats.ver": "2.14.6"
    },
    "consumer_limits": {}
  },
  "created": "2026-09-02T20:28:34.743533Z",
  "state": {
    "messages": 24,
    "bytes": 2562186,
    "first_seq": 1,
    "first_ts": "2026-09-02T20:28:34.761106Z",
    "last_seq": 24,
    "last_ts": "2026-09-02T20:28:34.790916Z",
    "num_subjects": 6,
    "consumer_count": 0
  },
  "domain": "leaf",
  "cluster": {
    "name": "leaf",
    "leader": "leaf"
  },
  "ts": "2026-09-02T20:28:34.815173Z"
}


### 2 · on the hub, with no mirror at all (the SI-1 check)
$ nats -s nats://a:p@127.0.0.1:4251 object ls
No Object Store buckets found

$ nats -s nats://a:p@127.0.0.1:4251 object ls dms
nats: error: nats: bucket not found

$ nats -s nats://a:p@127.0.0.1:4251 stream ls
No Streams defined

### 3 · on the hub: the mirror the issue's reporter built — no transform
$ cat m1.json
{"name":"OBJ_dms_mirror","retention":"limits","max_consumers":-1,"max_msgs":-1,"max_bytes":-1,"max_age":0,"max_msgs_per_subject":-1,"max_msg_size":-1,"discard":"new","storage":"file","num_replicas":1,"allow_direct":true,"allow_rollup_hdrs":true,"mirror":{"name":"OBJ_dms","external":{"api":"$JS.leaf.API"}}}

$ nats -s nats://a:p@127.0.0.1:4251 stream add OBJ_dms_mirror --config m1.json
Stream OBJ_dms_mirror was created

Information for Stream OBJ_dms_mirror created 2026-09-02 22:28:35

                     Replicas: 1
                      Storage: File

Options:

                    Retention: Limits
              Acknowledgments: true
               Discard Policy: New
             Duplicate Window: 0s
                   Direct Get: true
  Allows Atomic Batch Publish: false
    Allows Fast Batch Publish: false
              Allows Counters: false
            Allows Msg Delete: true
       Allows Per-Message TTL: false
                 Allows Purge: true
             Allows Schedules: false
               Allows Rollups: true

Limits:

             Maximum Messages: unlimited
          Maximum Per Subject: unlimited
                Maximum Bytes: unlimited
                  Maximum Age: unlimited
         Maximum Message Size: unlimited
            Maximum Consumers: unlimited

Replication:

                       Mirror: OBJ_dms, API Prefix: $JS.leaf.API

Mirror Information:

                  Stream Name: OBJ_dms
                          Lag: 0
                    Last Seen: never
              Ext. API Prefix: $JS.leaf.API

State:

                 Host Version: 2.14.6
           Required API Level: 0 hosted at level 4
                     Messages: 0
                        Bytes: 0 B
               First Sequence: 0
                Last Sequence: 0
             Active Consumers: 0

lagwait: lag 0 at 0.76s (msgs=24 last_seq=24)

$ nats -s nats://a:p@127.0.0.1:4251 stream info OBJ_dms_mirror --json
{
  "config": {
    "name": "OBJ_dms_mirror",
    "retention": "limits",
    "max_consumers": -1,
    "max_msgs_per_subject": -1,
    "max_msgs": -1,
    "max_bytes": -1,
    "max_age": 0,
    "max_msg_size": -1,
    "storage": "file",
    "discard": "new",
    "num_replicas": 1,
    "mirror": {
      "name": "OBJ_dms",
      "external": {
        "api": "$JS.leaf.API",
        "deliver": ""
      }
    },
    "sealed": false,
    "deny_delete": false,
    "deny_purge": false,
    "allow_rollup_hdrs": true,
    "allow_direct": true,
    "mirror_direct": false,
    "metadata": {
      "_nats.level": "4",
      "_nats.req.level": "0",
      "_nats.ver": "2.14.6"
    },
    "consumer_limits": {}
  },
  "created": "2026-09-02T20:28:35.200007Z",
  "state": {
    "messages": 24,
    "bytes": 2562186,
    "first_seq": 1,
    "first_ts": "2026-09-02T20:28:34.761106Z",
    "last_seq": 24,
    "last_ts": "2026-09-02T20:28:34.790916Z",
    "num_subjects": 6,
    "consumer_count": 0
  },
  "domain": "hub",
  "cluster": {
    "leader": "hub"
  },
  "mirror": {
    "name": "OBJ_dms",
    "external": {
      "api": "$JS.leaf.API",
      "deliver": ""
    },
    "lag": 0,
    "active": 275510000
  },
  "ts": "2026-09-02T20:28:35.684695Z"
}


$ nats -s nats://a:p@127.0.0.1:4251 stream subjects OBJ_dms_mirror
╭─────────────────────────────────────────╮
│   6 Subjects in stream OBJ_dms_mirror   │
├─────────────────────────────────┬───────┤
│ Subject                         │ Count │
├─────────────────────────────────┼───────┤
│ $O.dms.M.ZjEuYmlu               │ 1     │
│ $O.dms.M.ZjIuYmlu               │ 1     │
│ $O.dms.M.ZjMuYmlu               │ 1     │
│ $O.dms.C.BLluK7WW5ZTH9NSWYCDKBl │ 3     │
│ $O.dms.C.gh93xxi9gv9xtZ6RnYBQEX │ 6     │
│ $O.dms.C.Bdml5HwNIsKcmJejg0sxuR │ 12    │
╰─────────────────────────────────┴───────╯


$ nats -s nats://a:p@127.0.0.1:4251 object ls
╭────────────────────────────────────────────────────────────────────────╮
│                          Object Store Buckets                          │
├────────────┬─────────────┬─────────────────────┬─────────┬─────────────┤
│ Bucket     │ Description │ Created             │ Size    │ Last Update │
├────────────┼─────────────┼─────────────────────┼─────────┼─────────────┤
│ dms_mirror │             │ 2026-09-02 22:28:35 │ 2.4 MiB │ 938ms       │
╰────────────┴─────────────┴─────────────────────┴─────────┴─────────────╯


$ nats -s nats://a:p@127.0.0.1:4251 object ls dms_mirror
No entries found

$ nats -s nats://a:p@127.0.0.1:4251 object info dms_mirror
Information for Object Store Bucket dms_mirror created 2026-09-02 22:28:35

Configuration:

          Bucket Name: dms_mirror
             Replicas: 1
                  TTL: unlimited
               Sealed: false
                 Size: 2.4 MiB
  Maximum Bucket Size: unlimited
              Storage: File
   Backing Store Kind: JetStream
     JetStream Stream: OBJ_dms_mirror

Cluster Information:

                 Name: 
               Leader: hub

$ nats -s nats://a:p@127.0.0.1:4251 object get dms_mirror f1.bin -O out-m1-f1.bin
nats: error: nats: object not found

$ nats -s hub request '$JS.API.STREAM.NAMES' '{"subject":"$O.dms_mirror.M.>"}'
22:28:35 Sending request on "$JS.API.STREAM.NAMES"
22:28:35 Received with rtt 310.292µs
{"type":"io.nats.jetstream.api.v1.stream_names_response","total":0,"offset":0,"limit":1024,"streams":null}



$ nats -s hub request '$JS.API.STREAM.NAMES' '{"subject":"$O.dms.M.>"}'
22:28:35 Sending request on "$JS.API.STREAM.NAMES"
22:28:35 Received with rtt 133.333µs
{"type":"io.nats.jetstream.api.v1.stream_names_response","total":0,"offset":0,"limit":1024,"streams":null}



$ nats -s hub request '$JS.API.STREAM.NAMES' '{}'
22:28:35 Sending request on "$JS.API.STREAM.NAMES"
22:28:35 Received with rtt 156.917µs
{"type":"io.nats.jetstream.api.v1.stream_names_response","total":1,"offset":0,"limit":1024,"streams":["OBJ_dms_mirror"]}



$ nats -s hub object ls dms_mirror --trace 2>&1 | grep -E '>>>|<<<' | cut -c1-220
22:28:35 >>> $JS.API.STREAM.INFO.OBJ_dms_mirror
22:28:35 >>> Connected to nats://a:p@127.0.0.1:4251 (127.0.0.1:4251)
22:28:35 <<< $JS.API.STREAM.INFO.OBJ_dms_mirror: {"type":"io.nats.jetstream.api.v1.stream_info_response","total":0,"offset":0,"limit":0,"config":{"name":"OBJ_dms_mirror","retention":"limits","max_consumers":-1,"max_msgs"
22:28:35 >>> $JS.API.DIRECT.GET.OBJ_dms_mirror.$O.dms_mirror.M.>
22:28:35 <<< $JS.API.DIRECT.GET.OBJ_dms_mirror.$O.dms_mirror.M.>: 
22:28:35 >>> $JS.API.CONSUMER.CREATE.OBJ_dms_mirror.ctpyCnVy.$O.dms_mirror.M.>
22:28:35 <<< $JS.API.CONSUMER.CREATE.OBJ_dms_mirror.ctpyCnVy.$O.dms_mirror.M.>: {"type":"io.nats.jetstream.api.v1.consumer_create_response","stream_name":"OBJ_dms_mirror","name":"ctpyCnVy","created":"2026-09-02T20:28:35.
22:28:35 >>> $JS.API.CONSUMER.DELETE.OBJ_dms_mirror.ctpyCnVy
22:28:35 <<< $JS.API.CONSUMER.DELETE.OBJ_dms_mirror.ctpyCnVy: {"type":"io.nats.jetstream.api.v1.consumer_delete_response","success":true}

### 4 · the mirror with the transform the maintainer prescribed
$ nats -s nats://a:p@127.0.0.1:4251 stream rm OBJ_dms_mirror --force

$ cat m2.json
{"name":"OBJ_dms_mirror","retention":"limits","max_consumers":-1,"max_msgs":-1,"max_bytes":-1,"max_age":0,"max_msgs_per_subject":-1,"max_msg_size":-1,"discard":"new","storage":"file","num_replicas":1,"allow_direct":true,"allow_rollup_hdrs":true,"mirror":{"name":"OBJ_dms","external":{"api":"$JS.leaf.API"},"subject_transforms":[{"src":"$O.dms.>","dest":"$O.dms_mirror.>"}]}}

$ nats -s nats://a:p@127.0.0.1:4251 stream add OBJ_dms_mirror --config m2.json
Stream OBJ_dms_mirror was created

Information for Stream OBJ_dms_mirror created 2026-09-02 22:28:36

                      Replicas: 1
                       Storage: File

Options:

                     Retention: Limits
               Acknowledgments: true
                Discard Policy: New
              Duplicate Window: 0s
                    Direct Get: true
   Allows Atomic Batch Publish: false
     Allows Fast Batch Publish: false
               Allows Counters: false
             Allows Msg Delete: true
        Allows Per-Message TTL: false
                  Allows Purge: true
              Allows Schedules: false
                Allows Rollups: true

Limits:

              Maximum Messages: unlimited
           Maximum Per Subject: unlimited
                 Maximum Bytes: unlimited
                   Maximum Age: unlimited
          Maximum Message Size: unlimited
             Maximum Consumers: unlimited

Replication:

                        Mirror: OBJ_dms, API Prefix: $JS.leaf.API

Mirror Information:

                   Stream Name: OBJ_dms
  Subject Filter and Transform: $O.dms.> to $O.dms_mirror.>
                           Lag: 0
                     Last Seen: never
               Ext. API Prefix: $JS.leaf.API

State:

                  Host Version: 2.14.6
            Required API Level: 0 hosted at level 4
                      Messages: 0
                         Bytes: 0 B
                First Sequence: 0
                 Last Sequence: 0
              Active Consumers: 0

lagwait: lag 0 at 0.51s (msgs=24 last_seq=24)

$ nats -s nats://a:p@127.0.0.1:4251 stream subjects OBJ_dms_mirror
╭────────────────────────────────────────────────╮
│       6 Subjects in stream OBJ_dms_mirror      │
├────────────────────────────────────────┬───────┤
│ Subject                                │ Count │
├────────────────────────────────────────┼───────┤
│ $O.dms_mirror.M.ZjEuYmlu               │ 1     │
│ $O.dms_mirror.M.ZjIuYmlu               │ 1     │
│ $O.dms_mirror.M.ZjMuYmlu               │ 1     │
│ $O.dms_mirror.C.BLluK7WW5ZTH9NSWYCDKBl │ 3     │
│ $O.dms_mirror.C.gh93xxi9gv9xtZ6RnYBQEX │ 6     │
│ $O.dms_mirror.C.Bdml5HwNIsKcmJejg0sxuR │ 12    │
╰────────────────────────────────────────┴───────╯


$ nats -s nats://a:p@127.0.0.1:4251 object ls dms_mirror
╭────────────────────────────────────────╮
│             Bucket Contents            │
├────────┬─────────┬─────────────────────┤
│ Name   │ Size    │ Time                │
├────────┼─────────┼─────────────────────┤
│ f1.bin │ 300 KiB │ 2026-09-02 22:28:34 │
│ f2.bin │ 700 KiB │ 2026-09-02 22:28:34 │
│ f3.bin │ 1.5 MiB │ 2026-09-02 22:28:34 │
╰────────┴─────────┴─────────────────────╯


$ nats -s nats://a:p@127.0.0.1:4251 object info dms_mirror f1.bin
Object information for dms > f1.bin

               Size: 300 KiB
  Modification Time: 2026-09-02 22:28:34
             Chunks: 3
             Digest: SHA-256 d2e2f117a910ab4fdc588ff8430fe1d887d4aa634a1fd3a9f9c4455020092c8a

$ nats -s nats://a:p@127.0.0.1:4251 object get dms_mirror f3.bin -O out-m2-f3.bin

 done! [1.5 MiB in 1ms; 5.8 MiB/s]

Wrote: 1.5 MiB to <scratch>/runC/out-m2-f3.bin in 302ms

$ cmp f3.bin out-m2-f3.bin && echo identical
identical

### 5 · live: a fourth object put on the leaf after the mirror exists
$ nats -s leaf object put dms f4.bin --no-progress
               Size: 200 KiB
             Chunks: 2
$ nats -s nats://a:p@127.0.0.1:4251 object ls dms_mirror
╭────────────────────────────────────────╮
│             Bucket Contents            │
├────────┬─────────┬─────────────────────┤
│ Name   │ Size    │ Time                │
├────────┼─────────┼─────────────────────┤
│ f1.bin │ 300 KiB │ 2026-09-02 22:28:34 │
│ f2.bin │ 700 KiB │ 2026-09-02 22:28:34 │
│ f3.bin │ 1.5 MiB │ 2026-09-02 22:28:34 │
│ f4.bin │ 200 KiB │ 2026-09-02 22:28:36 │
╰────────┴─────────┴─────────────────────╯


$ nats -s nats://a:p@127.0.0.1:4251 stream info OBJ_dms_mirror --json
{
  "config": {
    "name": "OBJ_dms_mirror",
    "retention": "limits",
    "max_consumers": -1,
    "max_msgs_per_subject": -1,
    "max_msgs": -1,
    "max_bytes": -1,
    "max_age": 0,
    "max_msg_size": -1,
    "storage": "file",
    "discard": "new",
    "num_replicas": 1,
    "mirror": {
      "name": "OBJ_dms",
      "external": {
        "api": "$JS.leaf.API",
        "deliver": ""
      },
      "subject_transforms": [
        {
          "src": "$O.dms.\u003e",
          "dest": "$O.dms_mirror.\u003e"
        }
      ]
    },
    "sealed": false,
    "deny_delete": false,
    "deny_purge": false,
    "allow_rollup_hdrs": true,
    "allow_direct": true,
    "mirror_direct": false,
    "metadata": {
      "_nats.level": "4",
      "_nats.req.level": "0",
      "_nats.ver": "2.14.6"
    },
    "consumer_limits": {}
  },
  "created": "2026-09-02T20:28:36.160879Z",
  "state": {
    "messages": 27,
    "bytes": 2767598,
    "first_seq": 1,
    "first_ts": "2026-09-02T20:28:34.761106Z",
    "last_seq": 27,
    "last_ts": "2026-09-02T20:28:36.794412Z",
    "num_subjects": 8,
    "consumer_count": 0
  },
  "domain": "hub",
  "cluster": {
    "leader": "hub"
  },
  "mirror": {
    "name": "OBJ_dms",
    "external": {
      "api": "$JS.leaf.API",
      "deliver": ""
    },
    "lag": 0,
    "active": 62176000,
    "subject_transforms": [
      {
        "src": "$O.dms.\u003e",
        "dest": "$O.dms_mirror.\u003e"
      }
    ]
  },
  "ts": "2026-09-02T20:28:38.859242Z"
}


### 6 · the write side: a put on the hub against the mirror bucket
$ nats -s hub object put dms_mirror f4.bin --no-progress
             Digest: SHA-256 b6ad76e2deb7e7d8c8cb929339ae06ca31a21ed503463aa0a17cd4376cf3f353

nats: error: could not obtain confirmation: cannot ask for confirmation without a terminal

### 7 · what the CLI offers: nats object add has no --mirror; nats kv add has --mirror and --mirror-domain
$ nats object add --help | grep -ci mirror
0
$ nats kv add --help | grep -i mirror
  --mirror=MIRROR                Creates a mirror of a different bucket
  --mirror-domain=MIRROR-DOMAIN  When mirroring find the bucket in a different

### 8 · the KV comparison across the same boundary: a bucket on the leaf, a --mirror-domain mirror on the hub
$ nats -s nats://a:p@127.0.0.1:4252 kv add CFG
Information for Key-Value Store Bucket CFG created 2026-09-02 22:28:38

Configuration:

            Bucket Name: CFG
           History Kept: 1
          Values Stored: 0
             Compressed: false
  Per-Key TTL Supported: false
     Backing Store Kind: JetStream
            Bucket Size: 0 B
    Maximum Bucket Size: unlimited
     Maximum Value Size: unlimited
            Maximum Age: unlimited
       JetStream Stream: KV_CFG
                Storage: File

Cluster Information:

                   Name: leaf
                 Leader: leaf

$ nats -s nats://a:p@127.0.0.1:4252 kv put CFG k1 value-from-leaf
value-from-leaf

$ nats -s nats://a:p@127.0.0.1:4251 kv add CFG_M --mirror CFG --mirror-domain leaf
Information for Key-Value Store Bucket CFG_M created 2026-09-02 22:28:38

Configuration:

            Bucket Name: CFG_M
           History Kept: 1
          Values Stored: 0
             Compressed: false
  Per-Key TTL Supported: false
     Backing Store Kind: JetStream
            Bucket Size: 0 B
    Maximum Bucket Size: unlimited
     Maximum Value Size: unlimited
            Maximum Age: unlimited
       JetStream Stream: KV_CFG_M
                Storage: File

Mirror Information:

          Origin Bucket: CFG
           External API: $JS.leaf.API
              Last Seen: never
                    Lag: 0

Cluster Information:

                   Name: 
                 Leader: hub

$ nats -s nats://a:p@127.0.0.1:4251 kv get CFG_M k1
CFG_M > k1 revision: 1 created @ 2026-09-02 22:28:38

value-from-leaf


$ nats -s nats://a:p@127.0.0.1:4251 kv ls CFG_M
k1

$ nats -s hub kv get CFG_M k1 --trace 2>&1 | grep '>>>'
22:28:41 >>> $JS.API.STREAM.INFO.KV_CFG_M
22:28:41 >>> Connected to nats://a:p@127.0.0.1:4251 (127.0.0.1:4251)
22:28:41 >>> $JS.API.DIRECT.GET.KV_CFG_M.$KV.CFG.k1

$ nats -s nats://a:p@127.0.0.1:4251 stream info KV_CFG_M --json
{
  "config": {
    "name": "KV_CFG_M",
    "retention": "limits",
    "max_consumers": -1,
    "max_msgs_per_subject": 1,
    "max_msgs": -1,
    "max_bytes": -1,
    "max_age": 0,
    "max_msg_size": -1,
    "storage": "file",
    "discard": "new",
    "num_replicas": 1,
    "duplicate_window": 120000000000,
    "mirror": {
      "name": "KV_CFG",
      "external": {
        "api": "$JS.leaf.API",
        "deliver": ""
      }
    },
    "sealed": false,
    "deny_delete": true,
    "deny_purge": false,
    "allow_rollup_hdrs": true,
    "allow_direct": true,
    "mirror_direct": true,
    "metadata": {
      "_nats.level": "4",
      "_nats.req.level": "0",
      "_nats.ver": "2.14.6"
    },
    "consumer_limits": {}
  },
  "created": "2026-09-02T20:28:38.934398Z",
  "state": {
    "messages": 1,
    "bytes": 55,
    "first_seq": 1,
    "first_ts": "2026-09-02T20:28:38.923992Z",
    "last_seq": 1,
    "last_ts": "2026-09-02T20:28:38.923992Z",
    "num_subjects": 1,
    "consumer_count": 0
  },
  "domain": "hub",
  "cluster": {
    "leader": "hub"
  },
  "mirror": {
    "name": "KV_CFG",
    "external": {
      "api": "$JS.leaf.API",
      "deliver": ""
    },
    "lag": 0,
    "active": 934263000
  },
  "ts": "2026-09-02T20:28:41.028587Z"
}


### logs
$ grep -vE 'Healthcheck' hub.log | tail -6
[31505] 2026/09/02 22:16:28.589629 [INF] Took 624µs to start JetStream
[31505] 2026/09/02 22:16:28.589681 [INF] Listening for leafnode connections on 0.0.0.0:7451
[31505] 2026/09/02 22:16:28.590398 [INF] Listening for client connections on 0.0.0.0:4251
[31505] 2026/09/02 22:16:28.590486 [INF] Server is ready
[31505] 2026/09/02 22:16:29.118977 [INF] [::1]:58618 - lid:6 - Leafnode connection created 
[31505] 2026/09/02 22:16:29.121230 [INF] [::1]:58618 - lid:6 - JetStream using domains: local "hub", remote "leaf"
$ tail -4 leaf.log
[31535] 2026/09/02 22:16:29.114871 [INF] Listening for client connections on 0.0.0.0:4252
[31535] 2026/09/02 22:16:29.115068 [INF] Server is ready
[31535] 2026/09/02 22:16:29.118883 [INF] [::1]:7451 - lid:6 - Leafnode connection created for account: APP 
[31535] 2026/09/02 22:16:29.121421 [INF] [::1]:7451 - lid:6 - JetStream using domains: local "leaf", remote "hub"
```
```
### 6 (again) · the write side: a put of a NEW name on the hub against the mirror bucket, 3 s timeout
$ nats -s hub object put dms_mirror f5.bin --no-progress --timeout 3s
nats: error: nats: no response from stream

$ nats -s hub stream info OBJ_dms_mirror --json | jq -c .state
{"messages":27,"bytes":2767598,"first_seq":1,"first_ts":"2026-09-02T20:28:34.761106Z","last_seq":27,"last_ts":"2026-09-02T20:28:36.794412Z","num_subjects":8,"consumer_count":0}
$ nats -s leaf stream info OBJ_dms --json | jq -c .state
{"messages":27,"bytes":2767409,"first_seq":1,"first_ts":"2026-09-02T20:28:34.761106Z","last_seq":27,"last_ts":"2026-09-02T20:28:36.794412Z","num_subjects":8,"consumer_count":0}
$ nats -s hub object ls dms_mirror | grep -c bin
4
```

What this settles, on 2.14.6 / CLI 0.4.0 / nats.go 1.53.1:

1. **With no mirror at all, the hub sees nothing of the leaf's bucket** — `No Object Store buckets
   found`, `nats: error: nats: bucket not found`, `No Streams defined`. SI-1's convergence needs a
   same-named bucket on both sides; a mirror is a separate thing.
2. **A mirror without the transform is a bucket that lists as empty.** `nats object ls` shows
   `dms_mirror` with its 2.4 MiB, `nats object ls dms_mirror` prints `No entries found`, and a `get`
   says `object not found`. The 2024 error (`no stream matches subject`) is gone — the client binds
   the bucket by stream name now (`$JS.API.STREAM.INFO.OBJ_dms_mirror`, no `STREAM.NAMES` lookup
   in the trace) — but it then reads `$O.dms_mirror.M.>` and the mirror holds `$O.dms.M.>`.
   `STREAM.NAMES` by subject finds the mirror under neither prefix; only `{}` lists it.
3. **With `$O.dms.> → $O.dms_mirror.>` everything works**: list, info, a byte-identical get, and a
   fourth object put on the leaf appears in the hub's listing within two seconds.
4. **A put against the mirror bucket fails** with `nats: error: nats: no response from stream`
   (3 s timeout), and both streams are unchanged — the mirror captures no subject.
5. `nats object add` has **no `--mirror`**; `nats kv add` has `--mirror` and `--mirror-domain`, and
   the KV mirror built with them across the same boundary is readable by its own name at once
   (`kv get CFG_M k1` → `value-from-leaf`), because for a mirror with an `external` block the client
   rewrites the key prefix to the origin's (`$JS.API.DIRECT.GET.KV_CFG_M.$KV.CFG.k1` in the trace).

