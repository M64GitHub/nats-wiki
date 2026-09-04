#!/bin/bash
# Run A-R3 — the same stream-count question with replicas: what a replicated stream costs the meta
# layer. Three nodes (tools/lab/cluster.sh up 3), nats-server v2.14.6, nats CLI 0.4.0.
set -u
D=$(cd "$(dirname "$0")" && pwd)
REPO=/Users/m64/space/64/nats-wiki
cd "$D"
N="nats --server nats://127.0.0.1:4291 --timeout=300s"
SYS="nats --server nats://sys:sys@127.0.0.1:4291 --timeout=300s"
LAB="${TMPDIR:-/tmp}"; LAB="${LAB%/}/nats-lab"
lab() { bash "$REPO/tools/lab/cluster.sh" "$@"; }
tl()  { python3 - "$@" <<'PY'
import sys, time
print(f"### [{time.strftime('%H:%M:%S')}] " + " ".join(sys.argv[1:]))
PY
}
snap3() { python3 - "$1" <<'PY'
import sys, json, os, subprocess, urllib.request
label = sys.argv[1]
lab = os.path.join(os.environ.get("TMPDIR", "/tmp").rstrip("/"), "nats-lab")
print(f"[{label}]")
for k in (1, 2, 3):
    try:
        with urllib.request.urlopen(f"http://127.0.0.1:829{k}/varz", timeout=20) as r:
            v = json.load(r)
        with urllib.request.urlopen(f"http://127.0.0.1:829{k}/jsz", timeout=20) as r:
            j = json.load(r)
    except Exception as e:
        print(f"  n{k}: unreachable ({e})"); continue
    pid = int(open(f"{lab}/n{k}/n{k}.pid").read().strip())
    rss = subprocess.run(["ps", "-o", "rss=", "-p", str(pid)], capture_output=True, text=True).stdout.strip()
    meta = f"{lab}/n{k}/store/jetstream/$SYS/_js_/_meta_"
    du_meta = subprocess.run(["du", "-sk", meta], capture_output=True, text=True).stdout.split()
    du_all = subprocess.run(["du", "-sk", f"{lab}/n{k}/store"], capture_output=True, text=True).stdout.split()
    print(f"  n{k}: rss {int(rss)/1024:.1f} MiB  varz mem {v['mem']/1048576:.1f} MiB  "
          f"streams {j.get('streams')} consumers {j.get('consumers')} ha_assets {j.get('ha_assets')}  "
          f"leader {(j.get('meta_cluster') or {}).get('leader')}  "
          f"store {int(du_all[0]) if du_all else -1} KiB  _meta_ {int(du_meta[0]) if du_meta else -1} KiB")
PY
}

tl "versions"; nats-server --version; nats --version

tl "fresh lab: down --purge, up 3"
lab down --purge >/dev/null 2>&1
NATS_LAB_WAIT=300 lab up 3
snap3 "R0 baseline, three nodes, no stream"
echo "--- the _meta_ directory before any stream ---"
find "$LAB/n1/store/jetstream/\$SYS" -type f | sed "s|$LAB|<lab>|" | head
du -sk "$LAB/n1/store/jetstream/\$SYS/_js_/_meta_"

tl "R1 · 10 R3 streams"
python3 topolab.py mkstreams 4291 10 R 3 file
snap3 "R1 10 R3 streams"

tl "R2 · 100 R3 streams"
python3 topolab.py mkstreams 4291 100 R 3 file
snap3 "R2 100 R3 streams"
echo "--- nats server report jetstream ---"
$SYS server report jetstream 2>&1 | head -14
echo "--- the meta log on n1 ---"
ls -l "$LAB/n1/store/jetstream/\$SYS/_js_/_meta_/msgs/" 2>/dev/null | tail -5 | sed "s|$LAB|<lab>|"
echo "--- one stream's raft directory on n1 ---"
find "$LAB/n1/store/jetstream/\$G/streams/R00001" -type f -exec ls -l {} \; 2>/dev/null | awk '{print $5, $9}' | sed "s|$LAB|<lab>|"

tl "R3 · publish rate into one R3 stream with 100 R3 streams present"
python3 topolab.py pubrate 4291 r.00001.evt 20000 128
python3 topolab.py pubrate 4291 r.00001.evt 20000 128
snap3 "R3 after 40,000 R3 messages"

tl "R4 · 300 R3 streams"
python3 topolab.py mkstreams 4291 300 R 3 file
snap3 "R4 300 R3 streams"
python3 topolab.py pubrate 4291 r.00001.evt 20000 128

tl "R5 · 1000 R3 streams — where the meta layer starts to hurt"
python3 topolab.py mkstreams 4291 1000 R 3 file
snap3 "R5 1000 R3 streams"
python3 topolab.py pubrate 4291 r.00001.evt 20000 128
echo "--- how long does STREAM.INFO on one of them take now ---"
python3 topolab.py streaminfo 4291 R00001
echo "--- and the meta leader's raft state ---"
curl -s "http://127.0.0.1:8291/raftz?acc=\$SYS" 2>/dev/null | python3 -c 'import json,sys;d=json.load(sys.stdin);print(list(d)[:3])' 2>/dev/null || echo "(raftz shape not read)"

tl "R6 · restart one node with 1000 R3 streams: stop 3, start 3, time to healthy and to caught up"
lab stop 3
python3 - <<'PY'
import subprocess, time, urllib.request, json
t0 = time.monotonic()
subprocess.run(["bash", "/Users/m64/space/64/nats-wiki/tools/lab/cluster.sh", "start", "3"],
               capture_output=True, text=True)
healthy = None
while time.monotonic() - t0 < 900:
    try:
        with urllib.request.urlopen("http://127.0.0.1:8293/healthz", timeout=5) as r:
            if r.status == 200:
                healthy = time.monotonic() - t0; break
    except Exception:
        pass
    time.sleep(0.05)
print(f"n3 /healthz 200 in {healthy if healthy is None else round(healthy,3)}s")
# and /healthz?js-enabled-only=false full check
t1 = time.monotonic()
while time.monotonic() - t1 < 900:
    try:
        with urllib.request.urlopen("http://127.0.0.1:8293/jsz", timeout=5) as r:
            j = json.load(r)
        if j.get("streams") == 1000:
            print(f"n3 reports 1000 streams {time.monotonic()-t1:.3f}s after healthy"); break
    except Exception:
        pass
    time.sleep(0.1)
PY
snap3 "R6 after n3 rejoined"
echo "--- n3's log, the JetStream start line ---"
grep "Took .* to start JetStream" "$LAB/n3/n3.log" | tail -2
echo "--- how many 'Restored' lines n3 printed on this boot ---"
grep -c "Restored" "$LAB/n3/n3.log"

tl "R7 · what 1000 R3 streams cost against 1000 R1 streams (the same lab, R1 for comparison)"
python3 topolab.py mkstreams 4291 1000 Q 1 file
snap3 "R7 + 1000 R1 streams alongside"

tl "done"
