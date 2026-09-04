#!/bin/bash
# runF.sh — the header and queue forms of LMSG/HMSG on a leafnode, and a request over a leaf.
# nats-server v2.14.6.
set -u
D=$(cd "$(dirname "$0")" && pwd); cd "$D"
nats-server -c hub.conf -DV >f-hub1.log 2>&1 & S1=$!
nats-server -c hub2.conf >f-hub2.log 2>&1 & S2=$!
sleep 1.6
nats-server -c leaf.conf >f-leaf.log 2>&1 & S3=$!
sleep 1.5

# a plain sub, a queue sub and a responder, all on the leaf, all alive at once
nats sub -s nats://127.0.0.1:14224 'edge.ping' --count 3 >f-sub.log 2>&1 & A=$!
nats sub -s nats://127.0.0.1:14224 'edge.work' --queue W --count 2 >f-qsub.log 2>&1 & B=$!
nats reply -s nats://127.0.0.1:14224 'edge.svc' 'pong' >f-reply.log 2>&1 & C=$!
sleep 1.2

nats pub -s nats://127.0.0.1:14222 'edge.ping' 'plain' >/dev/null 2>&1
nats pub -s nats://127.0.0.1:14222 'edge.ping' --header 'Bar:Baz' 'with header' >/dev/null 2>&1
nats pub -s nats://127.0.0.1:14222 'edge.work' 'queued' >/dev/null 2>&1
nats pub -s nats://127.0.0.1:14222 'edge.work' --header 'K:V' 'queued+header' >/dev/null 2>&1
nats request -s nats://127.0.0.1:14222 'edge.svc' 'ask' --timeout 2s >f-req.log 2>&1
nats pub -s nats://127.0.0.1:14222 'edge.ping' --reply 'answers.here' 'with reply' >/dev/null 2>&1
sleep 1.2
kill $A $B $C 2>/dev/null; wait $A $B $C 2>/dev/null
kill $S1 $S2 $S3 2>/dev/null; wait 2>/dev/null

echo "--- every LMSG / HMSG / LS+ / LS- on the leafnode connection ---"
grep -E "lid:[0-9]+ - (->>|<<-) \[(LMSG|HMSG|LS\+|LS-)" f-hub1.log | sed -E 's/^\[[0-9]+\] //'
echo
echo "--- the same, carried on the route ---"
grep -E "rid:[0-9]+ - (->>|<<-) \[(LMSG|HMSG|LS\+|LS-|RS\+|RS-|RMSG)" f-hub1.log | sed -E 's/^\[[0-9]+\] //' | grep -v '\$SYS\|\$JS\|\$LDS' 
echo
echo "--- the request/reply inbox on the wire ---"
grep -E "edge.svc|_INBOX" f-hub1.log | sed -E 's/^\[[0-9]+\] //' | head -20
