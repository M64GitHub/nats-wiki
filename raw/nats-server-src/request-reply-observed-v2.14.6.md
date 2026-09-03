<!-- source: nats-server v2.14.6 binary, nats CLI 0.4.0 (its go.mod pins nats.go v1.51.0), Python 3.14.7, macOS, 2026-09-03 · runs A–D and G on one standalone server per scene on port 14222 (monitoring 18222), run E on the three-node lab of tools/lab/cluster.sh (n1 4291 / n2 4292 / n3 4293, plain clients in $G), run H on a standalone hub (14222, leafnode listener 17422) and a standalone leaf (14223) · four passes, scripts beside this file: request-reply-run.sh (A–E, G), request-reply-run2.sh (the /subsz views the first pass lost to a quoting slip in its helper — request-reply-subsz.py replaces it — the sentinel runs repeated, E2 repeated), request-reply-run3.sh (H1–H5), request-reply-run4.sh (H5 ×3, H6–H8); core-delivery-raw.py from step 1 is the raw protocol writer · the transcripts are the scripts' output verbatim except that bash's "Terminated: 15" job-control lines are dropped -->
# nats-server v2.14.6 — request/reply and queue groups observed: the 503 and its `Nats-Subject`, the CLI's gather modes and exit codes, a busy queue member, the pick across a cluster and across a leafnode, the 503 over a service import

The behavioural half of `request-reply-v2.14.6.md`, for `wiki/concepts/request-reply.md` and `wiki/concepts/queue-groups.md` (phase F step 2). Eight runs: **A** `nats reply`'s default queue group and what a request receives from two groups; **B** the no-responders `503` over the raw protocol in five shapes, and (**F**) the CLI's exit codes on no responders, on a timeout and on success; **C** the readiness claim — two members of one group, one of them busy for a second per request; **D** scatter-gather timing under `--replies N`, `--replies 0`, `--reply-timeout` and `--wait-for-empty`; **E** which member a cluster picks, with members spread over the lab's three nodes; **G** the 503 across a service import, with a renamed import; **H** a queue group with members on both sides of a leafnode, publishing from each side.

## What each run shows

