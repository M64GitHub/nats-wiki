#!/bin/bash
# runE.sh — what the verbs look like on the wire, from the server's own -DV trace.
# nats-server v2.14.6.
set -u
D=$(cd "$(dirname "$0")" && pwd); cd "$D"

echo "### E1 · a client CONNECT on a leafnode port with no auth configured"
nats-server -c noauth.conf >e-noauth.log 2>&1 & S=$!; sleep 0.7
python3 wire-raw.py --port 17422 --wait 1.0 --send 'CONNECT {"lang":"python","version":"0","verbose":false}' --send 'PING' --label ""
echo; echo "### E1b · a leaf-shaped CONNECT (no lang) on the same port"
python3 wire-raw.py --port 17422 --wait 1.0 --send 'CONNECT {"name":"fake","cluster":"NA1"}' --send 'PING' --label ""
kill $S 2>/dev/null; wait $S 2>/dev/null

echo; echo "### E2 · route verbs: two clustered servers, -DV on HUB1, one sub and one publish"
nats-server -c hub.conf -DV >e-hub1.log 2>&1 & S1=$!
nats-server -c hub2.conf >e-hub2.log 2>&1 & S2=$!
sleep 1.8
nats sub -s nats://127.0.0.1:14222 'orders.new' --count 1 >e-sub.log 2>&1 & SUB=$!
sleep 0.8
nats pub -s nats://127.0.0.1:14223 'orders.new' 'Hello World' >/dev/null 2>&1
sleep 0.5
nats sub -s nats://127.0.0.1:14222 'work.>' --queue WORKERS --count 1 >e-qsub.log 2>&1 & QSUB=$!
sleep 0.8
nats pub -s nats://127.0.0.1:14223 'work.a' 'queued' >/dev/null 2>&1
sleep 0.8
wait $SUB 2>/dev/null; wait $QSUB 2>/dev/null
sleep 0.5

echo; echo "### E3 · leafnode verbs: a leaf solicits HUB1, -DV on HUB1"
nats-server -c leaf.conf >e-leaf.log 2>&1 & S3=$!
sleep 1.5
nats sub -s nats://127.0.0.1:14224 'edge.ping' --count 1 >e-leafsub.log 2>&1 & LSUB=$!
sleep 0.8
nats pub -s nats://127.0.0.1:14222 'edge.ping' 'from the hub' >/dev/null 2>&1
sleep 0.5
nats pub -s nats://127.0.0.1:14222 'edge.ping' --header 'Bar:Baz' 'with a header' >/dev/null 2>&1
sleep 0.8
wait $LSUB 2>/dev/null
kill $S1 $S2 $S3 2>/dev/null; wait 2>/dev/null

echo; echo "--- HUB1 trace: every route/leaf protocol line ---"
grep -E "\[TRC\].*(RS\+|RS-|RMSG|LS\+|LS-|LMSG|HMSG|A\+|A-|CONNECT|INFO|PING|PONG)" e-hub1.log | sed -E 's/^\[[0-9]+\] //' | head -80
