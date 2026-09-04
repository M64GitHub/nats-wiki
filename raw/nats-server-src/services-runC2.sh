#!/bin/bash
# Run C2 — the corrected scenes: the service error on the raw wire, the blocked-endpoint
# timing with both replies captured, and broadcast vs queue group across two instances.
set -um
D=$(cd "$(dirname "$0")" && pwd); cd "$D"
pkill -f 'service serve' 2>/dev/null; pkill -f 'nats-server -c' 2>/dev/null; pkill -f svcbin 2>/dev/null; sleep 0.5
N="nats --server nats://127.0.0.1:14222 --timeout=8s"
nats-server -c base.conf -l "$D/c2-server.log" >/dev/null 2>&1 & S=$!
sleep 0.7
./go/svcbin -url nats://127.0.0.1:14222 -label A > c2-a.log 2>&1 & A=$!
sleep 1.0

echo "=== C3' · the service error as bytes on the wire ==="
python3 svc-raw.py --port 14222 --wait 2 --pong \
  --send 'CONNECT {"verbose":false,"headers":true,"no_responders":true}' \
  --send 'SUB _INBOX.RAW.1 1' \
  --send 'PUB orders.inventory.bad _INBOX.RAW.1 12' --send '{"total":-1}' 2>&1 | tail -4

echo
echo "=== C3'' · a request to an endpoint nobody serves (no-responders) vs a service error ==="
python3 svc-raw.py --port 14222 --wait 2 --pong \
  --send 'CONNECT {"verbose":false,"headers":true,"no_responders":true}' \
  --send 'SUB _INBOX.RAW.2 1' \
  --send 'PUB orders.inventory.nosuch _INBOX.RAW.2 2' --send 'hi' 2>&1 | tail -3

echo
echo "=== C5' · a blocked endpoint and its siblings, timed ==="
( echo "slow  sent   $(date +%H:%M:%S.%3N)"; $N request orders.inventory.slow 'blocking'; echo "slow  done   $(date +%H:%M:%S.%3N)" ) > c2-slow.log 2>&1 & SLOW=$!
sleep 0.3
( echo "check sent   $(date +%H:%M:%S.%3N)"; $N request orders.inventory.check 'fast'; echo "check done   $(date +%H:%M:%S.%3N)" ) > c2-check.log 2>&1 & CHK=$!
sleep 0.3
( echo "vip   sent   $(date +%H:%M:%S.%3N)"; $N request orders.inventory.vip 'vip'; echo "vip   done   $(date +%H:%M:%S.%3N)" ) > c2-vip.log 2>&1 & VIP=$!
wait $SLOW $CHK $VIP 2>/dev/null
echo "--- check (fired 0.3 s into the 3 s block) ---"; cat c2-check.log
echo "--- vip (fired 0.6 s in) ---"; cat c2-vip.log
echo "--- slow ---"; cat c2-slow.log
echo "--- the instance's handler log ---"; tail -5 c2-a.log

echo
echo "=== C6' · two instances: bcast has no queue group ==="
./go/svcbin -url nats://127.0.0.1:14222 -label B > c2-b.log 2>&1 & B=$!
sleep 1.0
echo "--- one request to bcast, --replies=0 ---"
nats --server nats://127.0.0.1:14222 --timeout=1s request orders.inventory.bcast 'who is there' --replies=0 2>&1 | grep -E 'Received|bcast from'
echo "--- one request to check (queue group q) ---"
nats --server nats://127.0.0.1:14222 --timeout=1s request orders.inventory.check 'once' --replies=0 2>&1 | grep -E 'Received|ok from'
echo "--- one request to vip (queue group q-vip) ---"
nats --server nats://127.0.0.1:14222 --timeout=1s request orders.inventory.vip 'once' --replies=0 2>&1 | grep -E 'Received|vip from'

echo
echo "=== C7' · a request while the second instance is blocked: does the queue group route around it? ==="
echo "--- 8 requests to slow across two instances, both handlers block 3 s ---"
for i in 1 2 3 4 5 6 7 8; do ( $N request orders.inventory.slow "s$i" > c2-s$i.log 2>&1 ) & done
wait 2>/dev/null
grep -h 'slow from' c2-s*.log | sort | uniq -c
echo "--- how long each took ---"
for i in 1 2 3 4 5 6 7 8; do printf "s%s: " $i; grep -c 'slow from' c2-s$i.log; done
echo "--- the two handler logs ---"
grep -c 'slow    <-' c2-a.log; grep -c 'slow    <-' c2-b.log

kill -9 $A $B $S 2>/dev/null
echo "=== C2 done ==="