- **A1** `/subsz?subs=1&acc=$G` shows the two responders as `qgroup NATS-RPLY-22` and `qgroup carrier-b` on `orders.inventory.check` — `nats reply` joins `NATS-RPLY-22` unless `--queue` says otherwise. **A2** a request with the defaults (`--replies 1`, `--timeout 5s`) printed **one** reply — `carrier-b`'s, the first to arrive — and exited 0; the other group's reply was discarded without a word. **A3** `--replies 0 --timeout 2s` printed both (one per group) and returned after **2.045 s**, the whole window. **A4** a third `nats reply` in the default group changed nothing: still two replies, one per group. **A5** 40 requests with `--replies 2`: the two `NATS-RPLY-22` members received **18 and 25** (43 with the three earlier requests), `carrier-b` all 43.
- **B1** a `CONNECT` with `headers` and `no_responders`, a `SUB _INBOX.x 1`, and a `PUB nobody _INBOX.x 0`: the server answered **`HMSG _INBOX.x 1 38 38`** with the header block `NATS/1.0 503\r\nNats-Subject: nobody\r\n\r\n` and no body — header length equals total length, and 38 is 32 bytes plus the six of the subject. **B2** the same with `no_responders: false`: nothing came back. **B3** `no_responders` without `headers`: `-ERR 'no responders requires headers support'`, the socket closed, and the server log `[ERR] … - "v0:python:raw" - no responders requires headers support`. **B4** a `PUB` whose reply subject this connection is not subscribed to: nothing — the 503 is sent only to a subscription the requesting connection holds. **B5** a `nats sub nobody` that never replies: nothing — a subscriber that does not answer is a timeout, not a 503. **B6 (F)** `nats request nobody x --timeout 2s`: `No responders are available` after **0.037 s**, **exit 0**. **B7 (F)** with a subscriber that never replies and `--timeout 1s`: **nothing printed** after `Sending request on "nobody"`, **exit 0** after 1.058 s. **B8 (F)** a successful request: exit 0. The CLI's three outcomes share one exit code, and only two of them print anything.
- **C1** two members of group `inv` — `fast` answers at once, `slow` runs `sleep 1` before each reply — under 20 **concurrent** requests: `fast` received **12**, `slow` **8**, and the run took **8.6 s** because the slow member answered its eight one per second. Repeated (`C1'`): 8 / 12 in 12.3 s, and `/subsz` shows `msgs 8` and `msgs 12` on the two members. **C3** 20 sequential requests: 8 / 12 in 12.3 s. The busy member kept receiving its random share while busy; nothing routed around it.
- **D1** three responders, `--replies 3 --timeout 2s`: 3 replies in **0.041 s**. **D2** `--replies 0 --timeout 2s`: 3 replies, returned after **2.057 s**. **D3** the default `--replies 1`: one reply, 0.034 s. **D4** two responders, `--replies 3`: 2 replies, returned after **0.364 s** — the average reply time plus the 300 ms `--reply-timeout`, not the 2 s. **D5** `--reply-timeout 1s`: 1.061 s. **D6** `--replies 0 --reply-timeout 50ms`: 2.040 s — no effect, as the docs say. **D7** nobody subscribed, `--replies 0`: `No responders are available` in 0.038 s. **D8'/D9'** (second pass, three times each) two quoting responders plus one that answers an **empty body** after 200 ms: with `--wait-for-empty` and with `--replies 5` alike the CLI printed both quotes, then `nil body` at ~212 ms, and returned at ~0.25 s — the empty reply ends the gather in **both** modes. **D11** `--replies 2`: the two quotes in 0.030 s; the later empty reply was never seen. (The first pass's D8 returned after 0.348 s with two replies: the sentinel's first invocation, a `sh` start plus `sleep 0.2`, lost the race against the 300 ms gap — the reason the run was repeated.)
- **E1** one member on n1, one on n2, 200 publishes on n1: **92 / 108**, repeated **116 / 84**. **E2** one on n1, three on n2, 400 publishes on n1: **90 / 97 / 106 / 107**, repeated **105 / 98 / 102 / 95** — a quarter each, wherever the member sits. **E3** members only on n2 and n3: 105 / 95. **E4** two on n1, one on n2, 300: 100 / 104 / 96. **E5** with a plain subscriber on n3 beside E1's shape: 98 / 102 to the members and all 200 to the plain subscriber. n1's `/subsz` lists only n1's own member (`qgroup workers`, `msgs 116`); the peer's members do not appear on it — `/subsz` is one server's client subscriptions. (n2's listing also shows the lab's earlier JetStream state: an `ORDERS` stream's mirror and source consumers, unrelated to this run.)
- **G1** account `APP` importing service `svc.check` from `SVC`, nobody subscribed in `SVC`: `No responders are available` after **0.037 s**, exit 0. **G2** raw: `HMSG _INBOX.x 1 41 41` with `Nats-Subject: svc.check`. **G3** an import renamed with `to: inv.stock`: the 503 names **`inv.stock`** — the subject the requester published, not the exporter's. **G4/G5** with a responder in `SVC`, both imports answer. **G6** a subject `APP` never imported: no responders too. The server logged nothing but the plaintext-password warning.
- **H1** one member on the hub, one on the leaf, 200 publishes on the hub: **200 / 0**. **H2** the same members, publishes on the leaf: **0 / 200**. **H3** members only on the leaf, publishes on the hub: 93 / 107. **H4** two on the hub, one on the leaf, publishes on the leaf: 0 / 0 / 200. A member across a leafnode is chosen only when the publisher's own server has none. **H5** two on the hub, two on the leaf, publishes on the hub: **148 / 52** to the hub's members and nothing to the leaf's; repeated with 400 publishes: **89 / 311**, **297 / 103**, **302 / 98**. **H6** two on the hub, one on the leaf: **137 / 263**. **H7** three on the hub, two on the leaf: **70 / 75 / 255**. **H8** the control, two on the hub and no leaf member: **196 / 204**. With a leaf holding *n* members the match list carries *n* leaf entries; the random walk skips them and lands on the next local member, which receives its own share plus the leaf's *n* — a 3 : 1 split for two and two, 2 : 1 for two and one, 3 : 1 : 1 for three and two.

## Transcript — the first pass (`request-reply-run.sh`)

