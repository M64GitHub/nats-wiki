#!/bin/bash
# Run A2 — the per-stream floor with nothing else in the way (empty streams only), the same at
# 10,000 streams, the restart at that count, and a SIGKILL *after* writes.
# nats-server v2.14.6, nats CLI 0.4.0, one standalone server (tools/lab/cluster.sh up 1).
set -u
D=$(cd "$(dirname "$0")" && pwd)
REPO=/Users/m64/space/64/nats-wiki
cd "$D"
N="nats --server nats://127.0.0.1:4291 --timeout=120s"
SYS="nats --server nats://sys:sys@127.0.0.1:4291 --timeout=120s"
HP=8291
LAB="${TMPDIR:-/tmp}"; LAB="${LAB%/}/nats-lab"
STORE="$LAB/n1/store"
lab() { bash "$REPO/tools/lab/cluster.sh" "$@"; }
snap() { python3 "$D/snap.py" "$HP" "$1" "$STORE"; }
tl()  { python3 - "$@" <<'PY'
import sys, time
print(f"### [{time.strftime('%H:%M:%S')}] " + " ".join(sys.argv[1:]))
PY
}
restart() { python3 - "$1" <<'PY'
import subprocess, sys, time, urllib.request
label = sys.argv[1]
t0 = time.monotonic()
subprocess.run(["bash", "/Users/m64/space/64/nats-wiki/tools/lab/cluster.sh", "start", "1"],
               capture_output=True, text=True)
code = 0
while time.monotonic() - t0 < 900:
    try:
        with urllib.request.urlopen("http://127.0.0.1:8291/healthz", timeout=5) as r:
            code = r.status
        if code == 200: break
    except Exception:
        pass
    time.sleep(0.02)
print(f"{label}: start -> /healthz 200 in {time.monotonic()-t0:.3f}s (code {code})")
PY
}

tl "versions"; nats-server --version; nats --version

tl "fresh lab: down --purge, up 1"
lab down --purge >/dev/null 2>&1
NATS_LAB_WAIT=300 lab up 1

tl "B0 · baseline"
snap "B0 baseline, no stream"

tl "B1 · 1000 empty file streams, nothing published"
python3 topolab.py mkstreams 4291 1000 E 1 file
snap "B1 1000 empty file streams"

tl "B2 · 10,000 empty file streams"
python3 topolab.py mkstreams 4291 10000 E 1 file
snap "B2 10,000 empty file streams"
echo "--- ha_assets and the account view ---"
curl -s "http://127.0.0.1:$HP/jsz" | python3 -c 'import json,sys;d=json.load(sys.stdin);print({k:d[k] for k in ("streams","consumers","ha_assets","memory","storage","accounts")})'
echo "--- STREAM.NAMES paging at 10,000 ---"
python3 topolab.py apitime 4291 '$JS.API.STREAM.NAMES' '{"offset":0}' 2>&1 | head -3
python3 - <<'PY'
import subprocess, time
t0=time.monotonic()
r=subprocess.run(["nats","--server","nats://127.0.0.1:4291","--timeout=120s","stream","ls","-n"],capture_output=True,text=True)
print(f"nats stream ls -n: {time.monotonic()-t0:.2f}s, {len(r.stdout.splitlines())} lines")
PY
echo "--- nats server report jetstream ---"
$SYS server report jetstream 2>&1 | sed -n '1,8p'

tl "B3 · restart with 10,000 empty streams"
lab stop 1
restart "B3 clean stop, 10,000 empty streams"
snap "B3 after restart"
grep "Took .* to start JetStream" "$LAB/n1/n1.log" | tail -2
grep -c "Restored" "$LAB/n1/n1.log"

tl "B4 · one message into each of the 10,000 streams, then a clean restart"
python3 topolab.py fill 4291 'e.%05d.evt' 10000 128 10000
snap "B4 10,000 streams x 1 msg"
lab stop 1
restart "B4 clean stop, 10,000 streams with one message each"
snap "B4 after restart"

tl "B5 · write, then SIGKILL, then start (the dirty case at 10,000 streams)"
python3 topolab.py fill 4291 'e.%05d.evt' 10000 128 10000
lab stop 1 -9
restart "B5 SIGKILL after writes, 10,000 streams"
snap "B5 after the SIGKILL restart"
echo "--- rebuild / outdated lines in the log ---"
grep -c "will rebuild\|Stream state outdated" "$LAB/n1/n1.log"
grep "will rebuild\|Stream state outdated" "$LAB/n1/n1.log" | tail -3 | sed "s|$LAB|<lab>|"
grep "Took .* to start JetStream" "$LAB/n1/n1.log" | tail -1

tl "B6 · deleting 10,000 streams"
python3 topolab.py rmstreams 4291 10000 E
snap "B6 after deleting them"

tl "done"
