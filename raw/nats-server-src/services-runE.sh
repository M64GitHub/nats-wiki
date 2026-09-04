#!/bin/bash
# Run E — does $SRV discovery and a service endpoint cross a leafnode?
# (learn/services/where-next.md:42 promises this in Topologies; no docs page covers it.)
set -um
D=$(cd "$(dirname "$0")" && pwd); cd "$D"
pkill -f svcbin 2>/dev/null; pkill -f 'nats-server -c' 2>/dev/null; pkill -f 'service serve' 2>/dev/null; sleep 0.5
nats-server -c hub.conf  -l "$D/e-hub.log"  >/dev/null 2>&1 & H=$!
sleep 0.6
nats-server -c leaf.conf -l "$D/e-leaf.log" >/dev/null 2>&1 & L=$!
sleep 1.2
HUB="nats --server nats://127.0.0.1:14222 --timeout=2s"
LEAF="nats --server nats://127.0.0.1:14223 --timeout=2s"
echo "--- the leafnode connection ---"; grep -i 'leafnode connection' e-hub.log e-leaf.log | head -4

echo
echo "=== E1 · a service on the LEAF, discovered from the HUB ==="
./go/svcbin -url nats://127.0.0.1:14223 -label LEAF > e-svc.log 2>&1 & SV=$!
sleep 1.2
echo "--- from the leaf itself ---"
$LEAF service list
echo "--- from the hub, across the leafnode ---"
$HUB service list
echo "--- \$SRV.PING from the hub ---"
$HUB request '$SRV.PING' '' --replies=0 2>&1 | grep -E 'ping_response|No respon|Timeout'
echo "--- calling the endpoint from the hub ---"
$HUB request orders.inventory.check 'from the hub' 2>&1 | grep -E 'Received|ok from|No respon'

echo
echo "=== E2 · what the leafnode carried: the hub's view of the leaf's interest ==="
python3 subsz.py 18222 | head -20

echo
echo "=== E3 · a second instance on the HUB — one queue group across the leafnode? ==="
./go/svcbin -url nats://127.0.0.1:14222 -label HUB > e-svc2.log 2>&1 & SV2=$!
sleep 1.2
echo "--- 8 requests to check, from the hub ---"
for i in 1 2 3 4 5 6 7 8; do $HUB request orders.inventory.check "h$i" 2>&1 | grep -o 'ok from [A-Z]*'; done | sort | uniq -c
echo "--- 8 requests to check, from the leaf ---"
for i in 1 2 3 4 5 6 7 8; do $LEAF request orders.inventory.check "l$i" 2>&1 | grep -o 'ok from [A-Z]*'; done | sort | uniq -c
echo "--- service list from the hub: how many instances? ---"
$HUB service list

kill -9 $SV $SV2 $L $H 2>/dev/null
echo "=== E done ==="
