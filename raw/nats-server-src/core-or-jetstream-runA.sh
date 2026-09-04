#!/bin/bash
set -m   # job control: background jobs take SIGINT
# Run A — the same subject, published two ways: what the wire carries and what the
# publisher learns. nats-server v2.14.6, nats CLI 0.4.0.
set -u
D=$(cd "$(dirname "$0")" && pwd); cd "$D"
N="nats --server nats://127.0.0.1:14222 --timeout=2s"
pkill -f 'nats-server -c' 2>/dev/null; sleep 0.5; rm -rf store; mkdir -p store
nats-server -c server.conf -l "$D/a-server.log" >/dev/null 2>&1 & SRV=$!
sleep 0.8

echo "=== A0 · the stream ORDERS on orders.> ==="
$N stream add ORDERS --subjects 'orders.>' --storage file --retention limits \
   --replicas 1 --defaults 2>&1 | tail -20

echo
echo "=== A1 · a raw tap on orders.> while one core and one JetStream publish go by ==="
( python3 coj-raw.py --port 14222 --send 'SUB orders.> 1' --wait 4.0 > a1-tap.txt 2>&1 ) & TAP=$!
sleep 0.6
echo "--- core: nats pub orders.created 'core' ---"
$N pub orders.created 'core'
echo "--- jetstream: nats pub orders.created 'jets' -J ---"
$N pub orders.created 'jets' -J
wait $TAP
echo "--- what the tap saw ---"
cat a1-tap.txt

echo
echo "=== A2 · the stream holds both, indistinguishably ==="
$N stream info ORDERS 2>&1 | sed -n '1,40p'
echo "--- the two stored messages ---"
$N stream get ORDERS 1 2>&1 | head -12
$N stream get ORDERS 2 2>&1 | head -12

echo
echo "=== A3 · nats pub -J prints the ack; nats pub prints nothing ==="
echo "--- core, exit code and output ---"
$N pub orders.created 'core-2' ; echo "exit=$?"
echo "--- jetstream, exit code and output ---"
$N pub orders.created 'jets-2' -J ; echo "exit=$?"

echo
echo "=== A4 · headers the server added to the stored JetStream message vs the core one ==="
$N stream get ORDERS 3 --json 2>&1 | head -6
$N stream get ORDERS 4 --json 2>&1 | head -6

kill $SRV 2>/dev/null; wait $SRV 2>/dev/null
echo "=== done ==="
