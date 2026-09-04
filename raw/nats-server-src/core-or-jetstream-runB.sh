#!/bin/bash
set -m
# Run B — what the publisher learns when there is no stream, and what a JetStream
# publish costs when JetStream is not there. nats-server v2.14.6, nats CLI 0.4.0.
set -u
D=$(cd "$(dirname "$0")" && pwd); cd "$D"
N="nats --server nats://127.0.0.1:14222 --timeout=2s"
pkill -f 'nats-server -c' 2>/dev/null; sleep 0.5; rm -rf store; mkdir -p store
nats-server -c server.conf -l "$D/b-server.log" >/dev/null 2>&1 & SRV=$!
sleep 0.8
$N stream add ORDERS --subjects 'orders.>' --storage file --retention limits --replicas 1 --defaults >/dev/null 2>&1

echo "=== B1 · core publish to a subject nobody captures and nobody hears ==="
/usr/bin/time -p $N pub nostream.x 'lost' 2>&1
echo "exit=$?"
echo "--- did anything happen? /varz in_msgs before/after is the only trace ---"
curl -s http://127.0.0.1:18222/varz | python3 -c "import json,sys; d=json.load(sys.stdin); print('in_msgs',d['in_msgs'],'out_msgs',d['out_msgs'],'slow_consumers',d['slow_consumers'])"

echo
echo "=== B2 · JetStream publish to a subject no stream captures ==="
S=$(python3 -c 'import time;print(time.time())')
$N pub nostream.x 'lost' -J 2>&1; echo "exit=$?"
python3 -c "import time;print('elapsed %.3fs' % (time.time()-$S))"

echo
echo "=== B3 · JetStream publish to a captured subject, timed against a core publish ==="
for k in 1 2 3; do
python3 - <<'PY'
import subprocess, time
for mode, args in (("core", []), ("jetstream", ["-J"])):
    t = time.time()
    subprocess.run(["nats", "--server", "nats://127.0.0.1:14222", "--timeout=2s",
                    "pub", "orders.created", "x"] + args,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    print(f"  {mode:9s} one nats pub process: {time.time()-t:.3f}s")
PY
done
echo "(process startup dominates; the ratio, not the number, is the point — see B4)"

echo
echo "=== B4 · 10000 publishes each way, same subject, same server (nats bench) ==="
$N bench pub orders.bench --msgs 10000 --size 128 --clients 1 --no-progress 2>&1 | tail -8
echo "---"
$N bench js pub --stream ORDERS --subject orders.bench --msgs 10000 --size 128 --clients 1 --no-progress 2>&1 | tail -12

echo
echo "=== B5 · the same 10000 JetStream publishes, but asynchronous ==="
$N bench js pub --stream ORDERS --subject orders.bench --msgs 10000 --size 128 --clients 1 --batch 100 --no-progress 2>&1 | tail -12

kill $SRV 2>/dev/null; wait $SRV 2>/dev/null
echo "=== done ==="
