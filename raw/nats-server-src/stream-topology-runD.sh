#!/bin/bash
# Run D — what a tenant sees at its account limits: max_streams, max_consumers, max_file, and the
# per-stream max_consumers. The exact error code and message on each. nats-server v2.14.6, nats 0.4.0.
set -u
D=$(cd "$(dirname "$0")" && pwd); cd "$D"
T="nats --server nats://t:t@127.0.0.1:4321 --timeout=20s"
F="nats --server nats://f:f@127.0.0.1:4321 --timeout=20s"
SY="nats --server nats://sys:sys@127.0.0.1:4321 --timeout=20s"
tl() { python3 - "$@" <<'PY'
import sys, time
print(f"### [{time.strftime('%H:%M:%S')}] " + " ".join(sys.argv[1:]))
PY
}

tl "versions"; nats-server --version; nats --version

pkill -f 'nats-server -c limits.conf' 2>/dev/null
rm -rf storeD; mkdir -p storeD
nats-server -c limits.conf -l "$D/d-server.log" -P "$D/d.pid" >/dev/null 2>&1 &
python3 - <<'PY'
import time, urllib.request
t0=time.monotonic()
while time.monotonic()-t0 < 30:
    try:
        with urllib.request.urlopen("http://127.0.0.1:8321/healthz", timeout=2) as r:
            if r.status == 200: print(f"server healthy in {time.monotonic()-t0:.2f}s"); break
    except Exception: pass
    time.sleep(0.05)
PY

tl "D0 · what the tenant sees before it has anything"
$T account info 2>&1 | sed -n '1,40p'

tl "D1 · max_streams: 3 allowed, the 4th refused"
for i in 1 2 3 4; do
  echo "--- stream S$i ---"
  $T stream add "S$i" --subjects "s$i.>" --storage file --retention limits --replicas 1 --defaults 2>&1 | tail -3
done
echo "--- the raw API error for the 4th ---"
NLAB_USER=t NLAB_PASS=t python3 topolab.py apitime 4321 '$JS.API.STREAM.CREATE.S4' '{"name":"S4","subjects":["s4.>"],"storage":"file","retention":"limits","num_replicas":1}'

tl "D2 · max_consumers: 2 allowed on the account, the 3rd refused"
for i in 1 2 3; do
  echo "--- consumer C$i on S1 ---"
  $T consumer add S1 "C$i" --pull --filter "s1.$i" --ack explicit --deliver all --defaults 2>&1 | tail -3
done
echo "--- the raw API error for the 3rd ---"
NLAB_USER=t NLAB_PASS=t python3 topolab.py apitime 4321 '$JS.API.CONSUMER.DURABLE.CREATE.S1.C3' '{"stream_name":"S1","config":{"durable_name":"C3","ack_policy":"explicit","deliver_policy":"all"}}'

tl "D3 · the per-STREAM max_consumers (a different limit, a different code)"
$F stream add PS --subjects 'ps.>' --storage file --retention limits --replicas 1 --max-consumers 1 --defaults 2>&1 | tail -3
$F consumer add PS A --pull --ack explicit --deliver all --defaults 2>&1 | tail -2
$F consumer add PS B --pull --ack explicit --deliver all --defaults 2>&1 | tail -3
echo "--- the raw API error ---"
NLAB_USER=f NLAB_PASS=f python3 topolab.py apitime 4321 '$JS.API.CONSUMER.DURABLE.CREATE.PS.B' '{"stream_name":"PS","config":{"durable_name":"B","ack_policy":"explicit","deliver_policy":"all"}}'

tl "D4 · max_file: fill S1 past 64 MB"
python3 - <<'PY'
import subprocess, time
t0 = time.monotonic()
r = subprocess.run(["nats","--server","nats://t:t@127.0.0.1:4321","--timeout=300s","bench","js","pub","sync",
                    "s1.bulk","--stream","S1","--msgs","600000","--size","128B","--clients","1","--no-progress"],
                   capture_output=True, text=True)
print("stdout tail:"); print("\n".join(r.stdout.splitlines()[-6:]))
print("stderr tail:"); print("\n".join(r.stderr.splitlines()[-6:]))
print(f"({time.monotonic()-t0:.1f}s)")
PY
echo "--- the raw API error on a publish past the account's max_file ---"
NLAB_USER=t NLAB_PASS=t python3 topolab.py apitime 4321 's1.overflow' 'x'
$T stream info S1 2>&1 | grep -iE "messages|bytes" | head -4
$T account info 2>&1 | sed -n '1,40p'

tl "D5 · what the system account sees"
$SY server report jetstream 2>&1 | head -12
curl -s "http://127.0.0.1:8321/jsz?accounts=1" | python3 -m json.tool | sed -n '1,60p'

tl "D6 · reserved storage: what the tenant's limit costs before a byte is written"
curl -s "http://127.0.0.1:8321/jsz" | python3 -c 'import json,sys;d=json.load(sys.stdin);print({k:d.get(k) for k in ("memory","storage","reserved_memory","reserved_storage","accounts","streams","consumers","ha_assets")})'

tl "done"
kill "$(cat "$D/d.pid")" 2>/dev/null
