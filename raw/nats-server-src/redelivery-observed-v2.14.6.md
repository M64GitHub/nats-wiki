<!-- source: run locally against nats-server v2.14.6 (`nats-server --version` -> v2.14.6) and nats CLI 0.4.0
     · observed 2026-09-03 · one standalone server from `NATS_LAB_FLAGS=-DV bash tools/lab/cluster.sh up 1`
     (client 127.0.0.1:4291, monitoring 8291), so the server log carries the trace lines quoted in run I;
     the lab directory is shortened to <lab>. The scripts are `redelivery-runG.sh`, `redelivery-runI.sh`,
     `redelivery-runH.sh`, `redelivery-runH-batch.py` and `redelivery-runH-repeat.sh` in this directory;
     the pull half of run H uses `nats-probe-client.py` (stdlib only) from this directory too. Output
     verbatim; the only edits are the <lab> substitution and the removal of blank lines between commands.
     The source ranges cited at the end are `server/consumer.go` at tag v2.14.6. -->

# Observed on nats-server v2.14.6 — issue #6921's recipe, what a redelivery loop looks like, and a 10 µs ack deadline from `backoff: [10000]`

Runs G, H and I of step 5 of `inbox/plan-the-runnable-scouts-2026-09-02.md` (question-bank rows 14 and
16–19; the gotcha `consumer-keeps-redelivering`), made after reading `raw/gh-issues/issue-6921.md`,
`raw/stackoverflow/so-78603662.md` and the five redelivery summaries already in the wiki. One standalone
server, Apple silicon, macOS. **Every number is one laptop**, and every timing is a localhost round
trip — evidence of a *mechanism*, never of a figure to size by.

- **Run G** — issue #6921's own reproduction recipe (a `last_per_subject` consumer with explicit acks on
  a stream with `max_msgs_per_subject: 5`), which stalled on 2.11.1 and 2.11.4 and was bisected by a
  second reporter to be fixed in 2.11.5: does it reproduce on 2.14.6?
- **Run I** — what a redelivery loop looks like from the outside: the CLI's `tries:`, `nats consumer
  info`, the JSON counters, and what the server log holds at the default level and at `-DV`.
- **Run H** — the Stack Overflow #78603662 shape: a consumer created with `backoff: [10000]` and
  `max_deliver: 2`, the numbers the poster's .NET code sent, with the pull half done the way a consume
  loop does it (a large batch kept open, every message acked).

## Run G — issue #6921's recipe on 2.14.6: no stall

The reporter's `docker` recipe (comment of 2025-06-06) has the stream and the ten publishes as `nats`
CLI lines; the consumer is the C# and Rust configuration that failed — `DeliverPolicy: LastPerSubject`,
`AckPolicy: Explicit`, `FilterSubject: ">"`, `MaxAckPending: 1` — and the `--max-deliver 3 --wait 30s`
of the reporter's 2.11.4 `nats consumer info`. On 2.11.4 the floor stuck at consumer sequence 1 after
the first ack. On 2.14.6 the five last-per-subject messages are delivered once each, the floor follows
every ack to 5 / 10, and the sixth pull times out with nothing left:

```
nats-server: v2.14.6
0.4.0

$ nats stream add FIVE --subjects five.> --max-msgs-per-subject=5 --max-age 1h --storage file --defaults
Stream FIVE was created

Information for Stream FIVE created 2026-09-03 00:33:59

                     Subjects: five.>
                     Replicas: 1
                      Storage: File

Options:

                    Retention: Limits
              Acknowledgments: true
               Discard Policy: Old
             Duplicate Window: 2m0s
                   Direct Get: true
  Allows Atomic Batch Publish: false
    Allows Fast Batch Publish: false
              Allows Counters: false
            Allows Msg Delete: true
       Allows Per-Message TTL: false
                 Allows Purge: true
             Allows Schedules: false
               Allows Rollups: false

Limits:

             Maximum Messages: unlimited
          Maximum Per Subject: 5
                Maximum Bytes: unlimited
                  Maximum Age: 1h0m0s
         Maximum Message Size: unlimited
            Maximum Consumers: unlimited

State:

                 Host Version: 2.14.6
           Required API Level: 0 hosted at level 4
                     Messages: 0
                        Bytes: 0 B
               First Sequence: 0
                Last Sequence: 0
             Active Consumers: 0

$ nats pub five.1 1
00:33:59 Published 1 bytes to "five.1"

$ nats pub five.1 2
00:33:59 Published 1 bytes to "five.1"

$ nats pub five.2 1
00:33:59 Published 1 bytes to "five.2"

$ nats pub five.2 2
00:33:59 Published 1 bytes to "five.2"

$ nats pub five.3 1
00:33:59 Published 1 bytes to "five.3"

$ nats pub five.3 2
00:33:59 Published 1 bytes to "five.3"

$ nats pub five.4 1
00:33:59 Published 1 bytes to "five.4"

$ nats pub five.4 2
00:33:59 Published 1 bytes to "five.4"

$ nats pub five.5 1
00:33:59 Published 1 bytes to "five.5"

$ nats pub five.5 2
00:33:59 Published 1 bytes to "five.5"

$ nats stream info FIVE
Information for Stream FIVE created 2026-09-03 00:33:59

                     Subjects: five.>
                     Replicas: 1
                      Storage: File

Options:

                    Retention: Limits
              Acknowledgments: true
               Discard Policy: Old
             Duplicate Window: 2m0s
                   Direct Get: true
  Allows Atomic Batch Publish: false
    Allows Fast Batch Publish: false
              Allows Counters: false
            Allows Msg Delete: true
       Allows Per-Message TTL: false
                 Allows Purge: true
             Allows Schedules: false
               Allows Rollups: false

Limits:

             Maximum Messages: unlimited
          Maximum Per Subject: 5
                Maximum Bytes: unlimited
                  Maximum Age: 1h0m0s
         Maximum Message Size: unlimited
            Maximum Consumers: unlimited

State:

                 Host Version: 2.14.6
           Required API Level: 0 hosted at level 4
                     Messages: 10
                        Bytes: 370 B
               First Sequence: 1 @ 2026-09-03 00:33:59
                Last Sequence: 10 @ 2026-09-03 00:33:59
             Active Consumers: 0
           Number of Subjects: 5

