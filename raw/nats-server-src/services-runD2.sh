#!/bin/bash
# Run D2 — Stop() called while a handler is genuinely mid-flight (the scaling.md:164 claim).
set -um
D=$(cd "$(dirname "$0")" && pwd); cd "$D"
pkill -f svcbin 2>/dev/null; pkill -f 'nats-server -c' 2>/dev/null; sleep 0.5
N="nats --server nats://127.0.0.1:14222 --timeout=12s"
nats-server -c base.conf -l "$D/d2-server.log" >/dev/null 2>&1 & S=$!
sleep 0.7
# handler blocks 5 s; Stop() lands at t=3 s, i.e. 2 s into the handler
./go/svcbin -url nats://127.0.0.1:14222 -label A -slow 5s -stop-after 3s -hold-after-stop 10s > d2-a.log 2>&1 & A=$!
sleep 1.0
echo "t≈1.0s  firing slow (handler blocks 5 s); Stop() will land at t≈3.0s, 2 s into the handler"
( $N request orders.inventory.slow 'mid-flight' ) > d2-slow.log 2>&1 & SLOW=$!
sleep 2.6
echo "t≈3.6s (just after Stop) — a check request, and \$SRV.PING"
nats --server nats://127.0.0.1:14222 --timeout=1s request orders.inventory.check 'after-stop' 2>&1 | grep -E 'Received|ok from|No respon'
nats --server nats://127.0.0.1:14222 --timeout=1s request '$SRV.PING' '' --replies=0 2>&1 | grep -E 'ping_response|No respon|Timeout' | head -2
wait $SLOW 2>/dev/null
echo "--- did the mid-flight request still get its reply? ---"; cat d2-slow.log
echo "--- the instance's log ---"; cat d2-a.log
kill -9 $A $S 2>/dev/null
echo "=== D2 done ==="