```
### versions
nats-server: v2.14.6
0.4.0
Python 3.14.7

### A — nats reply's default queue group NATS-RPLY-22, a second group, and what a request receives
--- A1: /subsz?subs=1&acc=$G — the two responders' subscriptions
  File "<string>", line 5
    print(f"  num_subscriptions {d[\"num_subscriptions\"]}; non-$SYS entries {len(subs)}:")
                                    ^
SyntaxError: unexpected character after line continuation character
--- A2: nats request with the defaults (--replies 1 --timeout 5s)
19:10:25 Sending request on "orders.inventory.check"
19:10:25 Received with rtt 330.792µs
{"carrier":"carrier-b"}


exit: 0
--- A3: --replies 0 --timeout 2s — every reply until the timeout, timed
19:10:25 Sending request on "orders.inventory.check"
19:10:25 Received with rtt 189.875µs
{"carrier":"carrier-b"}


19:10:25 Received with rtt 204.125µs
{"in_stock":true,"warehouse":"us-east"}


exit: 0 after 2.045 s
--- A4: a third nats reply in the default group; --replies 0 --timeout 2s again
19:10:28 Sending request on "orders.inventory.check"
19:10:28 Received with rtt 384.375µs
{"carrier":"carrier-b"}


19:10:28 Received with rtt 423.458µs
{"in_stock":true,"warehouse":"eu-west"}


exit: 0
--- A5: 40 requests with --replies 2 --timeout 2s; how the default group split them
exit: 0
received: us-east (r1) 18 · eu-west (r3) 25 · carrier-b (r2) 43
  File "<string>", line 5
    print(f"  num_subscriptions {d[\"num_subscriptions\"]}; non-$SYS entries {len(subs)}:")
                                    ^
SyntaxError: unexpected character after line continuation character

### B — the 503 over the raw protocol, and what the CLI makes of it (F: exit codes)
--- B1: CONNECT headers+no_responders, SUB _INBOX.x 1, PUB nobody _INBOX.x 0
<< INFO {"server_id":"NA2W45TNOOXGOVDUNDXWSAQ35UG5ONGWS2VN2RAY76TMD2KP5QXBVB4A","server_name":"rrlab","version":"2.14.6","proto":1,"go":"go1.27.0","host":"0.0.0.0","port":14222,"headers":true,"max_payload":1048576,"client_id":5,"client_ip":"127.0.0.1","api_lvl":4,"xkey":"XB3GGP7CC76TNFIVQH3QPCNPK6T5YVWVJCDHLCZ3U4YAONPXPO4VBQ6O"}
>> CONNECT {"name": "raw", "lang": "python", "version": "0", "protocol": 1, "verbose": false, "pedantic": false, "headers": true, "no_responders": true}
>> SUB _INBOX.x 1
>> PUB nobody _INBOX.x 0
>> (empty line)
>> PING
<< HMSG _INBOX.x 1 38 38 | payload: NATS/1.0 503\r\nNats-Subject: nobody\r\n\r\n\r\n
<< PONG
<< INFO {"server_id":"NA2W45TNOOXGOVDUNDXWSAQ35UG5ONGWS2VN2RAY76TMD2KP5QXBVB4A","server_name":"rrlab","version":"2.14.6","proto":1,"go":"go1.27.0","host":"0.0.0.0","port":14222,"headers":true,"max_payload":1048576,"client_id":5,"client_ip":"127.0.0.1","connect_info":true,"remote_account":"$G","api_lvl":4,"xkey":"XB3GGP7CC76TNFIVQH3QPCNPK6T5YVWVJCDHLCZ3U4YAONPXPO4VBQ6O"} 
-- socket still open after 1.0s
--- B2: the same with no_responders:false
<< INFO {"server_id":"NA2W45TNOOXGOVDUNDXWSAQ35UG5ONGWS2VN2RAY76TMD2KP5QXBVB4A","server_name":"rrlab","version":"2.14.6","proto":1,"go":"go1.27.0","host":"0.0.0.0","port":14222,"headers":true,"max_payload":1048576,"client_id":6,"client_ip":"127.0.0.1","api_lvl":4,"xkey":"XB3GGP7CC76TNFIVQH3QPCNPK6T5YVWVJCDHLCZ3U4YAONPXPO4VBQ6O"}
>> CONNECT {"name": "raw", "lang": "python", "version": "0", "protocol": 1, "verbose": false, "pedantic": false, "headers": true, "no_responders": false}
>> SUB _INBOX.x 1
>> PUB nobody _INBOX.x 0
>> (empty line)
>> PING
<< PONG
<< INFO {"server_id":"NA2W45TNOOXGOVDUNDXWSAQ35UG5ONGWS2VN2RAY76TMD2KP5QXBVB4A","server_name":"rrlab","version":"2.14.6","proto":1,"go":"go1.27.0","host":"0.0.0.0","port":14222,"headers":true,"max_payload":1048576,"client_id":6,"client_ip":"127.0.0.1","connect_info":true,"remote_account":"$G","api_lvl":4,"xkey":"XB3GGP7CC76TNFIVQH3QPCNPK6T5YVWVJCDHLCZ3U4YAONPXPO4VBQ6O"} 
-- socket still open after 1.0s
--- B3: no_responders:true without headers
<< INFO {"server_id":"NA2W45TNOOXGOVDUNDXWSAQ35UG5ONGWS2VN2RAY76TMD2KP5QXBVB4A","server_name":"rrlab","version":"2.14.6","proto":1,"go":"go1.27.0","host":"0.0.0.0","port":14222,"headers":true,"max_payload":1048576,"client_id":7,"client_ip":"127.0.0.1","api_lvl":4,"xkey":"XB3GGP7CC76TNFIVQH3QPCNPK6T5YVWVJCDHLCZ3U4YAONPXPO4VBQ6O"}
>> CONNECT {"name": "raw", "lang": "python", "version": "0", "protocol": 1, "verbose": false, "pedantic": false, "headers": false, "no_responders": true}
>> PING
<< -ERR 'no responders requires headers support'
-- socket closed by the server
--- B4: no_responders, a reply subject this connection is not subscribed to
<< INFO {"server_id":"NA2W45TNOOXGOVDUNDXWSAQ35UG5ONGWS2VN2RAY76TMD2KP5QXBVB4A","server_name":"rrlab","version":"2.14.6","proto":1,"go":"go1.27.0","host":"0.0.0.0","port":14222,"headers":true,"max_payload":1048576,"client_id":8,"client_ip":"127.0.0.1","api_lvl":4,"xkey":"XB3GGP7CC76TNFIVQH3QPCNPK6T5YVWVJCDHLCZ3U4YAONPXPO4VBQ6O"}
>> CONNECT {"name": "raw", "lang": "python", "version": "0", "protocol": 1, "verbose": false, "pedantic": false, "headers": true, "no_responders": true}
>> PUB nobody _INBOX.y 0
>> (empty line)
>> PING
<< PONG
<< INFO {"server_id":"NA2W45TNOOXGOVDUNDXWSAQ35UG5ONGWS2VN2RAY76TMD2KP5QXBVB4A","server_name":"rrlab","version":"2.14.6","proto":1,"go":"go1.27.0","host":"0.0.0.0","port":14222,"headers":true,"max_payload":1048576,"client_id":8,"client_ip":"127.0.0.1","connect_info":true,"remote_account":"$G","api_lvl":4,"xkey":"XB3GGP7CC76TNFIVQH3QPCNPK6T5YVWVJCDHLCZ3U4YAONPXPO4VBQ6O"} 
-- socket still open after 1.0s
--- B5: no_responders, with a subscriber on the subject that never replies (nats sub nobody)
<< INFO {"server_id":"NA2W45TNOOXGOVDUNDXWSAQ35UG5ONGWS2VN2RAY76TMD2KP5QXBVB4A","server_name":"rrlab","version":"2.14.6","proto":1,"go":"go1.27.0","host":"0.0.0.0","port":14222,"headers":true,"max_payload":1048576,"client_id":10,"client_ip":"127.0.0.1","api_lvl":4,"xkey":"XB3GGP7CC76TNFIVQH3QPCNPK6T5YVWVJCDHLCZ3U4YAONPXPO4VBQ6O"}
>> CONNECT {"name": "raw", "lang": "python", "version": "0", "protocol": 1, "verbose": false, "pedantic": false, "headers": true, "no_responders": true}
>> SUB _INBOX.x 1
>> PUB nobody _INBOX.x 0
>> (empty line)
>> PING
<< PONG
<< INFO {"server_id":"NA2W45TNOOXGOVDUNDXWSAQ35UG5ONGWS2VN2RAY76TMD2KP5QXBVB4A","server_name":"rrlab","version":"2.14.6","proto":1,"go":"go1.27.0","host":"0.0.0.0","port":14222,"headers":true,"max_payload":1048576,"client_id":10,"client_ip":"127.0.0.1","connect_info":true,"remote_account":"$G","api_lvl":4,"xkey":"XB3GGP7CC76TNFIVQH3QPCNPK6T5YVWVJCDHLCZ3U4YAONPXPO4VBQ6O"} 
-- socket still open after 1.0s
--- B6 (F): nats request to a subject with no subscriber — the line, the time, the exit code
19:10:37 Sending request on "nobody"
19:10:37 No responders are available
exit: 0 after 0.037 s
--- B7 (F): nats request to a subject whose subscriber never replies — the timeout, the exit code
19:10:37 Sending request on "nobody"
exit: 0 after 1.058 s
--- B8 (F): a successful request's exit code (nats reply --count 1 quits after one)
19:10:39 Sending request on "ping"
19:10:39 Received with rtt 510.958µs
pong


exit: 0
--- server log lines (ERR/WRN) for B
[43215] 2026/09/03 19:10:34.021981 [ERR] 127.0.0.1:54964 - cid:7 - "v0:python:raw" - no responders requires headers support

### C — the readiness claim: two members of one group, one busy for 1 s per request
--- C1: 20 concurrent requests (--timeout 30s), timed
elapsed: 8.614 s
replies: fast 12 · slow 8 · other 44
member logs: fast received 12 · slow received 8
--- C2: /subsz — msgs per member
  File "<string>", line 5
    print(f"  num_subscriptions {d[\"num_subscriptions\"]}; non-$SYS entries {len(subs)}:")
                                    ^
SyntaxError: unexpected character after line continuation character
--- C3: 20 sequential requests (--count 20 --timeout 5s), timed
exit: 0 after 12.280 s
replies: fast 8 · slow 12

### D — scatter-gather: --replies N, --replies 0, --reply-timeout and --wait-for-empty, timed
--- D1: three responders, --replies 3 --timeout 2s
replies: 3 [ carrier-c carrier-a carrier-b ] exit: 0 after 0.041 s
--- D2: three responders, --replies 0 --timeout 2s
replies: 3 [ carrier-c carrier-b carrier-a ] exit: 0 after 2.057 s
--- D3: three responders, the default --replies 1
replies: 1 [ carrier-b ] exit: 0 after 0.034 s
--- D4: two responders, --replies 3 --timeout 2s (--reply-timeout at its 300ms default)
replies: 2 [ carrier-b carrier-a ] exit: 0 after 0.364 s
--- D5: two responders, --replies 3 --reply-timeout 1s --timeout 2s
replies: 2 [ carrier-b carrier-a ] exit: 0 after 1.061 s
--- D6: two responders, --replies 0 --timeout 2s --reply-timeout 50ms (the docs: no effect)
replies: 2 [ carrier-a carrier-b ] exit: 0 after 2.040 s
--- D7: no responders, --replies 0 --timeout 2s
replies: 0 [ No responders are available ] exit: 0 after 0.038 s
--- D8: two quoting responders + one answering an empty body after 200 ms: --wait-for-empty --timeout 2s
replies: 2 [ carrier-a carrier-b ] exit: 0 after 0.348 s
--- D9: the same three, --replies 5 --timeout 2s, no --wait-for-empty
replies: 3 [ carrier-b carrier-a ] exit: 0 after 0.347 s
--- D10: the same three, --replies 0 --timeout 2s
replies: 3 [ carrier-b carrier-a ] exit: 0 after 2.055 s

### E — queue-group selection across the lab's three nodes, publisher on n1
node pid     alive client http  healthz  js-meta  meta_leader cluster_size
n1   15291   yes   4291   8291  200      200      n1          3
n2   15311   yes   4292   8292  200      200      n1          3
n3   15331   yes   4293   8293  200      200      n1          3
--- E1: one member on n1, one on n2; 200 publishes from n1
n1 member 92 · n2 member 108
n1's /subsz:
  File "<string>", line 5
    print(f"  num_subscriptions {d[\"num_subscriptions\"]}; non-$SYS entries {len(subs)}:")
                                    ^
SyntaxError: unexpected character after line continuation character
--- E2: one member on n1, three on n2; 400 publishes from n1
n1 member 90 · n2 members 97 / 106 / 107
n1's /subsz:
  File "<string>", line 5
    print(f"  num_subscriptions {d[\"num_subscriptions\"]}; non-$SYS entries {len(subs)}:")
                                    ^
SyntaxError: unexpected character after line continuation character
--- E3: no member on n1; one on n2, one on n3; 200 publishes from n1
n2 member 105 · n3 member 95
--- E4: two members on n1, one on n2; 300 publishes from n1
n1 members 100 / 104 · n2 member 96
--- E5: a plain subscriber on n3 beside E1's shape; 200 publishes from n1
n1 member 98 · n2 member 102 · n3 plain 200

### G — the 503 across a service import (bank row 150)
nats-server: configuration file g.conf is valid (sha256:822df0425f6bae5a3150a14f319a0b8140beeb0098b7de905ba9d9862da6f916)
exit (-t): 0
--- G1: APP requests svc.check with nobody in SVC — timed, exit code
19:11:31 Sending request on "svc.check"
19:11:31 No responders are available
exit: 0 after 0.037 s
--- G2: the same over the raw protocol — the 503's Nats-Subject
<< INFO {"server_id":"NAUOEHWKBDYGC5Q7PY2YLJFB5RCIFKKV7TCNHXON7LRXGT7SMC6FY4PK","server_name":"rrlab","version":"2.14.6","proto":1,"go":"go1.27.0","host":"0.0.0.0","port":14222,"headers":true,"auth_required":true,"max_payload":1048576,"client_id":8,"client_ip":"127.0.0.1","api_lvl":4,"xkey":"XDIRSCZRWWASF7D74SXSAQS2VW6VESOLW6WB3F55HKVIVK27ZSTGK3AV"}
>> CONNECT {"name": "raw", "lang": "python", "version": "0", "protocol": 1, "verbose": false, "pedantic": false, "headers": true, "user": "app", "pass": "app", "no_responders": true}
>> SUB _INBOX.x 1
>> PUB svc.check _INBOX.x 0
>> (empty line)
>> PING
<< HMSG _INBOX.x 1 41 41 | payload: NATS/1.0 503\r\nNats-Subject: svc.check\r\n\r\n\r\n
<< PONG
<< INFO {"server_id":"NAUOEHWKBDYGC5Q7PY2YLJFB5RCIFKKV7TCNHXON7LRXGT7SMC6FY4PK","server_name":"rrlab","version":"2.14.6","proto":1,"go":"go1.27.0","host":"0.0.0.0","port":14222,"headers":true,"auth_required":true,"max_payload":1048576,"client_id":8,"client_ip":"127.0.0.1","connect_info":true,"remote_account":"APP","api_lvl":4,"xkey":"XDIRSCZRWWASF7D74SXSAQS2VW6VESOLW6WB3F55HKVIVK27ZSTGK3AV"} 
-- socket still open after 1.0s
--- G3: the renamed import inv.stock, raw — which subject the header names
<< INFO {"server_id":"NAUOEHWKBDYGC5Q7PY2YLJFB5RCIFKKV7TCNHXON7LRXGT7SMC6FY4PK","server_name":"rrlab","version":"2.14.6","proto":1,"go":"go1.27.0","host":"0.0.0.0","port":14222,"headers":true,"auth_required":true,"max_payload":1048576,"client_id":9,"client_ip":"127.0.0.1","api_lvl":4,"xkey":"XDIRSCZRWWASF7D74SXSAQS2VW6VESOLW6WB3F55HKVIVK27ZSTGK3AV"}
>> CONNECT {"name": "raw", "lang": "python", "version": "0", "protocol": 1, "verbose": false, "pedantic": false, "headers": true, "user": "app", "pass": "app", "no_responders": true}
>> SUB _INBOX.x 1
>> PUB inv.stock _INBOX.x 0
>> (empty line)
>> PING
<< HMSG _INBOX.x 1 41 41 | payload: NATS/1.0 503\r\nNats-Subject: inv.stock\r\n\r\n\r\n
<< PONG
<< INFO {"server_id":"NAUOEHWKBDYGC5Q7PY2YLJFB5RCIFKKV7TCNHXON7LRXGT7SMC6FY4PK","server_name":"rrlab","version":"2.14.6","proto":1,"go":"go1.27.0","host":"0.0.0.0","port":14222,"headers":true,"auth_required":true,"max_payload":1048576,"client_id":9,"client_ip":"127.0.0.1","connect_info":true,"remote_account":"APP","api_lvl":4,"xkey":"XDIRSCZRWWASF7D74SXSAQS2VW6VESOLW6WB3F55HKVIVK27ZSTGK3AV"} 
-- socket still open after 1.0s
--- G4: a responder in SVC on svc.check; APP's request
19:11:33 Sending request on "svc.check"
19:11:33 Received with rtt 667.875µs
{"in_stock":true}


exit: 0
--- G5: a responder in SVC on svc.stock; APP's request on inv.stock
19:11:34 Sending request on "inv.stock"
19:11:34 Received with rtt 488.708µs
{"stock":7}


exit: 0
--- G6: APP requests a subject it never imported (other.x)
19:11:34 Sending request on "other.x"
19:11:34 No responders are available
exit: 0 after 0.031 s
--- server log lines (ERR/WRN) for G
[44497] 2026/09/03 19:11:30.363558 [WRN] Plaintext passwords detected, use nkeys or bcrypt

### done
```