$ nats consumer add FIVE Consumer --pull --deliver subject --filter > --ack explicit --max-pending 1 --max-deliver 3 --wait 30s --defaults
Information for Consumer FIVE > Consumer created 2026-09-03 00:33:59

Configuration:

                    Name: Consumer
               Pull Mode: true
          Filter Subject: >
          Deliver Policy: Last Per Subject
              Ack Policy: Explicit
                Ack Wait: 30.00s
           Replay Policy: Instant
      Maximum Deliveries: 3
         Max Ack Pending: 1
       Max Waiting Pulls: 512

State:

            Host Version: 2.14.6
      Required API Level: 0 hosted at level 4
  Last Delivered Message: Consumer sequence: 0 Stream sequence: 1
    Acknowledgment Floor: Consumer sequence: 0 Stream sequence: 1
        Outstanding Acks: 0 out of maximum 1
    Redelivered Messages: 0
    Unprocessed Messages: 5
           Waiting Pulls: 0 of maximum 512

$ nats consumer next FIVE Consumer --ack --timeout 3s
[00:33:59] subj: five.1 / tries: 1 / cons seq: 1 / str seq: 2 / pending: 4

2

Acknowledged message

$ nats consumer next FIVE Consumer --ack --timeout 3s
[00:33:59] subj: five.2 / tries: 1 / cons seq: 2 / str seq: 4 / pending: 3

2

Acknowledged message

$ nats consumer next FIVE Consumer --ack --timeout 3s
[00:33:59] subj: five.3 / tries: 1 / cons seq: 3 / str seq: 6 / pending: 2

2

Acknowledged message

$ nats consumer next FIVE Consumer --ack --timeout 3s
[00:33:59] subj: five.4 / tries: 1 / cons seq: 4 / str seq: 8 / pending: 1

2

Acknowledged message

$ nats consumer next FIVE Consumer --ack --timeout 3s
[00:33:59] subj: five.5 / tries: 1 / cons seq: 5 / str seq: 10 / pending: 0

2

Acknowledged message

$ nats consumer next FIVE Consumer --ack --timeout 3s
nats: error: no message received: nats: timeout

$ nats consumer info FIVE Consumer
Information for Consumer FIVE > Consumer created 2026-09-03 00:33:59

Configuration:

                    Name: Consumer
               Pull Mode: true
          Filter Subject: >
          Deliver Policy: Last Per Subject
              Ack Policy: Explicit
                Ack Wait: 30.00s
           Replay Policy: Instant
      Maximum Deliveries: 3
         Max Ack Pending: 1
       Max Waiting Pulls: 512

State:

            Host Version: 2.14.6
      Required API Level: 0 hosted at level 4
  Last Delivered Message: Consumer sequence: 5 Stream sequence: 10 Last delivery: 3.06s ago
    Acknowledgment Floor: Consumer sequence: 5 Stream sequence: 10 Last Ack: 3.06s ago
        Outstanding Acks: 0 out of maximum 1
    Redelivered Messages: 0
    Unprocessed Messages: 0
           Waiting Pulls: 0 of maximum 512```

Read against the reporter's 2.11.4 output: `Acknowledgment Floor: Consumer sequence: 5 Stream sequence:
10` here against `Consumer sequence: 1` there with `Last Ack: 56.18s ago`; `Redelivered Messages: 0`
here against `1` there; `Unprocessed Messages: 0` here against `70,382` there. The defect does not
reproduce on 2.14.6, as the v2.11.5 release notes (#7005) and the second reporter's bisect say.

## Run I — what a redelivery loop looks like

Three messages, a pull consumer with `ack_wait: 2s`, `max_deliver: -1` (the default), fetched with
`--no-ack` twice, three seconds apart, then acked:

```

$ nats stream add LOOP --subjects loop.> --storage file --defaults
Stream LOOP was created

Information for Stream LOOP created 2026-09-03 00:34:29

                     Subjects: loop.>
                     Replicas: 1
                      Storage: File

Options:

                    Retention: Limits
              Acknowledgments: true
               Discard Policy: Old
             Duplicate Window: 2m0s
                   Direct Get: true
  Allows Atomic Batch Publish: false
    Allows Fast Batch Publish: false
              Allows Counters: false
            Allows Msg Delete: true
       Allows Per-Message TTL: false
                 Allows Purge: true
             Allows Schedules: false
               Allows Rollups: false

Limits:

             Maximum Messages: unlimited
          Maximum Per Subject: unlimited
                Maximum Bytes: unlimited
                  Maximum Age: unlimited
         Maximum Message Size: unlimited
            Maximum Consumers: unlimited

State:

                 Host Version: 2.14.6
           Required API Level: 0 hosted at level 4
                     Messages: 0
                        Bytes: 0 B
               First Sequence: 0
                Last Sequence: 0
             Active Consumers: 0

$ nats pub loop.job job 1
00:34:29 Published 5 bytes to "loop.job"

$ nats pub loop.job job 2
00:34:29 Published 5 bytes to "loop.job"

$ nats pub loop.job job 3
00:34:29 Published 5 bytes to "loop.job"

$ nats consumer add LOOP worker --pull --ack explicit --wait 2s --max-deliver=-1 --max-pending 1000 --deliver all --filter loop.> --defaults
Information for Consumer LOOP > worker created 2026-09-03 00:34:29

Configuration:

                    Name: worker
               Pull Mode: true
          Filter Subject: loop.>
          Deliver Policy: All
              Ack Policy: Explicit
                Ack Wait: 2.00s
           Replay Policy: Instant
         Max Ack Pending: 1,000
       Max Waiting Pulls: 512

State:

            Host Version: 2.14.6
      Required API Level: 0 hosted at level 4
  Last Delivered Message: Consumer sequence: 0 Stream sequence: 0
    Acknowledgment Floor: Consumer sequence: 0 Stream sequence: 0
        Outstanding Acks: 0 out of maximum 1,000
    Redelivered Messages: 0
    Unprocessed Messages: 3
           Waiting Pulls: 0 of maximum 512

### first pass — fetch three, ack nothing

$ nats consumer next LOOP worker --no-ack --timeout 3s
[00:34:29] subj: loop.job / tries: 1 / cons seq: 1 / str seq: 1 / pending: 2

