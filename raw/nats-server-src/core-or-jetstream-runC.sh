#!/bin/bash
set -m
# Run C — the mixed design: does a core publisher into a captured subject lose messages,
# and what does a stream on '>' actually swallow? nats-server v2.14.6, nats CLI 0.4.0.
set -u
D=$(cd "$(dirname "$0")" && pwd); cd "$D"
N="nats --server nats://127.0.0.1:14222 --timeout=10s"
pkill -f 'nats-server -c' 2>/dev/null; sleep 0.5; rm -rf store; mkdir -p store
nats-server -c server.conf -l "$D/c-server.log" >/dev/null 2>&1 & SRV=$!
sleep 0.8

echo "=== C1 · 100000 core publishes into a subject a file stream captures ==="
$N stream add CAP --subjects 'cap.>' --storage file --retention limits --replicas 1 --defaults >/dev/null 2>&1
$N bench pub cap.x --msgs 100000 --size 128B --clients 1 --no-progress 2>&1 | grep "msgs/sec"
for i in 1 2 3 4 5; do sleep 1; echo -n "  t+${i}s stored: "; $N stream info CAP --json 2>/dev/null | python3 -c "import json,sys;print(json.load(sys.stdin)['state']['messages'])"; done
echo "  expected: 100000"
echo "  --- server log lines mentioning the stream or a drop ---"
grep -iE "slow|drop|error|warn" c-server.log | tail -5 || echo "  (none)"
curl -s http://127.0.0.1:18222/varz | python3 -c "import json,sys;d=json.load(sys.stdin);print('  varz: in_msgs',d['in_msgs'],'slow_consumers',d['slow_consumers'])"

echo
echo "=== C2 · the same, but the publisher flushes and waits before exiting (nats pub --count) ==="
$N stream add CAP2 --subjects 'cap2.>' --storage file --retention limits --replicas 1 --defaults >/dev/null 2>&1
$N pub cap2.x --count 5000 'm{{Count}}' >/dev/null 2>&1
sleep 2
echo -n "  stored (expected 5000): "; $N stream info CAP2 --json 2>/dev/null | python3 -c "import json,sys;print(json.load(sys.stdin)['state']['messages'])"

echo
echo "=== C3 · a stream on '>' — what does it swallow? ==="
$N stream add EVERYTHING --subjects '>' --storage memory --retention limits --replicas 1 --defaults >/dev/null 2>&1
echo "--- a request/reply exchange while EVERYTHING is capturing ---"
$N reply cap.svc 'pong' >/dev/null 2>&1 & R=$!
sleep 0.8
$N request cap.svc 'ping' 2>&1 | tail -3
sleep 0.5
kill $R 2>/dev/null
echo "--- and a services-framework instance ---"
$N service serve DEMO >/dev/null 2>&1 & S=$!
sleep 1.0
$N request DEMO.echo 'hi' >/dev/null 2>&1
sleep 0.5
kill $S 2>/dev/null
sleep 0.8
echo "--- the subjects EVERYTHING now holds ---"
$N stream subjects EVERYTHING 2>&1 | head -30
echo "--- message count ---"
$N stream info EVERYTHING --json 2>/dev/null | python3 -c "import json,sys;print(' messages:',json.load(sys.stdin)['state']['messages'])"

kill $SRV 2>/dev/null; wait $SRV 2>/dev/null
echo "=== done ==="
