#!/bin/bash
# runG.sh — the gateway verbs on the wire: the INFO exchange, A+/A-, RS+/RS-, RMSG and the
# mapped reply prefix. nats-server v2.14.6.
set -u
D=$(cd "$(dirname "$0")" && pwd); cd "$D"
nats-server -c gwA.conf -DV >g-a.log 2>&1 & S1=$!
nats-server -c gwB.conf -DV >g-b.log 2>&1 & S2=$!
sleep 2.0
nats sub -s nats://127.0.0.1:14223 'x.data' --count 1 >g-sub.log 2>&1 & A=$!
sleep 0.8
nats pub -s nats://127.0.0.1:14222 'x.data' 'across the gateway' >/dev/null 2>&1
sleep 0.6
nats reply -s nats://127.0.0.1:14223 'x.svc' 'answered' >g-reply.log 2>&1 & B=$!
sleep 0.8
nats request -s nats://127.0.0.1:14222 'x.svc' 'ask' --timeout 2s >g-req.log 2>&1
sleep 0.6
nats pub -s nats://127.0.0.1:14222 'nobody.listens' 'dropped' >/dev/null 2>&1
sleep 0.6
kill $A $B 2>/dev/null; wait $A $B 2>/dev/null
kill $S1 $S2 2>/dev/null; wait 2>/dev/null

echo "--- cluster CA: every gateway protocol line ---"
grep -E "gid:[0-9]+" g-a.log | sed -E 's/^\[[0-9]+\] //' | grep -E "\[(INFO|CONNECT|A\+|A-|RS\+|RS-|RMSG|HMSG|PING|PONG)" | head -40
echo; echo "--- cluster CB: every gateway protocol line ---"
grep -E "gid:[0-9]+" g-b.log | sed -E 's/^\[[0-9]+\] //' | grep -E "\[(INFO|CONNECT|A\+|A-|RS\+|RS-|RMSG|HMSG)" | head -40
echo; echo "--- the request across the gateway, CA side ---"
grep -E "x.svc|_GR_|\\\$GR\.|_INBOX" g-a.log | sed -E 's/^\[[0-9]+\] //' | head -20
echo; echo "--- the reply as CB sees it ---"
grep -E "x.svc|_GR_|\\\$GR\.|_INBOX" g-b.log | sed -E 's/^\[[0-9]+\] //' | head -20
echo; echo "--- reply files ---"; cat g-req.log g-sub.log 2>/dev/null | head -12