job 1

$ nats consumer next LOOP worker --no-ack --timeout 3s
[00:34:29] subj: loop.job / tries: 1 / cons seq: 2 / str seq: 2 / pending: 1

job 2

$ nats consumer next LOOP worker --no-ack --timeout 3s
[00:34:29] subj: loop.job / tries: 1 / cons seq: 3 / str seq: 3 / pending: 0

job 3

$ nats consumer info LOOP worker
Information for Consumer LOOP > worker created 2026-09-03 00:34:29

Configuration:

                    Name: worker
               Pull Mode: true
          Filter Subject: loop.>
          Deliver Policy: All
              Ack Policy: Explicit
                Ack Wait: 2.00s
           Replay Policy: Instant
         Max Ack Pending: 1,000
       Max Waiting Pulls: 512

State:

            Host Version: 2.14.6
      Required API Level: 0 hosted at level 4
  Last Delivered Message: Consumer sequence: 3 Stream sequence: 3 Last delivery: 10ms ago
    Acknowledgment Floor: Consumer sequence: 0 Stream sequence: 0
        Outstanding Acks: 3 out of maximum 1,000
    Redelivered Messages: 0
    Unprocessed Messages: 0
           Waiting Pulls: 0 of maximum 512

### sleep 3 (ack_wait is 2s), then fetch again

$ nats consumer next LOOP worker --no-ack --timeout 3s
[00:34:32] subj: loop.job / tries: 2 / cons seq: 4 / str seq: 1 / pending: 0

job 1

$ nats consumer next LOOP worker --no-ack --timeout 3s
[00:34:32] subj: loop.job / tries: 2 / cons seq: 5 / str seq: 2 / pending: 0

job 2

$ nats consumer next LOOP worker --no-ack --timeout 3s
[00:34:32] subj: loop.job / tries: 2 / cons seq: 6 / str seq: 3 / pending: 0

job 3

$ nats consumer info LOOP worker
Information for Consumer LOOP > worker created 2026-09-03 00:34:29

Configuration:

                    Name: worker
               Pull Mode: true
          Filter Subject: loop.>
          Deliver Policy: All
              Ack Policy: Explicit
                Ack Wait: 2.00s
           Replay Policy: Instant
         Max Ack Pending: 1,000
       Max Waiting Pulls: 512

State:

            Host Version: 2.14.6
      Required API Level: 0 hosted at level 4
  Last Delivered Message: Consumer sequence: 6 Stream sequence: 3 Last delivery: 11ms ago
    Acknowledgment Floor: Consumer sequence: 0 Stream sequence: 0
        Outstanding Acks: 3 out of maximum 1,000
    Redelivered Messages: 3
    Unprocessed Messages: 0
           Waiting Pulls: 0 of maximum 512

$ nats consumer info LOOP worker --json | jq ...
{"num_ack_pending":3,"num_redelivered":3,"num_pending":0,"ack_floor":{"consumer_seq":0,"stream_seq":0},"delivered":{"consumer_seq":6,"stream_seq":3,"last_active":"2026-09-02T22:34:32.813336Z"}}

### the server log: lines mentioning LOOP or loop.job at INF/WRN/ERR level, then the trace
$ grep -E '\[(INF|WRN|ERR)\]' n1.log | grep -c 'LOOP\|loop.job'
0
$ grep -E 'loop.job|JS.ACK.LOOP' n1.log | head -14
[4917] 2026/09/03 00:34:02.301099 [TRC] 127.0.0.1:62403 - cid:34 - "v1.51.0:go:NATS CLI Version 0.4.0" - "$G/user:nats-ja6GUvFT" - <<- [PUB loop.job 5]
[4917] 2026/09/03 00:34:02.313207 [TRC] 127.0.0.1:62404 - cid:35 - "v1.51.0:go:NATS CLI Version 0.4.0" - "$G/user:nats-ja6GUvFT" - <<- [PUB loop.job 5]
[4917] 2026/09/03 00:34:02.323666 [TRC] 127.0.0.1:62405 - cid:36 - "v1.51.0:go:NATS CLI Version 0.4.0" - "$G/user:nats-ja6GUvFT" - <<- [PUB loop.job 5]
[4917] 2026/09/03 00:34:29.654847 [TRC] 127.0.0.1:62430 - cid:55 - "v1.51.0:go:NATS CLI Version 0.4.0" - "$G/user:nats-ja6GUvFT" - <<- [PUB loop.job 5]
[4917] 2026/09/03 00:34:29.665109 [TRC] 127.0.0.1:62431 - cid:56 - "v1.51.0:go:NATS CLI Version 0.4.0" - "$G/user:nats-ja6GUvFT" - <<- [PUB loop.job 5]
[4917] 2026/09/03 00:34:29.675573 [TRC] 127.0.0.1:62432 - cid:57 - "v1.51.0:go:NATS CLI Version 0.4.0" - "$G/user:nats-ja6GUvFT" - <<- [PUB loop.job 5]
[4917] 2026/09/03 00:34:29.701282 [TRC] 127.0.0.1:62434 - cid:61 - "v1.51.0:go:NATS CLI Version 0.4.0" - "$G/user:nats-ja6GUvFT" - ->> [MSG loop.job 2 $JS.ACK.LOOP.worker.1.1.1.1788388469654945000.2 5]
[4917] 2026/09/03 00:34:29.712678 [TRC] 127.0.0.1:62435 - cid:62 - "v1.51.0:go:NATS CLI Version 0.4.0" - "$G/user:nats-ja6GUvFT" - ->> [MSG loop.job 2 $JS.ACK.LOOP.worker.1.2.2.1788388469665140000.1 5]
[4917] 2026/09/03 00:34:29.724899 [TRC] 127.0.0.1:62436 - cid:63 - "v1.51.0:go:NATS CLI Version 0.4.0" - "$G/user:nats-ja6GUvFT" - ->> [MSG loop.job 2 $JS.ACK.LOOP.worker.1.3.3.1788388469675607000.0 5]
[4917] 2026/09/03 00:34:32.778658 [TRC] 127.0.0.1:62439 - cid:65 - "v1.51.0:go:NATS CLI Version 0.4.0" - "$G/user:nats-ja6GUvFT" - ->> [MSG loop.job 2 $JS.ACK.LOOP.worker.2.1.4.1788388469654945000.0 5]
[4917] 2026/09/03 00:34:32.798484 [TRC] 127.0.0.1:62440 - cid:66 - "v1.51.0:go:NATS CLI Version 0.4.0" - "$G/user:nats-ja6GUvFT" - ->> [MSG loop.job 2 $JS.ACK.LOOP.worker.2.2.5.1788388469665140000.0 5]
[4917] 2026/09/03 00:34:32.813346 [TRC] 127.0.0.1:62441 - cid:67 - "v1.51.0:go:NATS CLI Version 0.4.0" - "$G/user:nats-ja6GUvFT" - ->> [MSG loop.job 2 $JS.ACK.LOOP.worker.2.3.6.1788388469675607000.0 5]

