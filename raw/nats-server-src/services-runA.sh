#!/bin/bash
set -m   # job control: background jobs take SIGINT (without it a script backgrounds with SIGINT ignored)
# Run A — the nats CLI demo service: what `nats service serve` creates, and what the
# $SRV tree answers. nats-server v2.14.6, nats CLI 0.4.0.
set -u
D=$(cd "$(dirname "$0")" && pwd); cd "$D"
N="nats --server nats://127.0.0.1:14222 --timeout=2s"
pkill -f 'service serve' 2>/dev/null; pkill -f 'nats-server -c' 2>/dev/null; sleep 0.5
nats-server -c base.conf -l "$D/a-server.log" >/dev/null 2>&1 & SRV=$!
sleep 0.8

echo "=== A1 · two demo instances of the same service ==="
$N service serve DEMO > a-demo1.log 2>&1 & D1=$!
sleep 0.6
$N service serve DEMO > a-demo2.log 2>&1 & D2=$!
sleep 1.0
cat a-demo1.log

echo
echo "=== A2 · nats service list --json (both instances) ==="
$N service list --json

echo
echo "=== A3 · nats service info DEMO — how many instances does it show? ==="
$N service info DEMO

echo
echo "=== A4 · the raw \$SRV.INFO body, one reply per instance ==="
$N request '$SRV.INFO' '' --replies=0

echo
echo "=== A5 · the raw \$SRV.PING body ==="
$N request '$SRV.PING' '' --replies=0

echo
echo "=== A6 · six requests to DEMO.echo, then stats ==="
for i in 1 2 3 4 5 6; do $N request DEMO.echo "req-$i" >/dev/null 2>&1; done
$N service stats DEMO

echo
echo "=== A7 · the raw \$SRV.STATS.DEMO body ==="
$N request '$SRV.STATS.DEMO' '' --replies=0

echo
echo "=== A8 · nats service ping DEMO ==="
$N service ping DEMO

echo
echo "=== A9 · the subscriptions the two instances made (/subsz) ==="
python3 subsz.py 18222

echo
echo "=== A10 · a request to \$SRV.INFO.DEMO.<id> — one instance only ==="
ID=$($N service list --json | python3 -c 'import json,sys; print(json.load(sys.stdin)[0]["id"])')
echo "targeting id=$ID"
$N request "\$SRV.INFO.DEMO.$ID" '' --replies=0

echo
echo "=== A11 · SIGINT on one instance, then list ==="
# job control on, so the backgrounded CLI does not inherit SIG_IGN for SIGINT
kill -INT $D1; sleep 1.2
$N service list
echo "--- the interrupted instance's last lines ---"
tail -3 a-demo1.log
echo "--- server log around the disconnect ---"
tail -4 a-server.log

kill -9 $D2 $SRV 2>/dev/null
echo "=== A done ==="
