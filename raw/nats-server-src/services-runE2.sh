#!/bin/bash
# Run E2 — the hub's subscription table with a service on the leaf (the leaf-origin interest).
set -um
D=$(cd "$(dirname "$0")" && pwd); cd "$D"
pkill -f svcbin 2>/dev/null; pkill -f 'nats-server -c' 2>/dev/null; sleep 0.5
nats-server -c hub.conf -l "$D/e2-hub.log" >/dev/null 2>&1 & H=$!
sleep 0.6
nats-server -c leaf.conf -l "$D/e2-leaf.log" >/dev/null 2>&1 & L=$!
sleep 1.2
./go/svcbin -url nats://127.0.0.1:14223 -label LEAF > e2-svc.log 2>&1 & SV=$!
sleep 1.2
echo "--- the HUB's /subsz?subs=1 (all accounts), the leaf-origin entries ---"
curl -s 'http://127.0.0.1:18222/subsz?subs=1&acc=$G' | python3 -c '
import json,sys
d=json.load(sys.stdin)
print("num_subscriptions", d["num_subscriptions"])
for s in sorted(d.get("subscriptions_list",[]), key=lambda x:x["subject"]):
    if s["subject"].startswith("$SYS"): continue
    print("   %-46s account=%-4s qgroup=%-6s cid=%s" % (s["subject"], s.get("account","-"), s.get("qgroup","-"), s.get("cid","-")))
'
echo "--- the LEAF's own /subsz?subs=1 ---"
curl -s 'http://127.0.0.1:18223/subsz?subs=1&acc=$G' | python3 -c '
import json,sys
d=json.load(sys.stdin)
print("num_subscriptions", d["num_subscriptions"])
n=0
for s in sorted(d.get("subscriptions_list",[]), key=lambda x:x["subject"]):
    if s["subject"].startswith("$SYS"): continue
    n+=1
print("   non-$SYS entries:", n)
'
kill -9 $SV $L $H 2>/dev/null
echo "=== E2 done ==="