### ack them

$ nats consumer next LOOP worker --ack --timeout 3s
[00:34:34] subj: loop.job / tries: 3 / cons seq: 7 / str seq: 1 / pending: 0

job 1

Acknowledged message

$ nats consumer next LOOP worker --ack --timeout 3s
[00:34:34] subj: loop.job / tries: 3 / cons seq: 8 / str seq: 2 / pending: 0

job 2

Acknowledged message

$ nats consumer next LOOP worker --ack --timeout 3s
[00:34:34] subj: loop.job / tries: 3 / cons seq: 9 / str seq: 3 / pending: 0

job 3

Acknowledged message

$ nats consumer info LOOP worker
Information for Consumer LOOP > worker created 2026-09-03 00:34:29

Configuration:

                    Name: worker
               Pull Mode: true
          Filter Subject: loop.>
          Deliver Policy: All
              Ack Policy: Explicit
                Ack Wait: 2.00s
           Replay Policy: Instant
         Max Ack Pending: 1,000
       Max Waiting Pulls: 512

State:

            Host Version: 2.14.6
      Required API Level: 0 hosted at level 4
  Last Delivered Message: Consumer sequence: 9 Stream sequence: 3 Last delivery: 13ms ago
    Acknowledgment Floor: Consumer sequence: 9 Stream sequence: 3 Last Ack: 13ms ago
        Outstanding Acks: 0 out of maximum 1,000
    Redelivered Messages: 0
    Unprocessed Messages: 0
           Waiting Pulls: 0 of maximum 512```

What to read off it:

- **`tries:` is the delivery count**, printed by the CLI from the message's own reply subject. The
  reply subject is `$JS.ACK.<stream>.<consumer>.<delivered>.<stream seq>.<consumer seq>.<timestamp>.<pending>`,
  and the `-DV` trace shows it verbatim on every delivery: `$JS.ACK.LOOP.worker.1.1.1.…` the first
  time, `$JS.ACK.LOOP.worker.2.1.4.…` the second — delivery 2 of stream sequence 1, as consumer
  sequence 4. The consumer sequence keeps counting (1–3, then 4–6, then 7–9); the stream sequence
  repeats.
- **`nats consumer info` shows the loop as three numbers that do not move together**: `Last Delivered
  Message: Consumer sequence: 6 Stream sequence: 3` climbing, `Acknowledgment Floor: Consumer sequence:
  0 Stream sequence: 0` not moving, `Outstanding Acks: 3` flat, `Redelivered Messages: 3`. In JSON:
  `num_ack_pending: 3, num_redelivered: 3, ack_floor.stream_seq: 0, delivered.consumer_seq: 6`.
- **The server log says nothing.** Zero lines at `INF`, `WRN` or `ERR` mention the stream or the
  subject across the whole run; redelivery is not an event the server logs. At `-DV` the deliveries are
  the `->> [MSG loop.job …]` trace lines above, and the acks that never came would have been
  `<<- [PUB $JS.ACK.LOOP.worker.…]` lines from the client.
- **Acking clears it**: after the third pass, `Outstanding Acks: 0`, `Redelivered Messages: 0`, the
  floor at 9 / 3. `num_redelivered` counts messages currently tracked as delivered more than once, not
  a lifetime tally.

## Run H — `backoff: [10000]` is a 10 µs ack deadline

Stack Overflow #78603662 (2024-06-10, .NET, unanswered): ten messages, a consumer with
`MaxDeliver = 2` and `Backoff = [10000]`, every message acked, every message processed twice; a higher
`MaxDeliver` meant more times; no `MaxDeliver` meant once. The wiki's rule from the earlier nak run —
*the first backoff entry becomes `ack_wait`* — makes this a deadline question: the JetStream API takes
durations in nanoseconds, so `10000` is ten microseconds.

### H.1 — the consumer, created through the raw API with the poster's numbers

```
Stream sample-new was created
00:35:01 Published 9 bytes to "test.new.first"
00:35:01 Published 9 bytes to "test.new.first"
00:35:01 Published 9 bytes to "test.new.first"
00:35:01 Published 9 bytes to "test.new.first"
00:35:01 Published 9 bytes to "test.new.first"
00:35:01 Published 9 bytes to "test.new.first"
00:35:01 Published 9 bytes to "test.new.first"
00:35:01 Published 9 bytes to "test.new.first"
00:35:01 Published 9 bytes to "test.new.first"
00:35:01 Published 9 bytes to "test.new.first"
published 10 messages to test.new.first

$ nats req '$JS.API.CONSUMER.CREATE.sample-new.first-new-consumer' '{..."max_deliver":2,"backoff":[10000]}' | jq .config
{"ack_wait":10000,"max_deliver":2,"backoff":[10000],"ack_policy":"explicit","deliver_policy":"all"}
Configuration:

                    Name: first-new-consumer
               Pull Mode: true
          Deliver Policy: All
              Ack Policy: Explicit
                Ack Wait: 10µs
           Replay Policy: Instant
      Maximum Deliveries: 2
         Max Ack Pending: 1,000
       Max Waiting Pulls: 512

### the same config with max_deliver omitted
$ nats req '$JS.API.CONSUMER.CREATE.sample-new.nomax' '{..."backoff":[10000]}' | jq
{"ack_wait":10000,"max_deliver":-1,"backoff":[10000]}

