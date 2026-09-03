<!-- source: nats-server v2.14.6 binary, nats CLI 0.4.0, Python 3.14.7, macOS, 2026-09-03 · one standalone server per scene on port 14222 (monitoring 18222), configs written by core-delivery-run.sh beside this file; core-delivery-raw.py beside it is the raw protocol writer; run D6 on the three-node lab of tools/lab/cluster.sh (n1, 4291, user sys) · the transcript is the script's output verbatim except that bash's "Terminated: 15" job-control lines are dropped and the three 200-line tap listings of runs F2, F3 and F5 are collapsed to per-subject counts (marked in place) -->
# nats-server v2.14.6 — core delivery observed: whitespace subjects, `max_payload` with headers, wildcards and pedantic mode, `max_subscription_tokens`, `/subsz`, `nats trace`, account mappings, restart and lame duck

The behavioural half of `core-delivery-v2.14.6.md`, for `wiki/concepts/core-nats-delivery.md` and
`wiki/concepts/subjects-and-wildcards.md` (phase F step 1). Seven runs: **A** the `INFO` line and a space
inside a subject; **B** `max_payload` on the client, on a raw `PUB`, and on an `HPUB` whose header and body
cross it together, plus `no_header_support`; **C** the subscribe- and publish-side subject checks, pedantic
mode, `max_subscription_tokens`; **D** `/subsz` with `test=`, and `nats server request subscriptions` /
`connections` without and with a system-account user; **E** `nats trace`; **F** account-level `mappings`;
**G** a `nats sub` through a server restart and through `--signal ldm`; **F8**, run separately afterwards on the same binary, a wildcard source listed as its own destination. `nc` is used once, for the `INFO`
line, as the docs do; everything else raw goes through `core-delivery-raw.py`, which prints `<<` for what
the server sent and `>>` for what it wrote.

## What each run shows

- **A1** `INFO` from `nc`: `"headers":true`, `"max_payload":1048576`, `"api_lvl":4`, an `xkey`, a
  `client_id`. **A2** a raw `PUB orders.us created 0` is accepted (the `PONG` follows) and the `>` tap
  prints `Received on "orders.us" with reply "created"` — the server read the space as the boundary before a
  reply subject. **A3/A4** `nats pub` and `nats sub` with the same subject fail client-side with
  `nats: error: nats: invalid subject`, exit 1; nothing reached the server. **A5** a `CONNECT` with
  `no_responders: true` and `headers: false` gets `-ERR 'no responders requires headers support'` and the
  socket is closed.
- **B1** a 2 MB `nats pub` fails client-side: `nats: error: nats: maximum payload exceeded`, exit 1. **B2** a
  raw `PUB` of 1,048,577 bytes gets `-ERR 'Maximum Payload Violation'`; the write ends in a broken pipe (the
  server closes on the control line, before the body is read) and the log records
  `maximum payload exceeded: 1048577 vs 1048576`. The helper prints "still open" there because its read ended
  in a reset rather than an EOF; `maxPayloadViolation` closes the connection (`client.go:2555`). **B3**
  exactly 1,048,576 bytes is delivered. **B4** an `HPUB` of 600,000 header bytes and 500,000 body bytes —
  each under the limit, 1,100,000 together — gets the same `-ERR` and `maximum payload exceeded: 1100000 vs
  1048576`: **the header block counts against `max_payload`**. **B5** 600,000 + 400,000 = 1,000,000 is
  delivered, headers and all. **B6** with `no_header_support: true` the `INFO` says `"headers":false` and
  `nats pub -H` fails client-side: `nats: error: nats: headers not supported by this server`. **B7** a
  `CONNECT` asking for headers and `no_responders` against that server is refused with the A5 error.
- **C1** `SUB orders.>.created 1` gets `-ERR 'Invalid Subject'` and the connection stays open (`PONG`).
  **C2** a non-pedantic `PUB orders.*.created 0` is accepted and delivered to `orders.>` and to a subscriber
  on `orders.*.created` (its `*` matches the literal `*` token), not to `orders.us.created`. **C3** the same
  publish from a pedantic `CONNECT` gets `-ERR 'Invalid Publish Subject'` **and is still delivered** to the
  `orders.>` tap; the connection stays open. **C4** an empty token (`orders..created`) is `Invalid Subject`.
  **C5** with `max_subscription_tokens: 3`, `SUB a.b.c.d` gets `-ERR 'Permissions Violation for Subscription
  to "a.b.c.d", too many tokens'` and the log `[ERR] … Subscription Violation Too Many Tokens - Subject
  "a.b.c.d", SID 1`; `SUB a.b.c` is fine; a `PUB a.b.c.d` is delivered to the `a.>` tap — the limit is
  subscriptions only. **C6** a reload with the value changed 3 → 4 is refused: `Failed to reload server
  configuration: config reload not supported for MaxSubTokens: old=3, new=4` — the old limit stays in force.
  **C7** `0` is refused as `max_subscription_tokens value can not be negative`, `256` as `… value is too big`.
- **D1** `/subsz?subs=1&acc=$G&test=orders.us.created` returns `total: 1` and only the `orders.>`
  subscription, while `num_subscriptions: 6` counts everything in `$G`. **D2** the six: four `$SYS.REQ.*`
  service-import subscriptions the server keeps in every account (`$SYS.REQ.SERVER.PING.CONNZ`,
  `$SYS.REQ.USER.INFO`, `$SYS.REQ.ACCOUNT.PING.CONNZ`, `$SYS.REQ.ACCOUNT.PING.STATZ`, all on cid 4), the
  queue subscription with `"qgroup": "packers"`, and the tap. **D3** without `acc=` the count is 62 across
  `$G` and `$SYS`. **D4** with no subscriber `total: 0` and no `subscriptions_list` at all. **D5** on the plain
  server `nats server request subscriptions` fails with `server request failed, ensure the account used has
  system privileges and appropriate permissions` (exit 1) while `nats server request connections` answers
  with the caller's own connection (`"name_tag":"$G"`). **D6** on the lab as `sys`, both answer, one JSON
  reply per node (three).