## Transcript — the second pass (`request-reply-run2.sh`)

```
### versions
nats-server: v2.14.6
0.4.0

### A1' — the two responders' subscriptions in /subsz
  num_subscriptions 6; non-$SYS entries 2:
  cid   5  sid   1  msgs    0  qgroup carrier-b      orders.inventory.check
  cid   6  sid   1  msgs    0  qgroup NATS-RPLY-22   orders.inventory.check

### C' — the readiness run again, with the /subsz msgs counters
--- C1': 20 concurrent requests (--timeout 30s), timed
elapsed: 12.314 s
replies: fast 8 · slow 12
member logs: fast received 8 · slow received 12
--- C2': /subsz — msgs per member
  num_subscriptions 6; non-$SYS entries 2:
  cid   5  sid   1  msgs    8  qgroup inv            orders.inventory.check
  cid   6  sid   1  msgs   12  qgroup inv            orders.inventory.check

### D8'/D9' — the sentinel, three times each, transcripts kept
--- D8'.1: --wait-for-empty --timeout 2s
    19:14:05 Sending request on "shipping.quote"
    19:14:05 Received with rtt 474.834µs
    {"carrier":"carrier-a","quote_cents":1500}
    
    
    19:14:05 Received with rtt 485.917µs
    {"carrier":"carrier-b","quote_cents":1200}
    
    
    19:14:06 Received with rtt 211.719375ms
    nil body
    
    
    exit: 0 after 0.260 s
--- D9'.1: --replies 5 --timeout 2s
    19:14:06 Sending request on "shipping.quote"
    19:14:06 Received with rtt 237.833µs
    {"carrier":"carrier-b","quote_cents":1200}
    
    
    19:14:06 Received with rtt 263.083µs
    {"carrier":"carrier-a","quote_cents":1500}
    
    
    19:14:06 Received with rtt 211.906416ms
    nil body
    
    
    exit: 0 after 0.258 s
--- D8'.2: --wait-for-empty --timeout 2s
    19:14:06 Sending request on "shipping.quote"
    19:14:06 Received with rtt 279.375µs
    {"carrier":"carrier-a","quote_cents":1500}
    
    
    19:14:06 Received with rtt 412.833µs
    {"carrier":"carrier-b","quote_cents":1200}
    
    
    19:14:06 Received with rtt 212.179708ms
    nil body
    
    
    exit: 0 after 0.261 s
--- D9'.2: --replies 5 --timeout 2s
    19:14:06 Sending request on "shipping.quote"
    19:14:06 Received with rtt 227.958µs
    {"carrier":"carrier-b","quote_cents":1200}
    
    
    19:14:06 Received with rtt 241.083µs
    {"carrier":"carrier-a","quote_cents":1500}
    
    
    19:14:06 Received with rtt 211.787667ms
    nil body
    
    
    exit: 0 after 0.247 s
--- D8'.3: --wait-for-empty --timeout 2s
    19:14:06 Sending request on "shipping.quote"
    19:14:06 Received with rtt 248.667µs
    {"carrier":"carrier-b","quote_cents":1200}
    
    
    19:14:06 Received with rtt 273.875µs
    {"carrier":"carrier-a","quote_cents":1500}
    
    
    19:14:07 Received with rtt 208.400458ms
    nil body
    
    
    exit: 0 after 0.250 s
--- D9'.3: --replies 5 --timeout 2s
    19:14:07 Sending request on "shipping.quote"
    19:14:07 Received with rtt 360.125µs
    {"carrier":"carrier-a","quote_cents":1500}
    
    
    19:14:07 Received with rtt 372.5µs
    {"carrier":"carrier-b","quote_cents":1200}
    
    
    19:14:07 Received with rtt 217.4845ms
    nil body
    
    
    exit: 0 after 0.256 s
--- D11: --replies 2 --timeout 2s against the same three (does the first two win, or the empty one end it?)
    19:14:07 Sending request on "shipping.quote"
    19:14:07 Received with rtt 414.209µs
    {"carrier":"carrier-b","quote_cents":1200}
    
    
    19:14:07 Received with rtt 439.334µs
    {"carrier":"carrier-a","quote_cents":1500}
    
    
    exit: 0 after 0.030 s
--- the sentinel responder's log (what it received and answered):
    19:14:05 Listening on "shipping.quote" in group "carrier-end"
    19:14:05 [#0] Received on subject "shipping.quote":
    
    {"order_id":"ord_8w2k"}
    19:14:06 [#1] Received on subject "shipping.quote":
    
    {"order_id":"ord_8w2k"}
    19:14:06 [#2] Received on subject "shipping.quote":
    
    {"order_id":"ord_8w2k"}
    19:14:06 [#3] Received on subject "shipping.quote":
    

### E1'/E2' — the lab again, with n1's /subsz view (port 8291)
--- E1': one member on n1, one on n2; 200 publishes from n1
n1 member 116 · n2 member 84
n1's /subsz:
  num_subscriptions 32; non-$SYS entries 4:
  cid   4  sid   5  msgs   36  qgroup -              $JS.API.>
  cid  22  sid   1  msgs    0  qgroup _sys_          $JS.API.DIRECT.GET.ORDERS
  cid  22  sid   2  msgs    0  qgroup _sys_          $JS.API.DIRECT.GET.ORDERS.>
  cid  57  sid   1  msgs  116  qgroup workers        orders.created
n2's /subsz:
  num_subscriptions 34; non-$SYS entries 25:
  cid   4  sid   5  msgs   23  qgroup -              $JS.API.>
  cid  21  sid   1  msgs 1530  qgroup -              orders.>
  cid  21  sid   2  msgs    0  qgroup _sys_          $JS.API.DIRECT.GET.ORDERS
  cid  21  sid   3  msgs    0  qgroup _sys_          $JS.API.DIRECT.GET.ORDERS.>
  cid  25  sid   1  msgs    1  qgroup -              $JS.ACK.ORDERS.shipping.*.*.*.*.*
  cid  25  sid   2  msgs    0  qgroup -              $JS.ACK._.szMpdrwD.ORDERS.shipping.*.*.*.*.>
  cid  25  sid   3  msgs   21  qgroup -              $JS.API.CONSUMER.MSG.NEXT.ORDERS.shipping
  cid  25  sid   4  msgs    0  qgroup -              $JS.API.CONSUMER.RESET.ORDERS.shipping
  cid  27  sid   1  msgs    0  qgroup _sys_          $JS.API.DIRECT.GET.ORDERS_MIRROR
  cid  27  sid   2  msgs    0  qgroup _sys_          $JS.API.DIRECT.GET.ORDERS_MIRROR.>
  cid  27  sid   4  msgs 53813  qgroup -              $JS.M.Qzsx0jGJ
  cid  27  sid   5  msgs    0  qgroup _sys_          $JS.API.DIRECT.GET.ORDERS
  cid  27  sid   6  msgs    0  qgroup _sys_          $JS.API.DIRECT.GET.ORDERS.>
  cid  30  sid   1  msgs    0  qgroup _sys_          $JS.API.DIRECT.GET.ORDERS_AGG
  cid  30  sid   2  msgs    0  qgroup _sys_          $JS.API.DIRECT.GET.ORDERS_AGG.>
  cid  30  sid   4  msgs 53813  qgroup -              $JS.S.dGBvANDe
  cid  33  sid   1  msgs    0  qgroup -              $JS.API.CONSUMER.MSG.NEXT.ORDERS.JS_MIRROR_eCMlsqH6-NDSfr3YI
  cid  33  sid   2  msgs    0  qgroup -              $JS.API.CONSUMER.RESET.ORDERS.JS_MIRROR_eCMlsqH6-NDSfr3YI
  cid  33  sid   3  msgs    0  qgroup -              $JS.FC.ORDERS.JS_MIRROR_eCMlsqH6-NDSfr3YI.*
  cid  33  sid   4  msgs    0  qgroup -              $JS.FC._.szMpdrwD.ORDERS.JS_MIRROR_eCMlsqH6-NDSfr3YI.*
  cid  35  sid   1  msgs    0  qgroup -              $JS.API.CONSUMER.MSG.NEXT.ORDERS.JS_SRC_wo4RcJXb-SS8vau7k
  cid  35  sid   2  msgs    0  qgroup -              $JS.API.CONSUMER.RESET.ORDERS.JS_SRC_wo4RcJXb-SS8vau7k
  cid  35  sid   3  msgs    0  qgroup -              $JS.FC.ORDERS.JS_SRC_wo4RcJXb-SS8vau7k.*
  cid  35  sid   4  msgs    0  qgroup -              $JS.FC._.szMpdrwD.ORDERS.JS_SRC_wo4RcJXb-SS8vau7k.*
  cid  44  sid   1  msgs   84  qgroup workers        orders.created
--- E2': one member on n1, three on n2; 400 publishes from n1 (repeated)
n1 member 105 · n2 members 98 / 102 / 95
n1's /subsz:
  num_subscriptions 32; non-$SYS entries 4:
  cid   4  sid   5  msgs   36  qgroup -              $JS.API.>
  cid  22  sid   1  msgs    0  qgroup _sys_          $JS.API.DIRECT.GET.ORDERS
  cid  22  sid   2  msgs    0  qgroup _sys_          $JS.API.DIRECT.GET.ORDERS.>
  cid  59  sid   1  msgs  105  qgroup workers        orders.created

### done
```