### and with max_deliver: 1 (the backoff list is as long as the limit)
{"ack_wait":10000,"max_deliver":1,"backoff":[10000]}```

The server stores `ack_wait: 10000` — nanoseconds — and the CLI prints it as **`Ack Wait: 10µs`**.
With `max_deliver` omitted it becomes `-1`, unlimited; with `max_deliver: 1` against a one-entry
backoff the create is accepted too.

### H.2 — the pull half, acked on arrival: a race the ack usually wins on localhost

`redelivery-runH-batch.py`: one pull of `batch: 100` with `expires: 3s`, every message acked the moment
it arrives, deliveries counted per stream sequence from the reply subject. `ctl` is the control, the
same consumer with `ack_wait: 30s` and no backoff. First pass, against the consumers created in H.1 a
minute earlier:

```

### sample-new / first-new-consumer: pull batch=100 expires=3s, acked on arrival
  t= 0.0003s  test.new.first   sseq=1   delivered=1  message 0
  t= 0.0003s  test.new.first   sseq=2   delivered=1  message 1
  t= 0.0004s  test.new.first   sseq=3   delivered=1  message 2
  t= 0.0004s  test.new.first   sseq=4   delivered=1  message 3
  t= 0.0004s  test.new.first   sseq=5   delivered=1  message 4
  t= 0.0004s  test.new.first   sseq=6   delivered=1  message 5
  t= 0.0004s  test.new.first   sseq=7   delivered=1  message 6
  t= 0.0004s  test.new.first   sseq=8   delivered=1  message 7
  t= 0.0004s  test.new.first   sseq=9   delivered=1  message 8
  t= 0.0004s  test.new.first   sseq=10  delivered=1  message 9
  t= 3.0012s  _INBOX.runH.first-new-consumer status NATS/1.0 408 Request Timeout | Nats-Pending-Messages: 90 | Nats-Pending-Bytes: 0
  => 10 deliveries of 10 messages; deliveries per message: 1x for 10 msgs

### sample-new / nomax: pull batch=100 expires=3s, acked on arrival
  t= 0.0018s  test.new.first   sseq=1   delivered=1  message 0
  t= 0.0018s  test.new.first   sseq=2   delivered=1  message 1
  t= 0.0018s  test.new.first   sseq=3   delivered=1  message 2
  t= 0.0019s  test.new.first   sseq=4   delivered=1  message 3
  t= 0.0019s  test.new.first   sseq=5   delivered=1  message 4
  t= 0.0019s  test.new.first   sseq=6   delivered=1  message 5
  t= 0.0019s  test.new.first   sseq=7   delivered=1  message 6
  t= 0.0019s  test.new.first   sseq=8   delivered=1  message 7
  t= 0.0019s  test.new.first   sseq=9   delivered=1  message 8
  t= 0.0020s  test.new.first   sseq=10  delivered=1  message 9
  t= 0.0032s  test.new.first   sseq=1   delivered=2  message 0
  t= 0.0032s  test.new.first   sseq=2   delivered=2  message 1
  t= 0.0032s  test.new.first   sseq=3   delivered=2  message 2
  t= 0.0033s  test.new.first   sseq=4   delivered=2  message 3
  t= 0.0033s  test.new.first   sseq=5   delivered=2  message 4
  t= 0.0033s  test.new.first   sseq=6   delivered=2  message 5
  t= 0.0033s  test.new.first   sseq=7   delivered=2  message 6
  t= 0.0033s  test.new.first   sseq=8   delivered=2  message 7
  t= 0.0033s  test.new.first   sseq=9   delivered=2  message 8
  t= 0.0033s  test.new.first   sseq=10  delivered=2  message 9
  t= 0.0034s  test.new.first   sseq=1   delivered=3  message 0
  t= 0.0034s  test.new.first   sseq=2   delivered=3  message 1
  t= 0.0034s  test.new.first   sseq=3   delivered=3  message 2
  t= 0.0034s  test.new.first   sseq=4   delivered=3  message 3
  t= 0.0034s  test.new.first   sseq=5   delivered=3  message 4
  t= 0.0034s  test.new.first   sseq=6   delivered=3  message 5
  t= 0.0034s  test.new.first   sseq=7   delivered=3  message 6
  t= 0.0034s  test.new.first   sseq=8   delivered=3  message 7
  t= 0.0035s  test.new.first   sseq=9   delivered=3  message 8
  t= 0.0052s  test.new.first   sseq=1   delivered=4  message 0
  t= 0.0053s  test.new.first   sseq=2   delivered=4  message 1
  t= 0.0053s  test.new.first   sseq=3   delivered=4  message 2
  t= 0.0053s  test.new.first   sseq=4   delivered=4  message 3
  t= 0.0053s  test.new.first   sseq=5   delivered=4  message 4
  t= 0.0053s  test.new.first   sseq=6   delivered=4  message 5
  t= 0.0053s  test.new.first   sseq=7   delivered=4  message 6
  t= 0.0053s  test.new.first   sseq=8   delivered=4  message 7
  t= 0.0053s  test.new.first   sseq=10  delivered=3  message 9
  t= 0.0053s  test.new.first   sseq=9   delivered=4  message 8
  t= 0.0053s  test.new.first   sseq=5   delivered=5  message 4
  t= 0.0053s  test.new.first   sseq=6   delivered=5  message 5
  t= 0.0053s  test.new.first   sseq=7   delivered=5  message 6
  t= 0.0053s  test.new.first   sseq=8   delivered=5  message 7
  t= 0.0053s  test.new.first   sseq=9   delivered=5  message 8
  t= 0.0053s  test.new.first   sseq=10  delivered=4  message 9
  t= 0.0053s  test.new.first   sseq=5   delivered=6  message 4
  t= 0.0053s  test.new.first   sseq=6   delivered=6  message 5
  t= 0.0054s  test.new.first   sseq=7   delivered=6  message 6
  t= 0.0054s  test.new.first   sseq=8   delivered=6  message 7
  t= 0.0054s  test.new.first   sseq=9   delivered=6  message 8
  t= 0.0054s  test.new.first   sseq=10  delivered=5  message 9
  t= 0.0054s  test.new.first   sseq=5   delivered=7  message 4
  t= 0.0054s  test.new.first   sseq=6   delivered=7  message 5
  t= 0.0054s  test.new.first   sseq=7   delivered=7  message 6
  t= 0.0054s  test.new.first   sseq=8   delivered=7  message 7
  t= 0.0054s  test.new.first   sseq=9   delivered=7  message 8
  t= 0.0054s  test.new.first   sseq=5   delivered=8  message 4
  t= 0.0054s  test.new.first   sseq=6   delivered=8  message 5
  t= 0.0054s  test.new.first   sseq=7   delivered=8  message 6
  t= 0.0054s  test.new.first   sseq=8   delivered=8  message 7
  t= 0.0054s  test.new.first   sseq=10  delivered=6  message 9
  t= 0.0054s  test.new.first   sseq=9   delivered=8  message 8
  t= 0.0054s  test.new.first   sseq=5   delivered=9  message 4
  t= 0.0054s  test.new.first   sseq=6   delivered=9  message 5
  t= 0.0054s  test.new.first   sseq=7   delivered=9  message 6
  t= 0.0054s  test.new.first   sseq=8   delivered=9  message 7
  t= 0.0055s  test.new.first   sseq=9   delivered=9  message 8
  t= 0.0055s  test.new.first   sseq=10  delivered=7  message 9
  t= 0.0055s  test.new.first   sseq=5   delivered=10  message 4
  t= 0.0055s  test.new.first   sseq=6   delivered=10  message 5
  t= 0.0055s  test.new.first   sseq=7   delivered=10  message 6
  t= 0.0055s  test.new.first   sseq=8   delivered=10  message 7
  t= 0.0055s  test.new.first   sseq=9   delivered=10  message 8
  t= 0.0055s  test.new.first   sseq=10  delivered=8  message 9
  t= 0.0055s  test.new.first   sseq=5   delivered=11  message 4
  t= 0.0055s  test.new.first   sseq=6   delivered=11  message 5
  t= 0.0055s  test.new.first   sseq=7   delivered=11  message 6
  t= 0.0056s  test.new.first   sseq=8   delivered=11  message 7
  t= 0.0056s  test.new.first   sseq=9   delivered=11  message 8
  t= 0.0056s  test.new.first   sseq=10  delivered=9  message 9
  t= 0.0056s  test.new.first   sseq=5   delivered=12  message 4
  t= 0.0056s  test.new.first   sseq=6   delivered=12  message 5
  t= 0.0056s  test.new.first   sseq=7   delivered=12  message 6
  t= 0.0056s  test.new.first   sseq=8   delivered=12  message 7
  t= 0.0056s  test.new.first   sseq=9   delivered=12  message 8
  t= 0.0057s  test.new.first   sseq=5   delivered=13  message 4
  t= 0.0057s  test.new.first   sseq=6   delivered=13  message 5
  t= 0.0057s  test.new.first   sseq=7   delivered=13  message 6
  t= 0.0057s  test.new.first   sseq=8   delivered=13  message 7
  t= 0.0057s  test.new.first   sseq=10  delivered=10  message 9
  t= 0.0057s  test.new.first   sseq=9   delivered=13  message 8
  t= 0.0057s  test.new.first   sseq=5   delivered=14  message 4
  t= 0.0057s  test.new.first   sseq=6   delivered=14  message 5
  t= 0.0058s  test.new.first   sseq=7   delivered=14  message 6
  t= 0.0058s  test.new.first   sseq=8   delivered=14  message 7
  t= 0.0058s  test.new.first   sseq=9   delivered=14  message 8
  t= 0.0058s  test.new.first   sseq=10  delivered=11  message 9
  t= 0.0058s  test.new.first   sseq=5   delivered=15  message 4
  t= 0.0058s  test.new.first   sseq=6   delivered=15  message 5
  t= 0.0058s  test.new.first   sseq=7   delivered=15  message 6
  => 100 deliveries of 10 messages; deliveries per message: 4x for 4 msgs, 11x for 1 msgs, 14x for 2 msgs, 15x for 3 msgs