- **E1** with no interest: `--X No active interest`. **E2** with an `orders.>` subscriber: `--C Client "NATS
  CLI Version 0.4.0" cid:6 subject:"orders.>"` and `Egress Count: Client: 1`, and the subscriber received
  nothing. **E3** `--deliver`: the same route "with delivery to the final destination", and the subscriber
  received the traced message on `orders.us.created` carrying `Nats-Trace-Dest: _INBOX.…` and
  `Accept-Encoding: snappy`, empty body. All three worked on a plain server with no system-account user.
- **F1** the dry runs print `orders.created`, `orders.us.created`, and buckets `0`, `1`, `2` for
  `ord_8w2k`, `ord_7mn3`, `ord_2zr9` — exactly the docs' figures. **F2** weight 10 to a canary: **17 of 200**
  went to `orders.created.canary`, 183 stayed on `orders.created`. **F3** the weight edited to 50 and
  `--signal reload`: `Reloaded: accounts`, then **93 / 107**. **F4** weights 60 + 50: `nats-server:
  map-over.conf:5:3: Error adding mapping for "orders.created" : total weight needs to be <= 100`, exit 1
  from `-t` and from a start. **F5** the source listed as its own destination at weight 90: **188 of 200**
  arrived, 12 were dropped — the remainder is discarded, as the docs say. **F6** the live partition put the
  three ids in buckets 0, 1, 2 and the repeated id in 0 again. **F7** a subscriber on the pre-map subject
  `orders.created.ord_8w2k` received nothing. **F8** (appended, `bash core-delivery-run.sh f8`): a **wildcard** source listed as its
  own destination — `"orders.loss.>": [ { destination: "orders.loss.>", weight: 50 } ]`, the "chaos testing trick" of the server's
  example config quoted in gh#5172 — passes `nats-server -t` and drops the remainder too: **98 of 200** arrived. The docs'
  "This only works for a literal source" does not hold.
- **G1** `nats sub --trace`: one received; the server stopped → `>>> Disconnected due to: EOF, will attempt
  reconnect`, `>>> Setting reconnect delay to 725ms`; a `nats pub` in the gap: `nats: error: nats: no servers
  available for connection`, exit 1; the server back → `>>> Reconnected to nats://127.0.0.1:14222`, and
  "three" received. **G2** `--signal ldm` with `lame_duck_grace_period: 1s` and `lame_duck_duration: 30s`
  (the minimum the server accepts — `3s` is refused at start with `invalid lame_duck_duration of 3s, minimum
  is 30 seconds`): the server logged `Entering lame duck mode, stop accepting new clients`, one second later
  `Closing existing clients`, `Initiating Shutdown...`, `Server Exiting..` — with its one client closed it
  exited about one second after the signal, not after the 30 s duration. The CLI printed no lame-duck line:
  only `>>> Disconnected due to: EOF, will attempt reconnect`, then `Setting reconnect delay` lines growing
  with jitter (1.008 s … 7.878 s) and `Reconnect error: dial tcp 127.0.0.1:14222: connect: connection refused`.

## Transcript

