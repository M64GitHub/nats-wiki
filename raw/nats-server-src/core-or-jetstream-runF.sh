#!/bin/bash
set -m
# Run F — the mixed design: a stream added over an unchanged core publisher, and both
# readers at once. nats-server v2.14.6, nats CLI 0.4.0.
set -u
D=$(cd "$(dirname "$0")" && pwd); cd "$D"
N="nats --server nats://127.0.0.1:14222 --timeout=3s"
pkill -f 'nats-server -c' 2>/dev/null; sleep 0.5; rm -rf store; mkdir -p store
nats-server -c server.conf -l "$D/f-server.log" >/dev/null 2>&1 & SRV=$!
sleep 0.8

echo "=== F1 · core only: the subscriber is away for three publishes ==="
$N sub orders.created > f1-sub.txt 2>&1 & S1=$!
sleep 0.8
$N pub orders.created 'A' >/dev/null 2>&1
sleep 0.3
kill $S1 2>/dev/null; sleep 0.4          # the subscriber goes away
$N pub orders.created 'B' >/dev/null 2>&1
$N pub orders.created 'C' >/dev/null 2>&1
$N sub orders.created > f1-sub2.txt 2>&1 & S2=$!
sleep 0.8
$N pub orders.created 'D' >/dev/null 2>&1
sleep 0.4; kill $S2 2>/dev/null; sleep 0.3
echo "--- first subscriber saw ---"; grep -E "^[A-D]$" f1-sub.txt | tr '\n' ' '; echo
echo "--- second subscriber saw ---"; grep -E "^[A-D]$" f1-sub2.txt | tr '\n' ' '; echo
echo "  (B and C were published while nobody was listening)"

echo
echo "=== F2 · add the stream. The publisher command does not change. ==="
$N stream add ORDERS --subjects 'orders.>' --storage file --retention limits --replicas 1 --defaults >/dev/null 2>&1
$N pub orders.created 'E' >/dev/null 2>&1     # identical command to F1
$N pub orders.created 'F' >/dev/null 2>&1
sleep 0.5
echo "--- what the stream holds (nobody was subscribed) ---"
$N stream view ORDERS 10 2>&1 | grep -E "^\[|^[A-Z]$" | head -12

echo
echo "=== F3 · one live core subscriber and one JetStream consumer, same subject ==="
$N consumer add ORDERS AUDIT --pull --deliver all --ack explicit --defaults >/dev/null 2>&1
$N sub orders.created > f3-sub.txt 2>&1 & S3=$!
sleep 0.8
$N pub orders.created 'G' >/dev/null 2>&1
sleep 0.5; kill $S3 2>/dev/null; sleep 0.3
echo "--- the core subscriber saw ---"; grep -E "^[A-Z]$" f3-sub.txt | tr '\n' ' '; echo
echo "--- the consumer replays everything the stream captured ---"
$N consumer next ORDERS AUDIT --count 5 --ack 2>&1 | grep -E "^[A-Z]$" | tr '\n' ' '; echo

echo
echo "=== F4 · remove the stream; the core path is untouched ==="
$N stream rm ORDERS -f >/dev/null 2>&1
$N sub orders.created > f4-sub.txt 2>&1 & S4=$!
sleep 0.8
$N pub orders.created 'H' >/dev/null 2>&1
sleep 0.4; kill $S4 2>/dev/null; sleep 0.3
echo "--- the core subscriber saw ---"; grep -E "^[A-Z]$" f4-sub.txt | tr '\n' ' '; echo
echo "--- and a JetStream publish now? ---"
$N pub orders.created 'I' -J 2>&1 | tail -2

kill $SRV 2>/dev/null; wait $SRV 2>/dev/null
echo "=== done ==="
