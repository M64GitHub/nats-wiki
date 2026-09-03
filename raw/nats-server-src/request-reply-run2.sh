#!/bin/bash
# request-reply-run2.sh — the second pass of request-reply-run.sh (same binary, nats-server v2.14.6, nats CLI 0.4.0,
# 2026-09-03): the /subsz views the first pass lost to a quoting slip in its helper (A1, C2, E1, E2 — subsz.py
# beside this file replaces it), the sentinel runs D8/D9 repeated with their transcripts kept, and E2 repeated.
set -u
cd "$(dirname "$0")"
PORT=14222; MON=18222
S="nats://127.0.0.1:$PORT"
L1=nats://127.0.0.1:4291; L2=nats://127.0.0.1:4292
start() { nats-server -c "$1" -P server.pid > "$2" 2>&1 & sleep 0.7; }
stop()  { kill "$(cat server.pid)" 2>/dev/null; sleep 0.4; }
now()   { python3 -c 'import time; print(f"{time.time():.3f}")'; }
since() { python3 -c "import time,sys; print(f'{time.time()-float(sys.argv[1]):.3f} s')" "$1"; }
trap 'kill $(cat server.pid 2>/dev/null) 2>/dev/null; kill $(jobs -p) 2>/dev/null' EXIT
echo "### versions"; nats-server --version; nats --version

echo; echo "### A1' — the two responders' subscriptions in /subsz"
start base.conf a1.log
nats reply --server $S orders.inventory.check '{"in_stock":true,"warehouse":"us-east"}' > a1-r1.log 2>&1 & R1=$!
nats reply --server $S orders.inventory.check --queue carrier-b '{"carrier":"carrier-b"}' > a1-r2.log 2>&1 & R2=$!
sleep 0.7; python3 subsz.py
kill $R1 $R2; sleep 0.3; stop

echo; echo "### C' — the readiness run again, with the /subsz msgs counters"
start base.conf c2.log
nats reply --server $S orders.inventory.check --queue inv fast > c2-fast.log 2>&1 & RF=$!
nats reply --server $S orders.inventory.check --queue inv --command ./slow.sh > c2-slow.log 2>&1 & RS=$!
sleep 0.7
echo "--- C1': 20 concurrent requests (--timeout 30s), timed"
T0=$(now); RP=()
for i in $(seq 1 20); do nats request --server $S orders.inventory.check "r$i" --timeout 30s --raw > c2-req-$i.log 2>&1 & RP+=($!); done
wait "${RP[@]}"
echo "elapsed: $(since $T0)"
echo "replies: fast $(cat c2-req-*.log | grep -c '^fast$') · slow $(cat c2-req-*.log | grep -c '^slow$')"
echo "member logs: fast received $(grep -c 'Received on' c2-fast.log) · slow received $(grep -c 'Received on' c2-slow.log)"
echo "--- C2': /subsz — msgs per member"; python3 subsz.py
kill $RF $RS; sleep 0.3; stop

echo; echo "### D8'/D9' — the sentinel, three times each, transcripts kept"
start base.conf d2.log
nats reply --server $S shipping.quote --queue carrier-a '{"carrier":"carrier-a","quote_cents":1500}' > d2-a.log 2>&1 & DA=$!
nats reply --server $S shipping.quote --queue carrier-b '{"carrier":"carrier-b","quote_cents":1200}' > d2-b.log 2>&1 & DB=$!
nats reply --server $S shipping.quote --queue carrier-end --command ./end.sh > d2-end.log 2>&1 & DE=$!
sleep 0.7
for n in 1 2 3; do
  echo "--- D8'.$n: --wait-for-empty --timeout 2s"
  T0=$(now); nats request --server $S shipping.quote '{"order_id":"ord_8w2k"}' --wait-for-empty --timeout 2s 2>&1 | sed 's/^/    /'; echo "    exit: ${PIPESTATUS[0]} after $(since $T0)"
  echo "--- D9'.$n: --replies 5 --timeout 2s"
  T0=$(now); nats request --server $S shipping.quote '{"order_id":"ord_8w2k"}' --replies 5 --timeout 2s 2>&1 | sed 's/^/    /'; echo "    exit: ${PIPESTATUS[0]} after $(since $T0)"
done
echo "--- D11: --replies 2 --timeout 2s against the same three (does the first two win, or the empty one end it?)"
T0=$(now); nats request --server $S shipping.quote '{"order_id":"ord_8w2k"}' --replies 2 --timeout 2s 2>&1 | sed 's/^/    /'; echo "    exit: ${PIPESTATUS[0]} after $(since $T0)"
echo "--- the sentinel responder's log (what it received and answered):"; sed 's/^/    /' d2-end.log | head -n 12
kill $DA $DB $DE; sleep 0.3; stop

echo; echo "### E1'/E2' — the lab again, with n1's /subsz view (port 8291)"
echo "--- E1': one member on n1, one on n2; 200 publishes from n1"
nats sub --server $L1 orders.created --queue workers > e1b-n1.log 2>&1 & P1=$!
nats sub --server $L2 orders.created --queue workers > e1b-n2.log 2>&1 & P2=$!
sleep 1.2
nats pub --server $L1 orders.created x --count 200 > /dev/null; sleep 0.8
echo "n1 member $(grep -c Received e1b-n1.log) · n2 member $(grep -c Received e1b-n2.log)"
echo "n1's /subsz:"; python3 subsz.py 8291
echo "n2's /subsz:"; python3 subsz.py 8292
kill $P1 $P2; sleep 0.6
echo "--- E2': one member on n1, three on n2; 400 publishes from n1 (repeated)"
nats sub --server $L1 orders.created --queue workers > e2b-n1.log 2>&1 & P1=$!
nats sub --server $L2 orders.created --queue workers > e2b-n2a.log 2>&1 & P2=$!
nats sub --server $L2 orders.created --queue workers > e2b-n2b.log 2>&1 & P3=$!
nats sub --server $L2 orders.created --queue workers > e2b-n2c.log 2>&1 & P4=$!
sleep 1.2
nats pub --server $L1 orders.created x --count 400 > /dev/null; sleep 0.8
echo "n1 member $(grep -c Received e2b-n1.log) · n2 members $(grep -c Received e2b-n2a.log) / $(grep -c Received e2b-n2b.log) / $(grep -c Received e2b-n2c.log)"
echo "n1's /subsz:"; python3 subsz.py 8291
kill $P1 $P2 $P3 $P4; sleep 0.4
rm -f server.pid
echo; echo "### done"
