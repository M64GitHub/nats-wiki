#!/bin/bash
# Run A/B — the cost of a stream, and of a thousand of them, against one stream with a tenant
# prefix. nats-server v2.14.6, nats CLI 0.4.0, one standalone server (tools/lab/cluster.sh up 1).
set -u
D=$(cd "$(dirname "$0")" && pwd)
REPO=/Users/m64/space/64/nats-wiki
cd "$D"
N="nats --server nats://127.0.0.1:4291 --timeout=60s"
SYS="nats --server nats://sys:sys@127.0.0.1:4291 --timeout=60s"
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

tl "versions"
nats-server --version; nats --version

tl "fresh lab: down --purge, up 1"
lab down --purge >/dev/null 2>&1
pkill -f 'nats (sub|reply|bench)' 2>/dev/null
lab up 1

tl "A0 · baseline, no stream"
snap "A0 baseline"

tl "A1 (= run B) · the per-stream floor: one empty file stream"
python3 topolab.py mkstreams 4291 1 T 1 file
snap "A1 one empty stream"
echo "--- the store tree of that one stream ---"
find "$STORE/jetstream/\$G/streams" -maxdepth 3 | sed "s|$LAB|<lab>|" | sort | head -20
echo "--- byte sizes ---"
find "$STORE/jetstream/\$G/streams/T00001" -type f -exec ls -l {} \; | awk '{print $5, $9}' | sed "s|$LAB|<lab>|"
echo "--- and one empty memory stream, for the comparison ---"
$N stream add MEMONE --subjects 'memone.>' --storage memory --retention limits --replicas 1 --defaults >/dev/null 2>&1
snap "A1b + one empty memory stream"
$N stream rm MEMONE -f >/dev/null 2>&1

tl "A1c · publish rate into T00001 with 1 stream on the server"
python3 topolab.py pubrate 4291 t.00001.evt 20000 128

tl "A2 · grow to 10 streams"
python3 topolab.py mkstreams 4291 10 T 1 file
snap "A2 ten streams"
python3 topolab.py pubrate 4291 t.00001.evt 20000 128

tl "A3 · grow to 100 streams"
python3 topolab.py mkstreams 4291 100 T 1 file
snap "A3 one hundred streams"
python3 topolab.py pubrate 4291 t.00001.evt 20000 128

tl "A4 · grow to 1000 streams"
python3 topolab.py mkstreams 4291 1000 T 1 file
snap "A4 one thousand streams"
python3 topolab.py pubrate 4291 t.00001.evt 20000 128

tl "A4b · what the server says about a thousand streams"
echo "--- nats server report jetstream ---"
$SYS server report jetstream 2>&1 | head -20
echo "--- \$JS.API.STREAM.NAMES / LIST timing ---"
python3 topolab.py apitime 4291 '$JS.API.STREAM.NAMES' '{"offset":0}'
python3 topolab.py apitime 4291 '$JS.API.STREAM.LIST' '{"offset":0}'
echo "--- time nats stream ls ---"
python3 - <<'PY'
import subprocess, time
t0=time.monotonic()
r=subprocess.run(["nats","--server","nats://127.0.0.1:4291","--timeout=60s","stream","ls","-n"],capture_output=True,text=True)
print(f"nats stream ls -n: {time.monotonic()-t0:.2f}s, {len(r.stdout.splitlines())} lines")
PY
echo "--- /jsz (no accounts) ---"
curl -s "http://127.0.0.1:$HP/jsz" | python3 -m json.tool | head -30

tl "A5 · fill the thousand streams: 100 messages of 128 B each = 100,000 messages"
du -sk "$STORE/jetstream/\$G/streams" | awk '{print "streams dir before: " $1 " KiB"}'
python3 topolab.py fill 4291 't.%05d.evt' 100000 128 1000
snap "A5 1000 streams x 100 msgs"
du -sk "$STORE/jetstream/\$G/streams" | awk '{print "streams dir after: " $1 " KiB"}'
du -sk "$STORE/jetstream/\$G/streams/T00001" | awk '{print "one filled stream: " $1 " KiB"}'

tl "A6 · the same volume through ONE stream with a tenant token"
$N stream add ONE --subjects 'one.>' --storage file --retention limits --replicas 1 --defaults >/dev/null 2>&1
snap "A6a ONE created"
python3 topolab.py fill 4291 'one.%05d.evt' 100000 128 1000
snap "A6b ONE filled with the same 100,000 messages over 1000 subjects"
du -sk "$STORE/jetstream/\$G/streams/ONE" | awk '{print "ONE: " $1 " KiB"}'
$N stream info ONE 2>&1 | head -25
echo "--- ONE's store tree ---"
find "$STORE/jetstream/\$G/streams/ONE" -type f -exec ls -l {} \; | awk '{print $5, $9}' | sed "s|$LAB|<lab>|" | head

tl "A7 · restart with 1001 streams and 180,000 messages: clean stop, start, time to healthy"
$N stream report 2>&1 | tail -3
lab stop 1
python3 - <<'PY'
import subprocess, time, urllib.request
t0 = time.monotonic()
subprocess.run(["bash", "/Users/m64/space/64/nats-wiki/tools/lab/cluster.sh", "start", "1"],
               capture_output=True, text=True)
code = 0
while time.monotonic() - t0 < 300:
    try:
        with urllib.request.urlopen("http://127.0.0.1:8291/healthz", timeout=5) as r:
            code = r.status
        if code == 200: break
    except Exception:
        pass
    time.sleep(0.05)
print(f"start -> /healthz 200 in {time.monotonic()-t0:.3f}s (code {code})")
PY
snap "A7 after restart"
echo "--- what the log says about the restart ---"
tail -40 "$LAB/n1/n1.log" | sed "s|$LAB|<lab>|"
echo "--- 'Restored' lines in this boot ---"
grep -c "Restored" "$LAB/n1/n1.log"

tl "A7b · restart again, this time after a SIGKILL"
lab stop 1 -9
python3 - <<'PY'
import subprocess, time, urllib.request
t0 = time.monotonic()
subprocess.run(["bash", "/Users/m64/space/64/nats-wiki/tools/lab/cluster.sh", "start", "1"],
               capture_output=True, text=True)
code = 0
while time.monotonic() - t0 < 600:
    try:
        with urllib.request.urlopen("http://127.0.0.1:8291/healthz", timeout=5) as r:
            code = r.status
        if code == 200: break
    except Exception:
        pass
    time.sleep(0.05)
print(f"SIGKILL, start -> /healthz 200 in {time.monotonic()-t0:.3f}s (code {code})")
PY
snap "A7b after the SIGKILL restart"
grep -c "rebuild" "$LAB/n1/n1.log"

tl "done"