### sample-new / ctl: pull batch=100 expires=3s, acked on arrival
  t= 0.0009s  test.new.first   sseq=1   delivered=1  message 0
  t= 0.0009s  test.new.first   sseq=2   delivered=1  message 1
  t= 0.0010s  test.new.first   sseq=3   delivered=1  message 2
  t= 0.0010s  test.new.first   sseq=4   delivered=1  message 3
  t= 0.0010s  test.new.first   sseq=5   delivered=1  message 4
  t= 0.0010s  test.new.first   sseq=6   delivered=1  message 5
  t= 0.0011s  test.new.first   sseq=7   delivered=1  message 6
  t= 0.0011s  test.new.first   sseq=8   delivered=1  message 7
  t= 0.0012s  test.new.first   sseq=9   delivered=1  message 8
  t= 0.0012s  test.new.first   sseq=10  delivered=1  message 9
  t= 3.0013s  _INBOX.runH.ctl  status NATS/1.0 408 Request Timeout | Nats-Pending-Messages: 90 | Nats-Pending-Bytes: 0
  => 10 deliveries of 10 messages; deliveries per message: 1x for 10 msgs
-- first-new-consumer
{"num_ack_pending":0,"num_redelivered":0,"num_pending":0,"ack_floor":10,"delivered":10}
-- nomax
{"num_ack_pending":0,"num_redelivered":0,"num_pending":0,"ack_floor":10,"delivered":100}
-- ctl
{"num_ack_pending":0,"num_redelivered":0,"num_pending":0,"ack_floor":10,"delivered":10}```

The `nomax` consumer redelivered the same ten messages **ninety times in six milliseconds** — delivery
counts up to 15 on one message — until the pull's batch of 100 was used up, and then its state was
clean (`num_ack_pending: 0`, floor 10, `delivered: 100`). The `max_deliver: 2` consumer beside it, same
deadline, redelivered nothing. Six fresh repeats — the consumer deleted and recreated through the API
before every pull, three pulls per shape, batch 100 and then batch 10 (`redelivery-runH-repeat.sh`):

```
batch=100 first-new-consumer #1  cfg={"ack_wait":10000,"max_deliver":2}
  t= 3.0011s  _INBOX.runH.first-new-consumer status NATS/1.0 408 Request Timeout | Nats-Pending-Messages: 90 | Nats-Pending-Bytes: 0
  => 10 deliveries of 10 messages; deliveries per message: 1x for 10 msgs