## Transcript — the third pass (`request-reply-run3.sh`)

```
### versions
nats-server: v2.14.6
0.4.0
--- the two logs (the leafnode connection):
[51282] 2026/09/03 19:16:02.551581 [INF] 127.0.0.1:17422 - lid:5 - Leafnode connection created for account: $G 
[51248] 2026/09/03 19:16:01.842689 [INF] Listening for leafnode connections on 0.0.0.0:17422
[51248] 2026/09/03 19:16:02.551624 [INF] 127.0.0.1:55246 - lid:5 - Leafnode connection created 
--- H1: one member on the hub, one on the leaf; 200 publishes on the hub
hub-a 200 · leaf-a 0
--- H2: the same members; 200 publishes on the leaf
hub-b 0 · leaf-b 200
--- H3: members only on the leaf (two); 200 publishes on the hub
leaf-c1 93 · leaf-c2 107
--- H4: two on the hub, one on the leaf; 200 publishes on the leaf
hub-d1 0 · hub-d2 0 · leaf-d 200
--- H5: two on the hub, two on the leaf; 200 publishes on the hub
hub-e1 148 · hub-e2 52 · leaf-e1 0 · leaf-e2 0
--- hub log lines (ERR/WRN):
--- leaf log lines (ERR/WRN):

### done
```

## Transcript — the fourth pass (`request-reply-run4.sh`)

```
### versions
nats-server: v2.14.6
0.4.0
1
--- H5.1: two on the hub, two on the leaf; 400 publishes on the hub
hub-e1-1 89 · hub-e2-1 311 · leaf-e1-1 0 · leaf-e2-1 0
--- H5.2: two on the hub, two on the leaf; 400 publishes on the hub
hub-e1-2 297 · hub-e2-2 103 · leaf-e1-2 0 · leaf-e2-2 0
--- H5.3: two on the hub, two on the leaf; 400 publishes on the hub
hub-e1-3 302 · hub-e2-3 98 · leaf-e1-3 0 · leaf-e2-3 0
--- H6: two on the hub, one on the leaf; 400 publishes on the hub
hub-f1 137 · hub-f2 263 · leaf-f 0
--- H7: three on the hub, two on the leaf; 400 publishes on the hub
hub-g1 70 · hub-g2 75 · hub-g3 255 · leaf-g1 0 · leaf-g2 0
--- H8: two on the hub, no leaf member; 400 publishes on the hub (the control)
hub-h1 196 · hub-h2 204

### done
```
