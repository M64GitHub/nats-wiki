#!/bin/bash
set -m
# Run E — the stream on '>' the server will accept, and what it swallows.
# nats-server v2.14.6, nats CLI 0.4.0.
set -u
D=$(cd "$(dirname "$0")" && pwd); cd "$D"
N="nats --server nats://127.0.0.1:14222 --timeout=3s"
pkill -f 'nats-server -c' 2>/dev/null; pkill -f 'nats .*reply' 2>/dev/null; sleep 0.5; rm -rf store; mkdir -p store
nats-server -c server.conf -l "$D/e-server.log" >/dev/null 2>&1 & SRV=$!
sleep 0.8

echo "=== E1 · the stream the server will accept on '>' ==="
$N stream add EVERYTHING --subjects '>' --storage memory --retention limits --replicas 1 \
   --no-ack --defaults 2>&1 | tail -3
$N stream info EVERYTHING 2>&1 | grep -E "Acknowledgments|Subjects:"

echo
echo "=== E2 · a core request/reply while EVERYTHING captures ==="
$N reply svc.echo 'pong' >/dev/null 2>&1 & R=$!
sleep 0.8
$N request svc.echo 'ping' 2>&1 | tail -3

echo
echo "=== E3 · a services-framework instance while EVERYTHING captures ==="
$N service serve DEMO >/dev/null 2>&1 & S=$!
sleep 1.2
$N request DEMO.echo 'hi' >/dev/null 2>&1
$N service ping DEMO >/dev/null 2>&1
sleep 0.6
kill $R $S 2>/dev/null; sleep 0.6

echo
echo "=== E4 · the subjects EVERYTHING now holds ==="
$N stream subjects EVERYTHING 2>&1 | head -40

echo
echo "=== E5 · does it hold the JetStream API itself? ==="
$N stream info EVERYTHING >/dev/null 2>&1
sleep 0.4
$N stream subjects EVERYTHING '$JS.>' 2>&1 | head -12
echo "--- and \$SRV / _INBOX ---"
$N stream subjects EVERYTHING '_INBOX.>' 2>&1 | head -8
$N stream subjects EVERYTHING '$SRV.>' 2>&1 | head -8

echo
echo "=== E6 · a JetStream publish into a no-ack stream ==="
S2=$(python3 -c 'import time;print(time.time())')
$N pub cap.x 'js-into-noack' -J 2>&1 | tail -3; echo "exit=$?"
python3 -c "import time;print('elapsed %.3fs' % (time.time()-$S2))"

echo
echo "=== E7 · total messages ==="
$N stream info EVERYTHING 2>&1 | grep -E "Messages:|Bytes:" | head -3

kill $SRV 2>/dev/null; wait $SRV 2>/dev/null
echo "=== done ==="
