#!/bin/bash
set -m
# Run B (third pass) — the cost of the JetStream round trip against a core publish,
# same server, same payload. nats-server v2.14.6, nats CLI 0.4.0.
set -u
D=$(cd "$(dirname "$0")" && pwd); cd "$D"
N="nats --server nats://127.0.0.1:14222 --timeout=10s"
pkill -f 'nats-server -c' 2>/dev/null; sleep 0.5; rm -rf store; mkdir -p store
nats-server -c server.conf -l "$D/b3-server.log" >/dev/null 2>&1 & SRV=$!
sleep 0.8
$N stream add BENCH   --subjects 'bench.>' --storage file   --retention limits --replicas 1 --defaults >/dev/null 2>&1
$N stream add MEMBENCH --subjects 'mem.>'  --storage memory --retention limits --replicas 1 --defaults >/dev/null 2>&1

echo "=== B4 · 200000 core publishes, 1 client, 128 B (no stream on bench.core) ==="
$N bench pub bench.core --msgs 200000 --size 128B --clients 1 --no-progress 2>&1 | grep "msgs/sec"

echo
echo "=== B5 · 200000 JetStream publishes, SYNC — one round trip each, file stream ==="
$N bench js pub sync bench.js --stream BENCH --msgs 200000 --size 128B --clients 1 --no-progress 2>&1 | grep "msgs/sec"

echo
echo "=== B6 · 200000 JetStream publishes, ASYNC — file stream ==="
$N bench js pub async bench.js --stream BENCH --msgs 200000 --size 128B --clients 1 --no-progress 2>&1 | grep "msgs/sec"

echo
echo "=== B7 · 200000 JetStream publishes, ASYNC — memory stream ==="
$N bench js pub async mem.js --stream MEMBENCH --msgs 200000 --size 128B --clients 1 --no-progress 2>&1 | grep "msgs/sec"

echo
echo "=== B8 · and a core publish into a subject a stream DOES capture (the mixed case) ==="
$N bench pub bench.captured --msgs 200000 --size 128B --clients 1 --no-progress 2>&1 | grep "msgs/sec"
sleep 1
$N stream info BENCH 2>&1 | grep -E "Messages:|Bytes:"

kill $SRV 2>/dev/null; wait $SRV 2>/dev/null
echo "=== done ==="
