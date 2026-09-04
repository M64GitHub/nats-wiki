#!/bin/bash
# Run D — Stop() drains, an abrupt exit does not.
set -um
D=$(cd "$(dirname "$0")" && pwd); cd "$D"
pkill -f 'service serve' 2>/dev/null; pkill -f 'nats-server -c' 2>/dev/null; pkill -f svcbin 2>/dev/null; sleep 0.5
N="nats --server nats://127.0.0.1:14222 --timeout=10s"
nats-server -c base.conf -l "$D/d-server.log" >/dev/null 2>&1 & S=$!
sleep 0.7

echo "=== D1 · Stop() while a request is in flight ==="
./go/svcbin -url nats://127.0.0.1:14222 -label A -slow 4s -stop-after 6s -hold-after-stop 8s > d-a.log 2>&1 & A=$!
sleep 1.2
echo "t≈1.2s  firing a slow request (handler blocks 4 s, Stop() lands at t≈6 s)"
( $N request orders.inventory.slow 'in-flight' ; echo "  ^ reply above" ) > d-slow.log 2>&1 & SLOW=$!
sleep 0.5
echo "t≈1.7s  a check request while the service is up"
$N request orders.inventory.check 'before' 2>&1 | grep -E 'Received|ok from|No respon'
wait $SLOW 2>/dev/null
echo "--- the in-flight slow request ---"; cat d-slow.log
sleep 2.0
echo "t≈7s (after Stop) a check request"
$N request orders.inventory.check 'after' 2>&1 | grep -E 'Received|ok from|No respon'
echo "t≈7s (after Stop) a \$SRV.PING"
nats --server nats://127.0.0.1:14222 --timeout=1s request '$SRV.PING' '' --replies=0 2>&1 | grep -E 'Received|ping_response|Timeout|No respon' | head -3
echo "--- the instance's log ---"; cat d-a.log
echo "--- /subsz after Stop() ---"; python3 subsz.py 18222 | grep -vc '^ ' ; python3 subsz.py 18222 | head -2
kill -9 $A 2>/dev/null; sleep 0.3

echo
echo "=== D2 · SIGKILL (no Stop) while a request is in flight ==="
./go/svcbin -url nats://127.0.0.1:14222 -label K -slow 4s > d-k.log 2>&1 & K=$!
sleep 1.2
( $N request orders.inventory.slow 'in-flight-killed' ; echo "  ^ reply above" ) > d-killed.log 2>&1 & SL2=$!
sleep 1.0
echo "t≈1.0s into the handler: SIGKILL the instance"
kill -9 $K
wait $SL2 2>/dev/null
echo "--- the caller ---"; cat d-killed.log
echo "--- the instance's log ---"; tail -2 d-k.log
echo "--- the server saw ---"; tail -2 d-server.log

kill -9 $S 2>/dev/null
echo "=== D done ==="
