#!/bin/bash
# runA.sh — the INFO line every listener offers, at nats-server v2.14.6.
set -u
D=$(cd "$(dirname "$0")" && pwd); cd "$D"
rm -rf /tmp/wp-store /tmp/wp-store2
nats-server --version

echo; echo "=== A1 · a standalone server, client port 14222 ==="
nats-server -c base.conf >a1-server.log 2>&1 &
S1=$!; sleep 0.7
python3 wire-raw.py --port 14222 --wait 0.5 --label "A1 client port, standalone"
kill $S1 2>/dev/null; wait $S1 2>/dev/null

echo; echo "=== A2..A6 · a clustered node with leafnode + gateway + JetStream ==="
nats-server -c full.conf >a2-server.log 2>&1 &
S2=$!; sleep 0.9
nats-server -c peer.conf >a2-peer.log 2>&1 &
S3=$!; sleep 1.5

python3 wire-raw.py --port 14222 --wait 0.5 --label "A2 client port, clustered (connect_urls, cluster)"
python3 wire-raw.py --port 17422 --wait 0.5 --label "A3 leafnode listener 17422"
python3 wire-raw.py --port 16222 --wait 0.5 --label "A4 route listener 16222"
python3 wire-raw.py --port 17222 --wait 0.5 --label "A5 gateway listener 17222"

echo; echo "=== A6 · the same client port after lame duck ==="
( python3 wire-raw.py --port 14222 --wait 8 --pong --send 'CONNECT {"protocol":1,"verbose":false}' --send 'PING' --label "A6 client port, watching for the LDM INFO" >a6-tap.log 2>&1 ) &
T=$!
sleep 1.2
nats-server --signal ldm=$S2 2>&1 | sed 's/^/    signal: /'
wait $T
cat a6-tap.log

kill $S2 $S3 2>/dev/null; wait 2>/dev/null
echo; echo "=== server log of A2 (first 20 lines) ==="; head -20 a2-server.log