batch=100 first-new-consumer #2  cfg={"ack_wait":10000,"max_deliver":2}
  t= 3.0015s  _INBOX.runH.first-new-consumer status NATS/1.0 408 Request Timeout | Nats-Pending-Messages: 90 | Nats-Pending-Bytes: 0
  => 10 deliveries of 10 messages; deliveries per message: 1x for 10 msgs
batch=100 first-new-consumer #3  cfg={"ack_wait":10000,"max_deliver":2}
  t= 3.0013s  _INBOX.runH.first-new-consumer status NATS/1.0 408 Request Timeout | Nats-Pending-Messages: 90 | Nats-Pending-Bytes: 0
  => 10 deliveries of 10 messages; deliveries per message: 1x for 10 msgs
batch=100 nomax #1  cfg={"ack_wait":10000,"max_deliver":-1}
  t= 3.0019s  _INBOX.runH.nomax status NATS/1.0 408 Request Timeout | Nats-Pending-Messages: 90 | Nats-Pending-Bytes: 0
  => 10 deliveries of 10 messages; deliveries per message: 1x for 10 msgs
batch=100 nomax #2  cfg={"ack_wait":10000,"max_deliver":-1}
  t= 3.0008s  _INBOX.runH.nomax status NATS/1.0 408 Request Timeout | Nats-Pending-Messages: 90 | Nats-Pending-Bytes: 0
  => 10 deliveries of 10 messages; deliveries per message: 1x for 10 msgs
batch=100 nomax #3  cfg={"ack_wait":10000,"max_deliver":-1}
  t= 3.0019s  _INBOX.runH.nomax status NATS/1.0 408 Request Timeout | Nats-Pending-Messages: 90 | Nats-Pending-Bytes: 0
  => 10 deliveries of 10 messages; deliveries per message: 1x for 10 msgs
batch=10 first-new-consumer #1  cfg={"ack_wait":10000,"max_deliver":2}
  => 10 deliveries of 10 messages; deliveries per message: 1x for 10 msgs
batch=10 first-new-consumer #2  cfg={"ack_wait":10000,"max_deliver":2}
  => 10 deliveries of 10 messages; deliveries per message: 1x for 10 msgs
batch=10 first-new-consumer #3  cfg={"ack_wait":10000,"max_deliver":2}
  => 10 deliveries of 10 messages; deliveries per message: 1x for 10 msgs
batch=10 nomax #1  cfg={"ack_wait":10000,"max_deliver":-1}
  => 10 deliveries of 10 messages; deliveries per message: 1x for 10 msgs
batch=10 nomax #2  cfg={"ack_wait":10000,"max_deliver":-1}
  => 10 deliveries of 10 messages; deliveries per message: 1x for 10 msgs
batch=10 nomax #3  cfg={"ack_wait":10000,"max_deliver":-1}
  => 10 deliveries of 10 messages; deliveries per message: 1x for 10 msgs```

Every one of them delivered once. So with the ack sent on arrival, one pull in seven redelivered, and
that one ran away: **a 10 µs deadline makes every delivery a race between the ack's arrival and the
redelivery timer, and on localhost the ack usually wins.** Acks are queued off the connection's read
loop and processed by the consumer's own goroutine (`processInboundAcks`, `consumer.go:5182`, the queue
pushed at `:2778–2779`), while the timer that expires them runs in `checkPending`; which lands first is
scheduling.

### H.3 — the deterministic form: a handler that does 5 ms of work before acking

`ACK_DELAY=0.005`: the client sleeps five milliseconds between receiving a message and acking it — a
handler that does anything at all, or a network with a round trip.

```
### run H, deterministic form: the handler sleeps 5 ms before acking (ACK_DELAY=0.005)
first-new-consumer cfg={"ack_wait":10000,"max_deliver":2,"backoff":[10000]}

### sample-new / first-new-consumer: 1 pull(s) of batch=100 expires=3s, ack after 5 ms
  t= 0.0001s  (pull)           status pull #1: batch=100 expires=3s
  t= 0.0067s  test.new.first   sseq=1   delivered=1  message 0
  t= 0.0131s  test.new.first   sseq=2   delivered=1  message 1
  t= 0.0194s  test.new.first   sseq=3   delivered=1  message 2
  t= 0.0257s  test.new.first   sseq=4   delivered=1  message 3
  t= 0.0319s  test.new.first   sseq=5   delivered=1  message 4
  t= 0.0382s  test.new.first   sseq=6   delivered=1  message 5
  t= 0.0445s  test.new.first   sseq=7   delivered=1  message 6
  t= 0.0508s  test.new.first   sseq=8   delivered=1  message 7
  t= 0.0571s  test.new.first   sseq=9   delivered=1  message 8
  t= 0.0634s  test.new.first   sseq=10  delivered=1  message 9
  t= 0.0697s  test.new.first   sseq=1   delivered=2  message 0
  t= 0.0760s  test.new.first   sseq=2   delivered=2  message 1
  t= 0.0823s  test.new.first   sseq=3   delivered=2  message 2
  t= 0.0885s  test.new.first   sseq=4   delivered=2  message 3
  t= 0.0948s  test.new.first   sseq=5   delivered=2  message 4
  t= 0.1011s  test.new.first   sseq=6   delivered=2  message 5
  t= 0.1074s  test.new.first   sseq=7   delivered=2  message 6
  t= 0.1137s  test.new.first   sseq=8   delivered=2  message 7
  t= 0.1200s  test.new.first   sseq=9   delivered=2  message 8
  t= 0.1263s  test.new.first   sseq=10  delivered=2  message 9
  t= 3.0016s  _INBOX.runH.first-new-consumer status NATS/1.0 408 Request Timeout | Nats-Pending-Messages: 80 | Nats-Pending-Bytes: 0
  => 20 deliveries of 10 messages; deliveries per message: 2x for 10 msgs
nomax cfg={"ack_wait":10000,"max_deliver":-1,"backoff":[10000]}

### sample-new / nomax: 1 pull(s) of batch=100 expires=3s, ack after 5 ms
  t= 0.0000s  (pull)           status pull #1: batch=100 expires=3s
  t= 0.0000s  (pull)           status pull #1: batch=100 expires=3s
  t= 0.0058s  test.new.first   sseq=1   delivered=1  message 0
  => 100 deliveries of 10 messages; deliveries per message: 10x for 10 msgs
