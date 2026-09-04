#!/bin/bash
# Run C — a real micro service (nats.go v1.53.1): groups, per-endpoint queue groups,
# the service error on the wire, and whether one blocked endpoint blocks the others.
set -um
D=$(cd "$(dirname "$0")" && pwd); cd "$D"
pkill -f 'service serve' 2>/dev/null; pkill -f 'nats-server -c' 2>/dev/null; pkill -f svcbin 2>/dev/null; sleep 0.5
N="nats --server nats://127.0.0.1:14222 --timeout=8s"
nats-server -c base.conf -l "$D/c-server.log" >/dev/null 2>&1 & S=$!
sleep 0.7

echo "=== C1 · one instance: the endpoint/subject/queue-group layout ==="
./go/svcbin -url nats://127.0.0.1:14222 -label A > c-a.log 2>&1 & A=$!
sleep 1.0
head -3 c-a.log
$N service info Inventory

echo
echo "=== C2 · the subscriptions one instance makes ==="
python3 subsz.py 18222

echo
echo "=== C3 · the 'bad' endpoint: the service error on the wire ==="
echo "--- nats request (shows headers?) ---"
$N request orders.inventory.bad '{"total":-1}' 2>&1 | head -8
echo "--- the same request read by a raw client ---"
python3 svc-raw.py --port 14222 --wait 2 --pong \
  --send 'CONNECT {"verbose":false,"headers":true,"no_responders":true}' \
  --send 'SUB _INBOX.RAW.1 1' \
  --send 'PUB orders.inventory.bad _INBOX.RAW.1 13' --send '{"total":-1}' 2>&1 | tail -6

echo
echo "=== C4 · stats after one error ==="
$N service stats Inventory --json | python3 -c '
import json,sys
for s in json.load(sys.stdin):
    for e in s["endpoints"]:
        print("  %-8s q=%-6s reqs=%-3s errs=%-3s last_error=%r" % (e["name"], e.get("queue_group","-"), e["num_requests"], e["num_errors"], e.get("last_error","")))
'

echo
echo "=== C5 · does a blocked endpoint block the others on the same instance? ==="
( $N request orders.inventory.slow 'blocking' > c-slow.log 2>&1 ) & SLOW=$!
sleep 0.3
echo "t+0.3s: firing check while slow is blocking"
/usr/bin/time -p $N request orders.inventory.check 'fast' 2>&1 | tail -5
wait $SLOW
echo "--- slow's reply ---"; tail -2 c-slow.log
echo "--- the instance's own log ---"; tail -6 c-a.log

echo
echo "=== C6 · a second instance: bcast (queue group disabled) vs check (queue group q) ==="
./go/svcbin -url nats://127.0.0.1:14222 -label B > c-b.log 2>&1 & B=$!
sleep 1.0
echo "--- 6 requests to check (queue group q) ---"
for i in 1 2 3 4 5 6; do $N request orders.inventory.check "r$i" >/dev/null 2>&1; done
echo "--- one request to bcast, --replies=0 (queue group disabled) ---"
$N request orders.inventory.bcast 'who is there' --replies=0 --timeout=1s 2>&1 | grep -E 'Received|bcast from'
echo "--- per-instance stats ---"
$N service stats Inventory --json | python3 -c '
import json,sys
for s in json.load(sys.stdin):
    lbl=[e for e in s["endpoints"]]
    print(" instance", s["id"], "data.label=", (s["endpoints"][0].get("data") or {}).get("label"))
    for e in s["endpoints"]:
        if e["num_requests"]: print("    %-8s q=%-6s reqs=%s" % (e["name"], e.get("queue_group","-"), e["num_requests"]))
'
echo "--- /subsz: which endpoint subjects carry a queue group ---"
python3 subsz.py 18222 | grep -v '\$SRV'

kill -9 $A $B $S 2>/dev/null
echo "=== C done ==="
