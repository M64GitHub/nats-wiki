#!/bin/bash
set -m
# Run G — ADR-22's motivation on an R3 cluster: what a JetStream publisher sees when the
# stream leader steps down, and what a core publisher sees at the same instant.
# nats-server v2.14.6, nats CLI 0.4.0, the lab (tools/lab/cluster.sh up 3).
set -u
D=$(cd "$(dirname "$0")" && pwd); cd "$D"
W=/Users/m64/space/64/nats-wiki
N="nats --server nats://127.0.0.1:4291 --timeout=5s"
NS="nats --server nats://sys:sys@127.0.0.1:4291 --timeout=5s"
bash "$W/tools/lab/cluster.sh" down >/dev/null 2>&1
bash "$W/tools/lab/cluster.sh" up 3 2>&1 | tail -4

echo
echo "=== G1 · an R3 file stream on orders.> ==="
$N stream add ORDERS --subjects 'orders.>' --storage file --retention limits --replicas 3 --defaults >/dev/null 2>&1
$N stream info ORDERS 2>&1 | grep -E "Leader|Replica|Cluster" | head -6

echo
echo "=== G2 · a JetStream publisher every 20 ms while the leader steps down ==="
python3 - <<'PY' > g2-js.txt 2>&1 &
import subprocess, time, sys
t0 = time.time()
n_ok = n_err = 0
while time.time() - t0 < 12.0:
    t = time.time()
    p = subprocess.run(["nats", "--server", "nats://127.0.0.1:4291", "--timeout=5s",
                        "pub", "orders.created", "x", "-J"],
                       capture_output=True, text=True)
    dt = time.time() - t
    out = (p.stdout + p.stderr).strip().replace("\n", " | ")
    if "error" in out or p.returncode != 0:
        n_err += 1
        print(f"t+{time.time()-t0:6.3f}s  {dt*1000:8.1f}ms  ERR  {out[-140:]}")
    else:
        n_ok += 1
    time.sleep(0.02)
print(f"-- js publishes: ok={n_ok} err={n_err}")
PY
JSPUB=$!
python3 - <<'PY' > g2-core.txt 2>&1 &
import subprocess, time
t0 = time.time()
n_ok = n_err = 0
while time.time() - t0 < 12.0:
    p = subprocess.run(["nats", "--server", "nats://127.0.0.1:4291", "--timeout=5s",
                        "pub", "orders.core", "x"], capture_output=True, text=True)
    out = (p.stdout + p.stderr).strip()
    if p.returncode != 0 or "error" in out:
        n_err += 1; print(f"t+{time.time()-t0:6.3f}s  CORE ERR  {out[-140:]}")
    else:
        n_ok += 1
    time.sleep(0.02)
print(f"-- core publishes: ok={n_ok} err={n_err}")
PY
COREPUB=$!
sleep 4
echo "--- step down the stream leader at t≈4s ---"
$N stream cluster step-down ORDERS 2>&1 | tail -2
sleep 3
echo "--- step down the meta leader at t≈7s ---"
$NS server report jetstream 2>&1 | grep -iE "leader" | head -2
$NS server raft step-down 2>&1 | tail -2
wait $JSPUB $COREPUB
echo
echo "--- JetStream publisher ---"; cat g2-js.txt
echo "--- core publisher ---"; cat g2-core.txt

echo
echo "=== G3 · the stream after it all ==="
$N stream info ORDERS 2>&1 | grep -E "Leader|Messages:|Replica" | head -6

bash "$W/tools/lab/cluster.sh" down >/dev/null 2>&1
echo "=== done ==="