ctl cfg={"ack_wait":30000000000,"max_deliver":-1,"backoff":null}

### sample-new / ctl: 1 pull(s) of batch=100 expires=3s, ack after 5 ms
  t= 0.0001s  (pull)           status pull #1: batch=100 expires=3s
  t= 0.0001s  (pull)           status pull #1: batch=100 expires=3s
  t= 3.0014s  _INBOX.runH.ctl  status NATS/1.0 408 Request Timeout | Nats-Pending-Messages: 90 | Nats-Pending-Bytes: 0
  => 10 deliveries of 10 messages; deliveries per message: 1x for 10 msgs

### batch 10, three pulls in a row, 5 ms ack delay
first-new-consumer cfg={"ack_wait":10000,"max_deliver":2,"backoff":[10000]}

### sample-new / first-new-consumer: 3 pull(s) of batch=10 expires=3s, ack after 5 ms
  t= 0.0001s  (pull)           status pull #1: batch=10 expires=3s
  t= 0.0054s  test.new.first   sseq=1   delivered=1  message 0
  t= 0.0105s  test.new.first   sseq=2   delivered=1  message 1
  t= 0.0155s  test.new.first   sseq=3   delivered=1  message 2
  t= 0.0205s  test.new.first   sseq=4   delivered=1  message 3
  t= 0.0256s  test.new.first   sseq=5   delivered=1  message 4
  t= 0.0306s  test.new.first   sseq=6   delivered=1  message 5
  t= 0.0356s  test.new.first   sseq=7   delivered=1  message 6
  t= 0.0407s  test.new.first   sseq=8   delivered=1  message 7
  t= 0.0457s  test.new.first   sseq=9   delivered=1  message 8
  t= 0.0507s  test.new.first   sseq=10  delivered=1  message 9
  t= 0.0507s  (pull)           status pull #2: batch=10 expires=3s
  t= 3.0524s  _INBOX.runH.first-new-consumer status NATS/1.0 408 Request Timeout | Nats-Pending-Messages: 10 | Nats-Pending-Bytes: 0
  t= 3.0526s  (pull)           status pull #3: batch=10 expires=3s
  t= 6.0544s  _INBOX.runH.first-new-consumer status NATS/1.0 408 Request Timeout | Nats-Pending-Messages: 10 | Nats-Pending-Bytes: 0
  => 10 deliveries of 10 messages; deliveries per message: 1x for 10 msgs
-- first-new-consumer
{"num_ack_pending":0,"num_redelivered":0,"num_pending":0,"ack_floor":10,"delivered":10}
-- nomax
{"num_ack_pending":0,"num_redelivered":0,"num_pending":0,"ack_floor":10,"delivered":100}```

Now the timer wins every time:

- **`max_deliver: 2`** — every message delivered **exactly twice**, `delivered=1` for all ten and then
  `delivered=2` for all ten, on the same open pull, every delivery acked. That is the Stack Overflow
  report to the letter: "processes each message twice, despite calling `msg.AckAsync()`".
- **`max_deliver: -1`** — the same ten messages **ten times each**, until the batch of 100 was used up.
  Unlimited deliveries against an unmeetable deadline redeliver as fast as the pull can take them.
- **`ack_wait: 30s`** — once each. The control.
- **Batch 10, three pulls in a row, `max_deliver: 2`** — once each, and pulls 2 and 3 return nothing.
  With the batch exactly the message count, the first pull is satisfied before the timer fires; the
  expired messages go on the redelivery queue, the acks land and clear them, and the next pull finds
  the queue empty. **A redelivery needs a pull waiting at the moment the deadline passes** — which is
  what a consume loop's open pull provides and a one-message-at-a-time `nats consumer next` does not.

The final counters after H.3 were clean in every case: `num_ack_pending: 0`, `num_redelivered: 0`,
`ack_floor: 10`; the only trace of the doubled work is `delivered.consumer_seq` (10 against 100).

## The mechanism, from `server/consumer.go` at v2.14.6

- **`:658`** — `config.AckWait = config.BackOff[0]` under *"If BackOff was specified that will override
  the AckWait and the MaxDeliver"*: the first entry is the ack deadline, in the API's unit.
- **`checkPending`, `:6003–6110`** — for every pending message, `deadline = int64(o.cfg.BackOff[dc])`
  (`:6066`) with `dc` the redelivery count capped at the last entry, and `if elapsed >= deadline`
  (`:6072`) the message goes on the redelivery queue (`:6088`) unless `hasMaxDeliveries` (`:2372`) says
  its delivery count has reached `max_deliver`, in which case it is dropped from pending with the
  advisory. The timer is re-armed with the smallest backoff entry (`:6025`), so a 10 µs deadline is
  re-checked continuously while anything is pending.
- **`processAckMsgLocked`, `:3717–3731`** — under `AckExplicit` an ack deletes `pending[sseq]`, the
  redelivery count and the redelivery-queue entry for that stream sequence **whatever delivery the
  ack names**. The second ack of a doubled message finds nothing pending and does nothing; the floor is
  correct at the end, which is why the counters look clean after H.3.
- **`:2778–2779`, `:5182`** — an inbound ack is pushed onto `o.ackMsgs` and processed by
  `processInboundAcks`, not inline in the connection's read loop; `checkPending` only yields to
  in-flight acks (`o.awl`) when more than 1024 messages are pending (`:6031`), so at ten pending the
  timer and the ack path simply race.

## What was not tested

- No older binary was run: the 2.11.1 / 2.11.4 stall in run G is the reporter's record, and "fixed in
  2.11.5" is the second reporter's bisect plus the v2.11.5 release line, not a run here.
- The .NET client's own serialisation of `Backoff` was not exercised; H.1 sends the poster's number
  straight to the API. Whether NATS.Net at the poster's version passed `10000` through unchanged is
  inferred from the symptom matching H.3, not observed.
- Advisories (`MAX_DELIVERIES` after the `max_deliver: 2` runs) were not captured in this run; the
  advisory on the wire at 2.14.6 is in `nak-backoff-observed-v2.14.6.md`.
