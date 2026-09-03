#!/bin/bash
# request-reply-run.sh — nats-server v2.14.6, nats CLI 0.4.0, macOS, 2026-09-03.
# Runs A–D and G of phase F step 2 (request/reply, the 503, scatter-gather timing, queue groups, the 503 over
# a service import) on one standalone server — port 14222, monitoring 18222, configs written beside this
# script, one server per scene — and run E on the three-node lab of tools/lab/cluster.sh (n1 4291, n2 4292,
# n3 4293; plain clients land in $G with no credentials). core-delivery-raw.py beside this file (step 1's
# raw protocol writer) sends CONNECT + verbatim lines and prints what comes back.
set -u
cd "$(dirname "$0")"
PORT=14222; MON=18222
S="nats://127.0.0.1:$PORT"
L1=nats://127.0.0.1:4291; L2=nats://127.0.0.1:4292; L3=nats://127.0.0.1:4293
RAW()   { python3 core-delivery-raw.py --port $PORT "$@"; }
start() { nats-server -c "$1" -P server.pid > "$2" 2>&1 & sleep 0.7; }
stop()  { kill "$(cat server.pid)" 2>/dev/null; sleep 0.4; }
now()   { python3 -c 'import time; print(f"{time.time():.3f}")'; }
since() { python3 -c "import time,sys; print(f'{time.time()-float(sys.argv[1]):.3f} s')" "$1"; }
subsz() { curl -s "http://127.0.0.1:${1:-$MON}/subsz?subs=1&acc=\$G" | python3 -c '
import json,sys
d=json.load(sys.stdin)
subs=[s for s in d.get("subscriptions_list",[]) if not s["subject"].startswith("$SYS")]
print(f"  num_subscriptions {d[\"num_subscriptions\"]}; non-$SYS entries {len(subs)}:")
for s in sorted(subs, key=lambda s:(s["cid"],int(s["sid"]))):
    print(f"  cid {s[\"cid\"]:>3}  sid {s[\"sid\"]:>3}  msgs {s[\"msgs\"]:>4}  qgroup {s.get(\"qgroup\",\"-\"):<14} {s[\"subject\"]}")'; }
trap 'kill $(cat server.pid 2>/dev/null) 2>/dev/null; kill $(jobs -p) 2>/dev/null' EXIT
if lsof -nP -iTCP:$PORT -sTCP:LISTEN >/dev/null 2>&1; then echo "port $PORT busy"; exit 1; fi

echo "### versions"; nats-server --version; nats --version; python3 --version
cat > base.conf <<CONF
port: $PORT
http: $MON
server_name: rrlab
CONF

echo; echo "### A — nats reply's default queue group NATS-RPLY-22, a second group, and what a request receives"
start base.conf a.log
nats reply --server $S orders.inventory.check '{"in_stock":true,"warehouse":"us-east"}' > a-r1.log 2>&1 & R1=$!
nats reply --server $S orders.inventory.check --queue carrier-b '{"carrier":"carrier-b"}' > a-r2.log 2>&1 & R2=$!
sleep 0.7
echo "--- A1: /subsz?subs=1&acc=\$G — the two responders' subscriptions"; subsz
echo "--- A2: nats request with the defaults (--replies 1 --timeout 5s)"
nats request --server $S orders.inventory.check '{"order_id":"ord_8w2k"}'; echo "exit: $?"
echo "--- A3: --replies 0 --timeout 2s — every reply until the timeout, timed"
T0=$(now); nats request --server $S orders.inventory.check '{"order_id":"ord_8w2k"}' --replies 0 --timeout 2s; echo "exit: $? after $(since $T0)"
echo "--- A4: a third nats reply in the default group; --replies 0 --timeout 2s again"
nats reply --server $S orders.inventory.check '{"in_stock":true,"warehouse":"eu-west"}' > a-r3.log 2>&1 & R3=$!; sleep 0.7
nats request --server $S orders.inventory.check '{"order_id":"ord_8w2k"}' --replies 0 --timeout 2s; echo "exit: $?"
echo "--- A5: 40 requests with --replies 2 --timeout 2s; how the default group split them"
nats request --server $S orders.inventory.check 'r{{Count}}' --count 40 --replies 2 --timeout 2s > a5.log 2>&1; echo "exit: $?"
echo "received: us-east (r1) $(grep -c 'Received on' a-r1.log) · eu-west (r3) $(grep -c 'Received on' a-r3.log) · carrier-b (r2) $(grep -c 'Received on' a-r2.log)"
subsz
kill $R1 $R2 $R3 2>/dev/null; sleep 0.3
stop

echo; echo "### B — the 503 over the raw protocol, and what the CLI makes of it (F: exit codes)"
start base.conf b.log
echo "--- B1: CONNECT headers+no_responders, SUB _INBOX.x 1, PUB nobody _INBOX.x 0"
RAW --connect '{"headers":true,"no_responders":true}' --send 'SUB _INBOX.x 1' --send 'PUB nobody _INBOX.x 0' --send '' --send 'PING' --wait 1
echo "--- B2: the same with no_responders:false"
RAW --connect '{"headers":true,"no_responders":false}' --send 'SUB _INBOX.x 1' --send 'PUB nobody _INBOX.x 0' --send '' --send 'PING' --wait 1
echo "--- B3: no_responders:true without headers"
RAW --connect '{"headers":false,"no_responders":true}' --send 'PING' --wait 1
echo "--- B4: no_responders, a reply subject this connection is not subscribed to"
RAW --connect '{"headers":true,"no_responders":true}' --send 'PUB nobody _INBOX.y 0' --send '' --send 'PING' --wait 1
echo "--- B5: no_responders, with a subscriber on the subject that never replies (nats sub nobody)"
nats sub --server $S nobody > b5-tap.log 2>&1 & TAP=$!; sleep 0.5
RAW --connect '{"headers":true,"no_responders":true}' --send 'SUB _INBOX.x 1' --send 'PUB nobody _INBOX.x 0' --send '' --send 'PING' --wait 1
kill $TAP; sleep 0.3
echo "--- B6 (F): nats request to a subject with no subscriber — the line, the time, the exit code"
T0=$(now); nats request --server $S nobody x --timeout 2s; echo "exit: $? after $(since $T0)"
echo "--- B7 (F): nats request to a subject whose subscriber never replies — the timeout, the exit code"
nats sub --server $S nobody > b7-tap.log 2>&1 & TAP=$!; sleep 0.5
T0=$(now); nats request --server $S nobody x --timeout 1s; echo "exit: $? after $(since $T0)"
kill $TAP; sleep 0.3
echo "--- B8 (F): a successful request's exit code (nats reply --count 1 quits after one)"
nats reply --server $S ping pong --count 1 > b8.log 2>&1 & sleep 0.5
nats request --server $S ping x --timeout 2s; echo "exit: $?"
echo "--- server log lines (ERR/WRN) for B"; grep -E '\[ERR\]|\[WRN\]' b.log
stop

echo; echo "### C — the readiness claim: two members of one group, one busy for 1 s per request"
start base.conf c.log
printf '#!/bin/sh\nsleep 1\necho slow\n' > slow.sh; chmod +x slow.sh
nats reply --server $S orders.inventory.check --queue inv fast > c-fast.log 2>&1 & RF=$!
nats reply --server $S orders.inventory.check --queue inv --command ./slow.sh > c-slow.log 2>&1 & RS=$!
sleep 0.7
echo "--- C1: 20 concurrent requests (--timeout 30s), timed"
T0=$(now); RP=()
for i in $(seq 1 20); do nats request --server $S orders.inventory.check "r$i" --timeout 30s --raw > c1-req-$i.log 2>&1 & RP+=($!); done
wait "${RP[@]}"
echo "elapsed: $(since $T0)"
echo "replies: fast $(cat c1-req-*.log | grep -c '^fast$') · slow $(cat c1-req-*.log | grep -c '^slow$') · other $(cat c1-req-*.log | grep -vc '^fast$\|^slow$')"
echo "member logs: fast received $(grep -c 'Received on' c-fast.log) · slow received $(grep -c 'Received on' c-slow.log)"
echo "--- C2: /subsz — msgs per member"; subsz
echo "--- C3: 20 sequential requests (--count 20 --timeout 5s), timed"
T0=$(now); nats request --server $S orders.inventory.check 'r{{Count}}' --count 20 --timeout 5s --raw > c3.log 2>&1; echo "exit: $? after $(since $T0)"
echo "replies: fast $(grep -c '^fast$' c3.log) · slow $(grep -c '^slow$' c3.log)"
kill $RF $RS 2>/dev/null; sleep 0.3
stop

echo; echo "### D — scatter-gather: --replies N, --replies 0, --reply-timeout and --wait-for-empty, timed"
start base.conf d.log
req() { local label=$1; shift; echo "--- $label"; T0=$(now); nats request --server $S shipping.quote '{"order_id":"ord_8w2k"}' "$@" > d-run.log 2>&1; local rc=$?; echo "replies: $(grep -c 'Received with rtt' d-run.log) [ $(grep -oE 'carrier-[a-z]+|No responders are available' d-run.log | tr '\n' ' ')] exit: $rc after $(since $T0)"; }
nats reply --server $S shipping.quote --queue carrier-a '{"carrier":"carrier-a","quote_cents":1500}' > d-a.log 2>&1 & DA=$!
nats reply --server $S shipping.quote --queue carrier-b '{"carrier":"carrier-b","quote_cents":1200}' > d-b.log 2>&1 & DB=$!
nats reply --server $S shipping.quote --queue carrier-c '{"carrier":"carrier-c","quote_cents":1800}' > d-c.log 2>&1 & DC=$!
sleep 0.7
req "D1: three responders, --replies 3 --timeout 2s" --replies 3 --timeout 2s
req "D2: three responders, --replies 0 --timeout 2s" --replies 0 --timeout 2s
req "D3: three responders, the default --replies 1" --timeout 2s
kill $DC; sleep 0.4
req "D4: two responders, --replies 3 --timeout 2s (--reply-timeout at its 300ms default)" --replies 3 --timeout 2s
req "D5: two responders, --replies 3 --reply-timeout 1s --timeout 2s" --replies 3 --reply-timeout 1s --timeout 2s
req "D6: two responders, --replies 0 --timeout 2s --reply-timeout 50ms (the docs: no effect)" --replies 0 --timeout 2s --reply-timeout 50ms
kill $DA $DB; sleep 0.4
req "D7: no responders, --replies 0 --timeout 2s" --replies 0 --timeout 2s
printf '#!/bin/sh\nsleep 0.2\n' > end.sh; chmod +x end.sh
nats reply --server $S shipping.quote --queue carrier-a '{"carrier":"carrier-a","quote_cents":1500}' > d-a2.log 2>&1 & DA=$!
nats reply --server $S shipping.quote --queue carrier-b '{"carrier":"carrier-b","quote_cents":1200}' > d-b2.log 2>&1 & DB=$!
nats reply --server $S shipping.quote --queue carrier-end --command ./end.sh > d-end.log 2>&1 & DE=$!
sleep 0.7
req "D8: two quoting responders + one answering an empty body after 200 ms: --wait-for-empty --timeout 2s" --wait-for-empty --timeout 2s
req "D9: the same three, --replies 5 --timeout 2s, no --wait-for-empty" --replies 5 --timeout 2s
req "D10: the same three, --replies 0 --timeout 2s" --replies 0 --timeout 2s
kill $DA $DB $DE; sleep 0.3
stop

echo; echo "### E — queue-group selection across the lab's three nodes, publisher on n1"
bash ../../../../tools/lab/cluster.sh status | head -n 4
echo "--- E1: one member on n1, one on n2; 200 publishes from n1"
nats sub --server $L1 orders.created --queue workers > e1-n1.log 2>&1 & P1=$!
nats sub --server $L2 orders.created --queue workers > e1-n2.log 2>&1 & P2=$!
sleep 1.2
nats pub --server $L1 orders.created x --count 200 > /dev/null; sleep 0.8
echo "n1 member $(grep -c Received e1-n1.log) · n2 member $(grep -c Received e1-n2.log)"
echo "n1's /subsz:"; subsz 8291
kill $P1 $P2; sleep 0.6
echo "--- E2: one member on n1, three on n2; 400 publishes from n1"
nats sub --server $L1 orders.created --queue workers > e2-n1.log 2>&1 & P1=$!
nats sub --server $L2 orders.created --queue workers > e2-n2a.log 2>&1 & P2=$!
nats sub --server $L2 orders.created --queue workers > e2-n2b.log 2>&1 & P3=$!
nats sub --server $L2 orders.created --queue workers > e2-n2c.log 2>&1 & P4=$!
sleep 1.2
nats pub --server $L1 orders.created x --count 400 > /dev/null; sleep 0.8
echo "n1 member $(grep -c Received e2-n1.log) · n2 members $(grep -c Received e2-n2a.log) / $(grep -c Received e2-n2b.log) / $(grep -c Received e2-n2c.log)"
echo "n1's /subsz:"; subsz 8291
kill $P1 $P2 $P3 $P4; sleep 0.6
echo "--- E3: no member on n1; one on n2, one on n3; 200 publishes from n1"
nats sub --server $L2 orders.created --queue workers > e3-n2.log 2>&1 & P2=$!
nats sub --server $L3 orders.created --queue workers > e3-n3.log 2>&1 & P3=$!
sleep 1.2
nats pub --server $L1 orders.created x --count 200 > /dev/null; sleep 0.8
echo "n2 member $(grep -c Received e3-n2.log) · n3 member $(grep -c Received e3-n3.log)"
kill $P2 $P3; sleep 0.6
echo "--- E4: two members on n1, one on n2; 300 publishes from n1"
nats sub --server $L1 orders.created --queue workers > e4-n1a.log 2>&1 & P1=$!
nats sub --server $L1 orders.created --queue workers > e4-n1b.log 2>&1 & P2=$!
nats sub --server $L2 orders.created --queue workers > e4-n2.log 2>&1 & P3=$!
sleep 1.2
nats pub --server $L1 orders.created x --count 300 > /dev/null; sleep 0.8
echo "n1 members $(grep -c Received e4-n1a.log) / $(grep -c Received e4-n1b.log) · n2 member $(grep -c Received e4-n2.log)"
kill $P1 $P2 $P3; sleep 0.6
echo "--- E5: a plain subscriber on n3 beside E1's shape; 200 publishes from n1"
nats sub --server $L1 orders.created --queue workers > e5-n1.log 2>&1 & P1=$!
nats sub --server $L2 orders.created --queue workers > e5-n2.log 2>&1 & P2=$!
nats sub --server $L3 orders.created > e5-n3-plain.log 2>&1 & P3=$!
sleep 1.2
nats pub --server $L1 orders.created x --count 200 > /dev/null; sleep 0.8
echo "n1 member $(grep -c Received e5-n1.log) · n2 member $(grep -c Received e5-n2.log) · n3 plain $(grep -c Received e5-n3-plain.log)"
kill $P1 $P2 $P3; sleep 0.4

echo; echo "### G — the 503 across a service import (bank row 150)"
cat > g.conf <<CONF
port: $PORT
http: $MON
server_name: rrlab
accounts {
  SVC: {
    users: [ { user: svc, password: svc } ]
    exports: [ { service: "svc.>" } ]
  }
  APP: {
    users: [ { user: app, password: app } ]
    imports: [
      { service: { account: SVC, subject: "svc.check" } },
      { service: { account: SVC, subject: "svc.stock" }, to: "inv.stock" }
    ]
  }
}
CONF
nats-server -t -c g.conf; echo "exit (-t): $?"
start g.conf g.log
echo "--- G1: APP requests svc.check with nobody in SVC — timed, exit code"
T0=$(now); nats request --server $S --user app --password app svc.check x --timeout 2s; echo "exit: $? after $(since $T0)"
echo "--- G2: the same over the raw protocol — the 503's Nats-Subject"
RAW --connect '{"user":"app","pass":"app","headers":true,"no_responders":true}' --send 'SUB _INBOX.x 1' --send 'PUB svc.check _INBOX.x 0' --send '' --send 'PING' --wait 1
echo "--- G3: the renamed import inv.stock, raw — which subject the header names"
RAW --connect '{"user":"app","pass":"app","headers":true,"no_responders":true}' --send 'SUB _INBOX.x 1' --send 'PUB inv.stock _INBOX.x 0' --send '' --send 'PING' --wait 1
echo "--- G4: a responder in SVC on svc.check; APP's request"
nats reply --server $S --user svc --password svc svc.check '{"in_stock":true}' > g4.log 2>&1 & GR=$!; sleep 0.7
nats request --server $S --user app --password app svc.check x --timeout 2s; echo "exit: $?"
echo "--- G5: a responder in SVC on svc.stock; APP's request on inv.stock"
nats reply --server $S --user svc --password svc svc.stock '{"stock":7}' > g5.log 2>&1 & GR2=$!; sleep 0.7
nats request --server $S --user app --password app inv.stock x --timeout 2s; echo "exit: $?"
echo "--- G6: APP requests a subject it never imported (other.x)"
T0=$(now); nats request --server $S --user app --password app other.x x --timeout 2s; echo "exit: $? after $(since $T0)"
kill $GR $GR2; sleep 0.3
echo "--- server log lines (ERR/WRN) for G"; grep -E '\[ERR\]|\[WRN\]' g.log
stop
rm -f server.pid
echo; echo "### done"
