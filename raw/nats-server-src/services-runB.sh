#!/bin/bash
# Run B — is $SRV reserved by the server, and what do subject permissions do to discovery?
set -um
D=$(cd "$(dirname "$0")" && pwd); cd "$D"
pkill -f 'service serve' 2>/dev/null; pkill -f 'nats-server -c' 2>/dev/null; sleep 0.5

echo "=== B1 · a plain client publishes to \$SRV.PING on a server with no auth ==="
nats-server -c base.conf -l "$D/b-server.log" >/dev/null 2>&1 & S1=$!
sleep 0.7
N="nats --server nats://127.0.0.1:14222 --timeout=2s"
$N service serve DEMO > b-demo.log 2>&1 & B1=$!
sleep 0.8
echo "--- nats pub '\$SRV.PING' hello (an ordinary client publishing into the tree) ---"
$N pub '$SRV.PING' hello ; echo "pub exit=$?"
echo "--- nats sub '\$SRV.>' for 1.5 s while another client pings ---"
$N sub '$SRV.>' > b-eaves.log 2>&1 & E=$!
sleep 0.5
$N service ping DEMO > /dev/null 2>&1
sleep 0.8
kill -9 $E 2>/dev/null
echo "--- what the eavesdropper saw ---"
grep -E '^\[#|Received' b-eaves.log | head -20
echo "--- can an ordinary client publish an endpoint subject the service owns? ---"
$N pub 'DEMO.echo' 'not a request'; echo "pub exit=$?"
sleep 0.3
echo "--- did the service handle it? ---"
tail -2 b-demo.log
kill -9 $B1 $S1 2>/dev/null; sleep 0.4

echo
echo "=== B2 · subject permissions around \$SRV ==="
nats-server -c perms.conf -l "$D/b2-server.log" >/dev/null 2>&1 & S2=$!
sleep 0.7
SVC="nats --server nats://svc:svc@127.0.0.1:14222 --timeout=2s"
CALLER="nats --server nats://caller:caller@127.0.0.1:14222 --timeout=2s"
OPS="nats --server nats://ops:ops@127.0.0.1:14222 --timeout=2s"
$SVC service serve orders > b2-demo.log 2>&1 & B2=$!
sleep 0.8
echo "--- caller (publish: orders.>, _INBOX.>) requests the endpoint ---"
$CALLER request orders.echo 'hi' 2>&1 | head -5
echo "--- caller asks \$SRV.PING (not in its allow list) ---"
$CALLER request '$SRV.PING' '' 2>&1 | head -5
echo "--- ops (publish: \$SRV.>) asks \$SRV.PING ---"
$OPS request '$SRV.PING' '' --replies=0 2>&1 | head -8
echo "--- ops calls the endpoint (not in its allow list) ---"
$OPS request orders.echo 'hi' 2>&1 | head -5
echo "--- server log: the violations ---"
grep -i 'violation' b2-server.log | tail -6
kill -9 $B2 $S2 2>/dev/null
echo "=== B done ==="
