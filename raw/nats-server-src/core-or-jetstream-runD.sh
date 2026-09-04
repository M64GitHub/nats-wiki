#!/bin/bash
set -m
# Run D — what happens when a stream is laid over a core request/reply subject, and
# what a stream on '>' swallows. nats-server v2.14.6, nats CLI 0.4.0.
set -u
D=$(cd "$(dirname "$0")" && pwd); cd "$D"
N="nats --server nats://127.0.0.1:14222 --timeout=3s"
pkill -f 'nats-server -c' 2>/dev/null; pkill -f 'nats.*reply' 2>/dev/null; sleep 0.5; rm -rf store; mkdir -p store
nats-server -c server.conf -l "$D/d-server.log" >/dev/null 2>&1 & SRV=$!
sleep 0.8

echo "=== D1 · a responder on svc.echo, no stream — the control ==="
$N reply svc.echo 'pong' >/dev/null 2>&1 & R=$!
sleep 0.8
echo "--- nats request svc.echo ping ---"
$N request svc.echo 'ping' 2>&1 | tail -4

echo
echo "=== D2 · now add a stream that captures svc.> and ask again ==="
$N stream add SVC --subjects 'svc.>' --storage file --retention limits --replicas 1 --defaults >/dev/null 2>&1
sleep 0.3
echo "--- nats request svc.echo ping (one reply) ---"
$N request svc.echo 'ping' 2>&1 | tail -4
echo "--- nats request svc.echo ping --replies=0 (gather everything until the deadline) ---"
$N request svc.echo 'ping' --replies=0 2>&1 | tail -8

echo
echo "=== D3 · the wire: how many MSG frames does the requester's inbox get? ==="
python3 coj-raw.py --port 14222 \
  --send 'SUB _INBOX.rawcoj.1 9' \
  --send 'PUB svc.echo _INBOX.rawcoj.1 4' --send 'ping' \
  --wait 2.0 2>&1 | tail -12
kill $R 2>/dev/null; sleep 0.3

echo
echo "=== D4 · what the stream stored ==="
$N stream subjects SVC 2>&1 | head -20

echo
echo "=== D5 · a stream on '>' on a clean account: is it even allowed? ==="
$N stream add EVERYTHING --subjects '>' --storage memory --retention limits --replicas 1 --defaults 2>&1 | tail -4
echo "--- and after deleting SVC? ---"
$N stream rm SVC -f >/dev/null 2>&1
$N stream add EVERYTHING --subjects '>' --storage memory --retention limits --replicas 1 --defaults 2>&1 | tail -3

echo
echo "=== D6 · with EVERYTHING in place, run a request/reply and a service, then look ==="
$N reply svc.echo 'pong' >/dev/null 2>&1 & R2=$!
sleep 0.8
$N request svc.echo 'ping' >/dev/null 2>&1
$N service serve DEMO >/dev/null 2>&1 & S=$!
sleep 1.2
$N request DEMO.echo 'hi' >/dev/null 2>&1
sleep 0.5
kill $R2 $S 2>/dev/null; sleep 0.5
echo "--- subjects EVERYTHING holds ---"
$N stream subjects EVERYTHING 2>&1 | head -40
echo "--- count ---"
$N stream info EVERYTHING 2>&1 | grep -E "Messages:|Bytes:" | head -3

kill $SRV 2>/dev/null; wait $SRV 2>/dev/null
echo "=== done ==="