```
### versions
nats-server: v2.14.6
0.4.0
Python 3.14.7

### A — the INFO line, a whitespace subject over the raw protocol, and the CLI's own check
--- A1: nc prints the INFO line the moment it connects
INFO {"server_id":"NDI7LT7QBYWXURWLWEFPFHMAPJL47HQNTDEC7IYT5IUTLSK7SO5GQ4FH","server_name":"corelab","version":"2.14.6","proto":1,"go":"go1.27.0","host":"0.0.0.0","port":14222,"headers":true,"max_payload":1048576,"client_id":5,"client_ip":"127.0.0.1","api_lvl":4,"xkey":"XBUEXYMWYOX7YAKVJPDRZJOIUEWOGVPM4GKGLJ3FMSKBLJ25NC3CFHIB"} 

--- A2: raw 'PUB orders.us created 0' (a space inside the subject) with a nats sub '>' tap
<< INFO {"server_id":"NDI7LT7QBYWXURWLWEFPFHMAPJL47HQNTDEC7IYT5IUTLSK7SO5GQ4FH","server_name":"corelab","version":"2.14.6","proto":1,"go":"go1.27.0","host":"0.0.0.0","port":14222,"headers":true,"max_payload":1048576,"client_id":7,"client_ip":"127.0.0.1","api_lvl":4,"xkey":"XBUEXYMWYOX7YAKVJPDRZJOIUEWOGVPM4GKGLJ3FMSKBLJ25NC3CFHIB"}
>> CONNECT {"name": "raw", "lang": "python", "version": "0", "protocol": 1, "verbose": false, "pedantic": false, "headers": true}
>> PUB orders.us created 0
>> (empty line)
>> PING
<< PONG
<< INFO {"server_id":"NDI7LT7QBYWXURWLWEFPFHMAPJL47HQNTDEC7IYT5IUTLSK7SO5GQ4FH","server_name":"corelab","version":"2.14.6","proto":1,"go":"go1.27.0","host":"0.0.0.0","port":14222,"headers":true,"max_payload":1048576,"client_id":7,"client_ip":"127.0.0.1","connect_info":true,"remote_account":"$G","api_lvl":4,"xkey":"XBUEXYMWYOX7YAKVJPDRZJOIUEWOGVPM4GKGLJ3FMSKBLJ25NC3CFHIB"} 
-- socket still open after 1.0s
the tap saw:
18:22:44 Subscribing on > 
[#1] Received on "orders.us" with reply "created"
nil body


--- A3: nats pub with a space in the subject
nats: error: nats: invalid subject
exit: 1
--- A4: nats sub with a space in the subject
18:22:46 Subscribing on orders.us created 
nats: error: nats: invalid subject
exit: 1
--- A5: CONNECT asking for no_responders without headers
<< INFO {"server_id":"NDI7LT7QBYWXURWLWEFPFHMAPJL47HQNTDEC7IYT5IUTLSK7SO5GQ4FH","server_name":"corelab","version":"2.14.6","proto":1,"go":"go1.27.0","host":"0.0.0.0","port":14222,"headers":true,"max_payload":1048576,"client_id":10,"client_ip":"127.0.0.1","api_lvl":4,"xkey":"XBUEXYMWYOX7YAKVJPDRZJOIUEWOGVPM4GKGLJ3FMSKBLJ25NC3CFHIB"}
>> CONNECT {"name": "raw", "lang": "python", "version": "0", "protocol": 1, "verbose": false, "pedantic": false, "headers": false, "no_responders": true}
>> PING
<< -ERR 'no responders requires headers support'
-- socket closed by the server

### B — max_payload: the client's check, the server's on a raw PUB, and headers counted in an HPUB
--- B1: a 2 MB nats pub
18:22:47 Reading payload from STDIN
nats: error: nats: maximum payload exceeded
exit: 1
--- B2: raw PUB of 1048577 bytes (max_payload + 1)
<< INFO {"server_id":"NCDZTDPLRDYPAOHIYUNGONCFQFRLOQM7MNIPBA2KM7O5VEA7VD5SCKVV","server_name":"corelab","version":"2.14.6","proto":1,"go":"go1.27.0","host":"0.0.0.0","port":14222,"headers":true,"max_payload":1048576,"client_id":6,"client_ip":"127.0.0.1","api_lvl":4,"xkey":"XCPLZZ2ZFSDK62CHTF4KXUG3H7IKJ7TWUHIQZ76HYPNGYLRE6AIVJQYQ"}
>> CONNECT {"name": "raw", "lang": "python", "version": "0", "protocol": 1, "verbose": false, "pedantic": false, "headers": true}
>> PUB orders.created 1048577  (+1048577 payload bytes)
>> PING
-- send interrupted: BrokenPipeError (the server closed the socket before the frame was fully written)
<< -ERR 'Maximum Payload Violation'
-- socket still open after 1.0s
--- B3: raw PUB of 1048576 bytes (exactly max_payload), with an orders.> tap
<< INFO {"server_id":"NCDZTDPLRDYPAOHIYUNGONCFQFRLOQM7MNIPBA2KM7O5VEA7VD5SCKVV","server_name":"corelab","version":"2.14.6","proto":1,"go":"go1.27.0","host":"0.0.0.0","port":14222,"headers":true,"max_payload":1048576,"client_id":8,"client_ip":"127.0.0.1","api_lvl":4,"xkey":"XCPLZZ2ZFSDK62CHTF4KXUG3H7IKJ7TWUHIQZ76HYPNGYLRE6AIVJQYQ"}
>> CONNECT {"name": "raw", "lang": "python", "version": "0", "protocol": 1, "verbose": false, "pedantic": false, "headers": true}
>> PUB orders.created 1048576  (+1048576 payload bytes)
>> PING
<< PONG
<< INFO {"server_id":"NCDZTDPLRDYPAOHIYUNGONCFQFRLOQM7MNIPBA2KM7O5VEA7VD5SCKVV","server_name":"corelab","version":"2.14.6","proto":1,"go":"go1.27.0","host":"0.0.0.0","port":14222,"headers":true,"max_payload":1048576,"client_id":8,"client_ip":"127.0.0.1","connect_info":true,"remote_account":"$G","api_lvl":4,"xkey":"XCPLZZ2ZFSDK62CHTF4KXUG3H7IKJ7TWUHIQZ76HYPNGYLRE6AIVJQYQ"} 
-- socket still open after 1.0s
the tap saw:
18:22:48 Subscribing on orders.> 
[#1] Received on "orders.created"
--- B4: raw HPUB, 600000 header bytes + 500000 body bytes = 1100000 total
<< INFO {"server_id":"NCDZTDPLRDYPAOHIYUNGONCFQFRLOQM7MNIPBA2KM7O5VEA7VD5SCKVV","server_name":"corelab","version":"2.14.6","proto":1,"go":"go1.27.0","host":"0.0.0.0","port":14222,"headers":true,"max_payload":1048576,"client_id":9,"client_ip":"127.0.0.1","api_lvl":4,"xkey":"XCPLZZ2ZFSDK62CHTF4KXUG3H7IKJ7TWUHIQZ76HYPNGYLRE6AIVJQYQ"}
>> CONNECT {"name": "raw", "lang": "python", "version": "0", "protocol": 1, "verbose": false, "pedantic": false, "headers": true}
>> HPUB orders.created 600000 1100000  (+1100000 bytes: 600000 header, 500000 body)
>> PING
-- send interrupted: BrokenPipeError (the server closed the socket before the frame was fully written)
<< -ERR 'Maximum Payload Violation'
-- socket still open after 1.0s
--- B5: raw HPUB, 600000 header bytes + 400000 body bytes = 1000000 total, with a --headers-only tap
<< INFO {"server_id":"NCDZTDPLRDYPAOHIYUNGONCFQFRLOQM7MNIPBA2KM7O5VEA7VD5SCKVV","server_name":"corelab","version":"2.14.6","proto":1,"go":"go1.27.0","host":"0.0.0.0","port":14222,"headers":true,"max_payload":1048576,"client_id":11,"client_ip":"127.0.0.1","api_lvl":4,"xkey":"XCPLZZ2ZFSDK62CHTF4KXUG3H7IKJ7TWUHIQZ76HYPNGYLRE6AIVJQYQ"}
>> CONNECT {"name": "raw", "lang": "python", "version": "0", "protocol": 1, "verbose": false, "pedantic": false, "headers": true}
>> HPUB orders.created 600000 1000000  (+1000000 bytes: 600000 header, 400000 body)
>> PING
<< PONG
<< INFO {"server_id":"NCDZTDPLRDYPAOHIYUNGONCFQFRLOQM7MNIPBA2KM7O5VEA7VD5SCKVV","server_name":"corelab","version":"2.14.6","proto":1,"go":"go1.27.0","host":"0.0.0.0","port":14222,"headers":true,"max_payload":1048576,"client_id":11,"client_ip":"127.0.0.1","connect_info":true,"remote_account":"$G","api_lvl":4,"xkey":"XCPLZZ2ZFSDK62CHTF4KXUG3H7IKJ7TWUHIQZ76HYPNGYLRE6AIVJQYQ"} 
-- socket still open after 1.0s
the tap saw (first 120 bytes):
18:22:50 Subscribing on orders.> 
[#1] Received on "orders.created"
X-Pad: ppppppppppppppppppppppppppppppppppppppppppppp
--- server log lines (ERR/WRN) for B
[1007] 2026/09/03 18:22:48.103420 [ERR] 127.0.0.1:53729 - cid:6 - "v0:python:raw" - maximum payload exceeded: 1048577 vs 1048576
[1007] 2026/09/03 18:22:50.343400 [ERR] 127.0.0.1:53735 - cid:9 - "v0:python:raw" - maximum payload exceeded: 1100000 vs 1048576
--- B6: nats pub -H against a server with no_header_support: true
INFO {"server_id":"NCOMKYMNKZMONDPEAQHXMO5NH6WKTOMUESRTOFAME5Q6Y4WFCRD7CV75","server_name":"corelab","version":"2.14.6","proto":1,"go":"go1.27.0","host":"0.0.0.0","port":14222,"headers":false,"max_payload":1048576,"client_id":5,"client_ip":"127.0.0.1","api_lvl":4,"xkey":"XAYGDKWYO2G2YQMTSE2PFUFAP5GPOCZQ6XKXCOCB67L7WGQBDTISFGWB"} 

nats: error: nats: headers not supported by this server
exit: 1
--- B7: CONNECT with headers:true and no_responders:true against the same server
<< INFO {"server_id":"NCOMKYMNKZMONDPEAQHXMO5NH6WKTOMUESRTOFAME5Q6Y4WFCRD7CV75","server_name":"corelab","version":"2.14.6","proto":1,"go":"go1.27.0","host":"0.0.0.0","port":14222,"headers":false,"max_payload":1048576,"client_id":7,"client_ip":"127.0.0.1","api_lvl":4,"xkey":"XAYGDKWYO2G2YQMTSE2PFUFAP5GPOCZQ6XKXCOCB67L7WGQBDTISFGWB"}
>> CONNECT {"name": "raw", "lang": "python", "version": "0", "protocol": 1, "verbose": false, "pedantic": false, "headers": true, "no_responders": true}
>> PING
<< -ERR 'no responders requires headers support'
-- socket closed by the server

### C — subscribe- and publish-side wildcard checks, pedantic mode, max_subscription_tokens
--- C1: raw 'SUB orders.>.created 1', then PING
<< INFO {"server_id":"NDNPCHXV3C5TBQW7PU2YS53WK24ZGIELF6LLF5IL7B242A5VMY2RTY2A","server_name":"corelab","version":"2.14.6","proto":1,"go":"go1.27.0","host":"0.0.0.0","port":14222,"headers":true,"max_payload":1048576,"client_id":5,"client_ip":"127.0.0.1","api_lvl":4,"xkey":"XAMLPEWCPZ3XBO6XFSGWDDD6F2KQUQTMBBENGMPVYJVHLBB6QCUWQI5E"}
>> CONNECT {"name": "raw", "lang": "python", "version": "0", "protocol": 1, "verbose": false, "pedantic": false, "headers": true}
>> SUB orders.>.created 1
>> PING
<< -ERR 'Invalid Subject'
<< PONG
<< INFO {"server_id":"NDNPCHXV3C5TBQW7PU2YS53WK24ZGIELF6LLF5IL7B242A5VMY2RTY2A","server_name":"corelab","version":"2.14.6","proto":1,"go":"go1.27.0","host":"0.0.0.0","port":14222,"headers":true,"max_payload":1048576,"client_id":5,"client_ip":"127.0.0.1","connect_info":true,"remote_account":"$G","api_lvl":4,"xkey":"XAMLPEWCPZ3XBO6XFSGWDDD6F2KQUQTMBBENGMPVYJVHLBB6QCUWQI5E"} 
-- socket still open after 1.0s
--- C2: raw 'PUB orders.*.created 0' from a default (non-pedantic) CONNECT; taps on orders.>, orders.*.created, orders.us.created
<< INFO {"server_id":"NDNPCHXV3C5TBQW7PU2YS53WK24ZGIELF6LLF5IL7B242A5VMY2RTY2A","server_name":"corelab","version":"2.14.6","proto":1,"go":"go1.27.0","host":"0.0.0.0","port":14222,"headers":true,"max_payload":1048576,"client_id":9,"client_ip":"127.0.0.1","api_lvl":4,"xkey":"XAMLPEWCPZ3XBO6XFSGWDDD6F2KQUQTMBBENGMPVYJVHLBB6QCUWQI5E"}
>> CONNECT {"name": "raw", "lang": "python", "version": "0", "protocol": 1, "verbose": false, "pedantic": false, "headers": true}
>> PUB orders.*.created 0
>> (empty line)
>> PING
<< PONG
<< INFO {"server_id":"NDNPCHXV3C5TBQW7PU2YS53WK24ZGIELF6LLF5IL7B242A5VMY2RTY2A","server_name":"corelab","version":"2.14.6","proto":1,"go":"go1.27.0","host":"0.0.0.0","port":14222,"headers":true,"max_payload":1048576,"client_id":9,"client_ip":"127.0.0.1","connect_info":true,"remote_account":"$G","api_lvl":4,"xkey":"XAMLPEWCPZ3XBO6XFSGWDDD6F2KQUQTMBBENGMPVYJVHLBB6QCUWQI5E"} 
-- socket still open after 1.0s
orders.> tap:
18:22:55 Subscribing on orders.> 
[#1] Received on "orders.*.created"
nil body


orders.*.created tap:
18:22:56 Subscribing on orders.*.created 
[#1] Received on "orders.*.created"
nil body


orders.us.created tap:
18:22:56 Subscribing on orders.us.created 
--- C3: the same PUB from a pedantic CONNECT, orders.> tap
<< INFO {"server_id":"NDNPCHXV3C5TBQW7PU2YS53WK24ZGIELF6LLF5IL7B242A5VMY2RTY2A","server_name":"corelab","version":"2.14.6","proto":1,"go":"go1.27.0","host":"0.0.0.0","port":14222,"headers":true,"max_payload":1048576,"client_id":11,"client_ip":"127.0.0.1","api_lvl":4,"xkey":"XAMLPEWCPZ3XBO6XFSGWDDD6F2KQUQTMBBENGMPVYJVHLBB6QCUWQI5E"}
>> CONNECT {"name": "raw", "lang": "python", "version": "0", "protocol": 1, "verbose": false, "pedantic": true, "headers": true}
>> PUB orders.*.created 0
>> (empty line)
>> PING
<< -ERR 'Invalid Publish Subject'
<< PONG
<< INFO {"server_id":"NDNPCHXV3C5TBQW7PU2YS53WK24ZGIELF6LLF5IL7B242A5VMY2RTY2A","server_name":"corelab","version":"2.14.6","proto":1,"go":"go1.27.0","host":"0.0.0.0","port":14222,"headers":true,"max_payload":1048576,"client_id":11,"client_ip":"127.0.0.1","connect_info":true,"remote_account":"$G","api_lvl":4,"xkey":"XAMLPEWCPZ3XBO6XFSGWDDD6F2KQUQTMBBENGMPVYJVHLBB6QCUWQI5E"} 
-- socket still open after 1.0s
orders.> tap:
18:22:58 Subscribing on orders.> 
[#1] Received on "orders.*.created"
nil body


--- C4: raw SUB with an empty token, then PING
<< INFO {"server_id":"NDNPCHXV3C5TBQW7PU2YS53WK24ZGIELF6LLF5IL7B242A5VMY2RTY2A","server_name":"corelab","version":"2.14.6","proto":1,"go":"go1.27.0","host":"0.0.0.0","port":14222,"headers":true,"max_payload":1048576,"client_id":12,"client_ip":"127.0.0.1","api_lvl":4,"xkey":"XAMLPEWCPZ3XBO6XFSGWDDD6F2KQUQTMBBENGMPVYJVHLBB6QCUWQI5E"}
>> CONNECT {"name": "raw", "lang": "python", "version": "0", "protocol": 1, "verbose": false, "pedantic": false, "headers": true}
>> SUB orders..created 1
>> PING
<< -ERR 'Invalid Subject'
<< PONG
<< INFO {"server_id":"NDNPCHXV3C5TBQW7PU2YS53WK24ZGIELF6LLF5IL7B242A5VMY2RTY2A","server_name":"corelab","version":"2.14.6","proto":1,"go":"go1.27.0","host":"0.0.0.0","port":14222,"headers":true,"max_payload":1048576,"client_id":12,"client_ip":"127.0.0.1","connect_info":true,"remote_account":"$G","api_lvl":4,"xkey":"XAMLPEWCPZ3XBO6XFSGWDDD6F2KQUQTMBBENGMPVYJVHLBB6QCUWQI5E"} 
-- socket still open after 1.0s
--- C5: max_subscription_tokens: 3 — SUB with four tokens, SUB with three, PUB with four
<< INFO {"server_id":"NBYW47WSB63SEEKZYYW6KW6OBTPQ5PRYICOI22NNQZWZAN7Z6BUL6GFB","server_name":"corelab","version":"2.14.6","proto":1,"go":"go1.27.0","host":"0.0.0.0","port":14222,"headers":true,"max_payload":1048576,"client_id":6,"client_ip":"127.0.0.1","api_lvl":4,"xkey":"XCUGJBFCGCEQTWTJFRJ5JBUCPRTFF4J5RXM3EH4QFO2KBJRV6ELTERNK"}
>> CONNECT {"name": "raw", "lang": "python", "version": "0", "protocol": 1, "verbose": false, "pedantic": false, "headers": true}
>> SUB a.b.c.d 1
>> SUB a.b.c 2
>> PUB a.b.c.d 0
>> (empty line)
>> PING
<< -ERR 'Permissions Violation for Subscription to "a.b.c.d", too many tokens'
<< PONG
<< INFO {"server_id":"NBYW47WSB63SEEKZYYW6KW6OBTPQ5PRYICOI22NNQZWZAN7Z6BUL6GFB","server_name":"corelab","version":"2.14.6","proto":1,"go":"go1.27.0","host":"0.0.0.0","port":14222,"headers":true,"max_payload":1048576,"client_id":6,"client_ip":"127.0.0.1","connect_info":true,"remote_account":"$G","api_lvl":4,"xkey":"XCUGJBFCGCEQTWTJFRJ5JBUCPRTFF4J5RXM3EH4QFO2KBJRV6ELTERNK"} 
-- socket still open after 1.0s
a.> tap:
18:23:03 Subscribing on a.> 
[#1] Received on "a.b.c.d"
nil body


server log:
[1459] 2026/09/03 18:23:03.825236 [ERR] 127.0.0.1:53759 - cid:6 - "v0:python:raw" - Subscription Violation Too Many Tokens - Subject "a.b.c.d", SID 1
--- C6: reload with max_subscription_tokens changed 3 -> 4
signal exit: 0
[1459] 2026/09/03 18:23:05.483213 [INF] Trapped "hangup" signal
[1459] 2026/09/03 18:23:05.483496 [ERR] Failed to reload server configuration: config reload not supported for MaxSubTokens: old=3, new=4
<< INFO {"server_id":"NBYW47WSB63SEEKZYYW6KW6OBTPQ5PRYICOI22NNQZWZAN7Z6BUL6GFB","server_name":"corelab","version":"2.14.6","proto":1,"go":"go1.27.0","host":"0.0.0.0","port":14222,"headers":true,"max_payload":1048576,"client_id":7,"client_ip":"127.0.0.1","api_lvl":4,"xkey":"XCUGJBFCGCEQTWTJFRJ5JBUCPRTFF4J5RXM3EH4QFO2KBJRV6ELTERNK"}
>> CONNECT {"name": "raw", "lang": "python", "version": "0", "protocol": 1, "verbose": false, "pedantic": false, "headers": true}
>> SUB a.b.c.d 1
>> PING
<< -ERR 'Permissions Violation for Subscription to "a.b.c.d", too many tokens'
<< PONG
<< INFO {"server_id":"NBYW47WSB63SEEKZYYW6KW6OBTPQ5PRYICOI22NNQZWZAN7Z6BUL6GFB","server_name":"corelab","version":"2.14.6","proto":1,"go":"go1.27.0","host":"0.0.0.0","port":14222,"headers":true,"max_payload":1048576,"client_id":7,"client_ip":"127.0.0.1","connect_info":true,"remote_account":"$G","api_lvl":4,"xkey":"XCUGJBFCGCEQTWTJFRJ5JBUCPRTFF4J5RXM3EH4QFO2KBJRV6ELTERNK"} 
-- socket still open after 1.0s
--- C7: max_subscription_tokens: 0 and 256 through nats-server -t
nats-server: tok0.conf:4:1: max_subscription_tokens value can not be negative

exit: 1
nats-server: tok256.conf:4:1: max_subscription_tokens value is too big

exit: 1

### D — /subsz test=, and the two nats server request commands on a plain server and on the lab
--- D1: /subsz?subs=1&acc=$G&test=orders.us.created with an orders.> subscriber and a queue subscriber on orders.created
{
    "server_id": "NDZFHUOL72IRUNPWMXU4LQXU2ZC6YVRGWOSLNXS25A7Q2M2ZBUBMALT7",
    "now": "2026-09-03T16:23:09.35767Z",
    "num_subscriptions": 6,
    "num_cache": 0,
    "num_inserts": 6,
    "num_removes": 0,
    "num_matches": 0,
    "cache_hit_rate": 0,
    "max_fanout": 0,
    "avg_fanout": 0,
    "total": 1,
    "offset": 0,
    "limit": 1024,
    "subscriptions_list": [
        {
            "account": "$G",
            "account_tag": "$G",
            "subject": "orders.>",
            "sid": "1",
            "msgs": 0,
            "cid": 5
        }
    ]
}
--- D2: /subsz?subs=1&acc=$G — every subscription in $G
{
    "server_id": "NDZFHUOL72IRUNPWMXU4LQXU2ZC6YVRGWOSLNXS25A7Q2M2ZBUBMALT7",
    "now": "2026-09-03T16:23:09.402324Z",
    "num_subscriptions": 6,
    "num_cache": 0,
    "num_inserts": 6,
    "num_removes": 0,
    "num_matches": 0,
    "cache_hit_rate": 0,
    "max_fanout": 0,
    "avg_fanout": 0,
    "total": 6,
    "offset": 0,
    "limit": 1024,
    "subscriptions_list": [
        {
            "account": "$G",
            "account_tag": "$G",
            "subject": "$SYS.REQ.SERVER.PING.CONNZ",
            "sid": "2",
            "msgs": 0,
            "cid": 4
        },
        {
            "account": "$G",
            "account_tag": "$G",
            "subject": "$SYS.REQ.USER.INFO",
            "sid": "4",
            "msgs": 0,
            "cid": 4
        },
        {
            "account": "$G",
            "account_tag": "$G",
            "subject": "$SYS.REQ.ACCOUNT.PING.CONNZ",
            "sid": "1",
            "msgs": 0,
            "cid": 4
        },
        {
            "account": "$G",
            "account_tag": "$G",
            "subject": "$SYS.REQ.ACCOUNT.PING.STATZ",
            "sid": "3",
            "msgs": 0,
            "cid": 4
        },
        {
            "account": "$G",
            "account_tag": "$G",
            "subject": "orders.created",
            "qgroup": "packers",
            "sid": "1",
            "msgs": 0,
            "cid": 6
        },
        {
            "account": "$G",
            "account_tag": "$G",
            "subject": "orders.>",
            "sid": "1",
            "msgs": 0,
            "cid": 5
        }
    ]
}
--- D3: /subsz?subs=1 with no acc= — the count across accounts
num_subscriptions: 62 total: 62
[('$G', '$SYS'), ('$G', 'orders'), ('$SYS', '$SYS')]
--- D4: the test= query again with no subscriber
{
    "server_id": "NDZFHUOL72IRUNPWMXU4LQXU2ZC6YVRGWOSLNXS25A7Q2M2ZBUBMALT7",
    "now": "2026-09-03T16:23:10.386733Z",
    "num_subscriptions": 4,
    "num_cache": 0,
    "num_inserts": 6,
    "num_removes": 2,
    "num_matches": 0,
    "cache_hit_rate": 0,
    "max_fanout": 0,
    "avg_fanout": 0,
    "total": 0,
    "offset": 0,
    "limit": 1024
}
--- D5: nats server request subscriptions / connections on the plain server (no system-account user)
nats: error: server request failed, ensure the account used has system privileges and appropriate permissions
exit: 1
{"server":{"name":"corelab","host":"0.0.0.0","id":"NDZFHUOL72IRUNPWMXU4LQXU2ZC6YVRGWOSLNXS25A7Q2M2ZBUBMALT7","ver":"2.14.6","feature_flags":{"js_ack_fc_v2":false,"js_raft_delete_range":false},"jetstream":false,"flags":0,"seq":15,"time":"2026-09-03T16:23:10.447255Z"},"data":{"server_id":"NDZFHUOL72IRUNPWMXU4LQXU2ZC6YVRGWOSLNXS25A7Q2M2ZBUBMALT7","now":"2026-09-03T16:23:10.447248Z","num_connections":1,"total":1,"offset":0,"limit":2048,"connections":[{"cid":8,"kind":"Client","type":"nats","ip":"127.0.0.1","port":53770,"start":"2026-09-03T18:23:10.446703+02:00","last_activity":"2026-09-03T18:23:10.447203+02:00","rtt":"157µs","uptime":"0s","idle":"0s","pending_bytes":0,"in_msgs":2,"out_msgs":0,"in_bytes":233,"out_bytes":0,"subscriptions":2,"name":"NATS CLI Version 0.4.0","lang":"go","version":"1.51.0","name_tag":"$G"}]}}
exit: 0
--- D6: the same two on the lab (tools/lab/cluster.sh up 3, user sys)
node pid     alive client http  healthz  js-meta  meta_leader cluster_size
n1   15291   yes   4291   8291  200      200      n1          3
n2   15311   yes   4292   8292  200      200      n1          3
n3   15331   yes   4293   8293  200      200      n1          3
{"server":{"name":"n1","host":"127.0.0.1","id":"NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S","cluster":"east","ver":"2.14.6","feature_flags":{"js_ack_fc_v2":false,"js_raft_delete_range":false},"jetstream":true,"flags":7,"seq":5049,"time":"2026-09-03T16:23:11.323399Z"},"data":{"server_id":"NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S","now":"2026-09-03T16:23:11.323396Z","num_subscriptions":259,"num_cache":26,"num_inserts":319,"num_removes":60,"num_matches":426,"cache_hit_rate":0.5422535211267606,"max_fanout":3,"avg_fanout":1.8076923076923077,"total":0,"offset":0,"limit":2048}}
{"server":{"name":"n3","host":"127.0.0.1","id":"NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI","cluster":"east","ver":"2.14.6","feature_flags":{"js_ack_fc_v2":false,"js_raft_delete_range":false},"jetstream":true,"flags":7,"seq":4990,"time":"2026-09-03T16:23:11.323451Z"},"data":{"server_id":"NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI","now":"2026-09-03T16:23:11.323448Z","num_subscriptions":259,"num_cache":37,"num_inserts":319,"num_removes":60,"num_matches":215,"cache_hit_rate":0.7023255813953488,"max_fanout":6,"avg_fanout":2.5945945945945947,"total":0,"offset":0,"limit":2048}}
{"server":{"name":"n2","host":"127.0.0.1","id":"NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO","cluster":"east","ver":"2.14.6","feature_flags":{"js_ack_fc_v2":false,"js_raft_delete_range":false},"jetstream":true,"flags":7,"seq":4999,"time":"2026-09-03T16:23:11.323446Z"},"data":{"server_id":"NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO","now":"2026-09-03T16:23:11.323443Z","num_subscriptions":261,"num_cache":60,"num_inserts":321,"num_removes":60,"num_matches":328,"cache_hit_rate":0.6676829268292683,"max_fanout":6,"avg_fanout":1.9333333333333333,"total":0,"offset":0,"limit":2048}}
exit: 0
{"server":{"name":"n1","host":"127.0.0.1","id":"NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S","cluster":"east","ver":"2.14.6","feature_flags":{"js_ack_fc_v2":false,"js_raft_delete_range":false},"jetstream":true,"flags":7,"seq":5057,"time":"2026-09-03T16:23:11.33471Z"},"data":{"server_id":"NDSQMOX6AWOXINWEODK576NHL2NUDCGCSC5AFXYRHT7OS3DX4YJUW34S","now":"2026-09-03T16:23:11.334698Z","num_connections":1,"total":1,"offset":0,"limit":2048,"connections":[{"cid":46,"kind":"Client","type":"nats","ip":"127.0.0.1","port":53782,"start":"2026-09-03T18:23:11.333854+02:00","last_activity":"2026-09-03T18:23:11.334691+02:00","rtt":"226µs","uptime":"0s","idle":"0s","pending_bytes":0,"in_msgs":2,"out_msgs":1,"in_bytes":233,"out_bytes":2166,"subscriptions":1,"name":"NATS CLI Version 0.4.0","lang":"go","version":"1.51.0","authorized_user":"sys","account":"$SYS","name_tag":"$SYS"}]}}
{"server":{"name":"n3","host":"127.0.0.1","id":"NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI","cluster":"east","ver":"2.14.6","feature_flags":{"js_ack_fc_v2":false,"js_raft_delete_range":false},"jetstream":true,"flags":7,"seq":4992,"time":"2026-09-03T16:23:11.334749Z"},"data":{"server_id":"NC7MMFPMMCTNPPXNPHFALYTKA3FRJZA337ID5WPP2BPPOENUORA5PUTI","now":"2026-09-03T16:23:11.334747Z","num_connections":0,"total":0,"offset":0,"limit":2048,"connections":[]}}
{"server":{"name":"n2","host":"127.0.0.1","id":"NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO","cluster":"east","ver":"2.14.6","feature_flags":{"js_ack_fc_v2":false,"js_raft_delete_range":false},"jetstream":true,"flags":7,"seq":5001,"time":"2026-09-03T16:23:11.334747Z"},"data":{"server_id":"NACESP3ZRLTA6AWMK5SAJGKJBWOBE43S6643MKQ2UOOIRIQI6OHRDZRO","now":"2026-09-03T16:23:11.334745Z","num_connections":0,"total":0,"offset":0,"limit":2048,"connections":[]}}
exit: 0

### E — nats trace with no subscriber, with orders.>, and with --deliver
--- E1: no subscriber
Tracing message route to subject orders.us.created 

Client "NATS CLI Version 0.4.0" cid:5 server:"corelab" version:"2.14.6"
--X No active interest

Legend: Client: --C Router: --> Gateway: ==> Leafnode: ~~> JetStream: --J Error: --X

exit: 0
--- E2: with an orders.> subscriber, no --deliver
Tracing message route to subject orders.us.created 

Client "NATS CLI Version 0.4.0" cid:7 server:"corelab" version:"2.14.6"
--C Client "NATS CLI Version 0.4.0" cid:6 subject:"orders.>"

Legend: Client: --C Router: --> Gateway: ==> Leafnode: ~~> JetStream: --J Error: --X

Egress Count:

  Client: 1
exit: 0
--- E3: with --deliver
Tracing message route to subject orders.us.created with delivery to the final destination

Client "NATS CLI Version 0.4.0" cid:8 server:"corelab" version:"2.14.6"
--C Client "NATS CLI Version 0.4.0" cid:6 subject:"orders.>"

Legend: Client: --C Router: --> Gateway: ==> Leafnode: ~~> JetStream: --J Error: --X

Egress Count:

  Client: 1
exit: 0
the subscriber saw:
18:23:12 Subscribing on orders.> 
[#1] Received on "orders.us.created"
Nats-Trace-Dest: _INBOX.9durgJX4MMEuUmSFC5eQH6.5TllEURn
Accept-Encoding: snappy

nil body



### F — account-level mappings: dry runs, weights, the remainder, partition, reload
--- F1: nats server mappings dry runs (the docs' examples; the three order ids)
orders.created

orders.us.created

orders.created.0.ord_8w2k

orders.created.1.ord_7mn3

orders.created.2.ord_2zr9

--- F2: weight 10 to a canary; 200 publishes counted on an orders.> tap
   [200 "Received on" lines collapsed to counts: orders.created 183, orders.created.canary 17]
18:23:15 Subscribing on orders.> 
--- F3: reload after changing the weight to 50; 200 more
signal exit: 0
[1751] 2026/09/03 18:23:17.215005 [INF] Reloaded: accounts
[1751] 2026/09/03 18:23:17.215051 [INF] Reloaded server configuration (sha256:53318b4a07d564a643e0e577ca6a07660c186b2c579428f7e0e0325c1175cd4d)
   [200 "Received on" lines collapsed to counts: orders.created 107, orders.created.canary 93]
18:23:17 Subscribing on orders.> 
--- F4: weights 60 + 50 on one source
nats-server: map-over.conf:5:3: Error adding mapping for "orders.created" : total weight needs to be <= 100

exit (-t): 1
exit (start): 1
nats-server: map-over.conf:5:3: Error adding mapping for "orders.created" : total weight needs to be <= 100

--- F5: the source listed as its own destination at weight 90 — 200 publishes
received: 189 of 200 (a wc count that includes the "Subscribing on" line — 188 messages; see the collapsed counts)
   [188 "Received on" lines collapsed to counts: orders.created 188]
18:23:20 Subscribing on orders.> 
--- F6: partition(3, 1) live; the three ids, one of them twice; then a subscriber on the pre-map subject
18:23:24 Published 1 bytes to "orders.created.ord_8w2k"
18:23:24 Published 1 bytes to "orders.created.ord_7mn3"
18:23:24 Published 1 bytes to "orders.created.ord_2zr9"
18:23:24 Published 1 bytes to "orders.created.ord_8w2k"
18:23:24 Subscribing on orders.> 
[#1] Received on "orders.created.0.ord_8w2k"
[#2] Received on "orders.created.1.ord_7mn3"
[#3] Received on "orders.created.2.ord_2zr9"
[#4] Received on "orders.created.0.ord_8w2k"
18:23:26 Published 1 bytes to "orders.created.ord_8w2k"
the pre-map subscriber received 0 message(s)

### G — the client through a server restart and through lame duck
--- G1: publish one; stop the server; publish two (no server); start it; publish three
18:23:28 Published 3 bytes to "orders.created"
server stopped
nats: error: nats: no servers available for connection
exit: 1
18:23:34 Published 5 bytes to "orders.created"
the subscriber's log:
18:23:28 Subscribing on orders.created 
18:23:28 >>> Connected to nats://127.0.0.1:14222 (127.0.0.1:14222)
[#1] Received on "orders.created"
one


18:23:29 >>> Disconnected due to: EOF, will attempt reconnect
18:23:29 >>> Setting reconnect delay to 725ms
18:23:29 >>> Reconnected to nats://127.0.0.1:14222 (127.0.0.1:14222)
[#2] Received on "orders.created"
three


--- G2: --signal ldm with the subscriber attached (lame_duck_grace_period 1s, lame_duck_duration 30s — the minimum the server accepts)
signal exit: 0
server log:
[2004] 2026/09/03 18:23:34.867989 [INF] Entering lame duck mode, stop accepting new clients
[2004] 2026/09/03 18:23:35.869106 [INF] Closing existing clients
[2004] 2026/09/03 18:23:35.869403 [INF] Initiating Shutdown...
[2004] 2026/09/03 18:23:35.869591 [INF] Server Exiting..
the subscriber's log after ldm:
18:23:28 Subscribing on orders.created 
18:23:28 >>> Connected to nats://127.0.0.1:14222 (127.0.0.1:14222)
[#1] Received on "orders.created"
one


18:23:29 >>> Disconnected due to: EOF, will attempt reconnect
18:23:29 >>> Setting reconnect delay to 725ms
18:23:29 >>> Reconnected to nats://127.0.0.1:14222 (127.0.0.1:14222)
[#2] Received on "orders.created"
three


18:23:35 >>> Disconnected due to: EOF, will attempt reconnect
18:23:35 >>> Setting reconnect delay to 1.008s
18:23:36 >>> Setting reconnect delay to 1.253s
18:23:36 >>> Reconnect error: dial tcp 127.0.0.1:14222: connect: connection refused
18:23:38 >>> Setting reconnect delay to 2.03s
18:23:38 >>> Reconnect error: dial tcp 127.0.0.1:14222: connect: connection refused
18:23:40 >>> Setting reconnect delay to 1.042s
18:23:40 >>> Reconnect error: dial tcp 127.0.0.1:14222: connect: connection refused
18:23:41 >>> Setting reconnect delay to 1.738s
18:23:41 >>> Reconnect error: dial tcp 127.0.0.1:14222: connect: connection refused
18:23:42 >>> Setting reconnect delay to 2.141s
18:23:42 >>> Reconnect error: dial tcp 127.0.0.1:14222: connect: connection refused
18:23:45 >>> Setting reconnect delay to 3.834s
18:23:45 >>> Reconnect error: dial tcp 127.0.0.1:14222: connect: connection refused
18:23:48 >>> Setting reconnect delay to 5.907s
18:23:48 >>> Reconnect error: dial tcp 127.0.0.1:14222: connect: connection refused
18:23:54 >>> Setting reconnect delay to 3.97s
18:23:54 >>> Reconnect error: dial tcp 127.0.0.1:14222: connect: connection refused
18:23:58 >>> Setting reconnect delay to 6.671s
18:23:58 >>> Reconnect error: dial tcp 127.0.0.1:14222: connect: connection refused
18:24:05 >>> Setting reconnect delay to 7.878s
18:24:05 >>> Reconnect error: dial tcp 127.0.0.1:14222: connect: connection refused

### done

### F8 — appended from a separate invocation (bash core-delivery-run.sh f8), same binary, 2026-09-03
### versions
nats-server: v2.14.6
0.4.0
Python 3.14.7

### F8 — a wildcard source listed as its own destination at weight 50
nats-server: configuration file map-loss-wc.conf is valid (sha256:629d2073835bfc444f8922d5f9dc1538a8238bf6cfa975b3462a57728fdfc3d3)
exit (-t): 0
received: 98 of 200 on orders.loss.a
```
