#!/bin/bash
# Run F — the three ways to make a second copy of a stream: a mirror, a `sources` stream, and a
# consumer that delivers into a second stream. What each costs in disk and in catch-up time, and
# what each can and cannot do. nats-server v2.14.6, nats CLI 0.4.0, one standalone server.
set -u
D=$(cd "$(dirname "$0")" && pwd)
REPO=/Users/m64/space/64/nats-wiki
cd "$D"
N="nats --server nats://127.0.0.1:4291 --timeout=600s"
HP=8291
LAB="${TMPDIR:-/tmp}"; LAB="${LAB%/}/nats-lab"
STORE="$LAB/n1/store"
ST="$STORE/jetstream/\$G/streams"
lab() { bash "$REPO/tools/lab/cluster.sh" "$@"; }
snap() { python3 "$D/snap.py" "$HP" "$1" "$STORE"; }
tl()  { python3 - "$@" <<'PY'
import sys, time
print(f"### [{time.strftime('%H:%M:%S')}] " + " ".join(sys.argv[1:]))
PY
}
du1() { for s in "$@"; do du -sk "$ST/$s" 2>/dev/null | awk -v n="$s" '{print "  " n ": " $1 " KiB"}'; done; }

tl "versions"; nats-server --version; nats --version

tl "fresh lab: down --purge, up 1"
lab down --purge >/dev/null 2>&1
NATS_LAB_WAIT=600 lab up 1 | tail -2
snap "F0 baseline"

tl "F1 · SRC: 200,000 x 128 B over 100 subjects"
$N stream add SRC --subjects 'src.>' --storage file --retention limits --replicas 1 --defaults >/dev/null
python3 topolab.py fill 4291 'src.%05d.evt' 200000 128 100
snap "F1 SRC filled"
du1 SRC

tl "F2 · (i) a mirror"
python3 - <<'PY'
import subprocess, time
t0 = time.monotonic()
r = subprocess.run(["nats","--server","nats://127.0.0.1:4291","--timeout=600s","stream","add","MIR",
                    "--mirror","SRC","--storage","file","--replicas","1","--defaults"],
                   capture_output=True, text=True)
print(f"stream add MIR --mirror SRC: {time.monotonic()-t0:.3f}s")
print("\n".join((r.stdout + r.stderr).splitlines()[:6]))
PY
python3 topolab.py lagwait 4291 MIR 200000
du1 SRC MIR
snap "F2 mirror caught up"
echo "--- what the mirror's config looks like ---"
python3 topolab.py apitime 4291 '$JS.API.STREAM.INFO.MIR' 2>&1 | tail -2
echo "--- can you publish into a mirror? ---"
$N pub src.00001.evt 'direct into SRC' -J 2>&1 | tail -2
NLAB_USER= python3 topolab.py apitime 4291 'mir.anything' 'x' 2>&1 | tail -1
echo "--- a mirror has no subjects of its own: what nats stream info says ---"
$N stream info MIR --json 2>/dev/null | python3 -c 'import json,sys;d=json.load(sys.stdin);print("subjects:",d["config"].get("subjects"),"mirror:",d["config"].get("mirror"),"mirror_direct:",d["config"].get("mirror_direct"),"state.messages:",d["state"]["messages"],"first_seq:",d["state"]["first_seq"])'
echo "--- and a direct get from the mirror (mirror_direct off, then on) ---"
python3 topolab.py apitime 4291 '$JS.API.DIRECT.GET.MIR.src.00001.evt' 2>&1 | tail -2
$N stream edit MIR --json 2>/dev/null >/dev/null
python3 - <<'PY'
import json, sys, subprocess
sys.path.insert(0, ".")
import topolab
c = topolab.Nats(4291, "edit")
m = c.request("$JS.API.STREAM.INFO.MIR", b"", timeout=30)
cfg = json.loads(m[3])["config"]
cfg["mirror_direct"] = True
m2 = c.request("$JS.API.STREAM.UPDATE.MIR", json.dumps(cfg).encode(), timeout=60)
d = json.loads(m2[3])
print("mirror_direct update:", "error" in d and d["error"] or "ok, mirror_direct=" + str(d["config"]["mirror_direct"]))
c.close()
PY
python3 topolab.py apitime 4291 '$JS.API.DIRECT.GET.MIR.src.00001.evt' 2>&1 | tail -2

tl "F3 · (ii) a sourcing stream"
python3 - <<'PY'
import subprocess, time
t0 = time.monotonic()
r = subprocess.run(["nats","--server","nats://127.0.0.1:4291","--timeout=600s","stream","add","SRCD",
                    "--source","SRC","--subjects","own.>","--storage","file","--replicas","1","--defaults"],
                   capture_output=True, text=True)
print(f"stream add SRCD --source SRC --subjects own.>: {time.monotonic()-t0:.3f}s")
print("\n".join((r.stdout + r.stderr).splitlines()[:6]))
PY
python3 topolab.py lagwait 4291 SRCD 200000
du1 SRC MIR SRCD
snap "F3 sourcing stream caught up"
echo "--- a sourcing stream CAN have its own subjects ---"
$N pub own.thing 'published straight into SRCD' -J 2>&1 | tail -2
python3 topolab.py streaminfo 4291 SRCD
echo "--- do the source's consumers count against max_consumers? (numLimitableConsumers) ---"
python3 topolab.py conslist 4291 SRC
curl -s "http://127.0.0.1:$HP/jsz?consumers=1&streams=1&accounts=1" | python3 -c '
import json,sys
d=json.load(sys.stdin)
for a in d.get("account_details",[]):
    for st in a.get("stream_detail",[]):
        print(" ", st["name"], "consumer_count", st["state"].get("consumer_count"))' 2>/dev/null || true

tl "F4 · (iii) a consumer that delivers into a second stream"
$N stream add COPY --subjects 'copy.>' --storage file --retention limits --replicas 1 --defaults >/dev/null
python3 - <<'PY'
import json, sys, time
sys.path.insert(0, ".")
import topolab
c = topolab.Nats(4291, "pushcons")
cfg = {"stream_name": "SRC", "config": {"durable_name": "TOCOPY", "ack_policy": "none",
        "deliver_policy": "all", "deliver_subject": "copy.evt", "replay_policy": "instant"}}
t0 = time.monotonic()
m = c.request("$JS.API.CONSUMER.DURABLE.CREATE.SRC.TOCOPY", json.dumps(cfg).encode(), timeout=60)
print(f"push consumer SRC/TOCOPY -> copy.evt created in {(time.monotonic()-t0)*1000:.1f}ms")
d = json.loads(m[3])
if "error" in d: print("  error:", m[3][:300].decode())
c.close()
PY
python3 topolab.py lagwait 4291 COPY 200000
du1 SRC MIR SRCD COPY
snap "F4 consumer copy caught up"
echo "--- what the copy actually holds: subject, sequence, headers ---"
python3 - <<'PY'
import json, sys
sys.path.insert(0, ".")
import topolab
c = topolab.Nats(4291, "peek")
for st in ("SRC", "MIR", "SRCD", "COPY"):
    m = c.request(f"$JS.API.STREAM.MSG.GET.{st}", json.dumps({"seq": 1}).encode(), timeout=60)
    d = json.loads(m[3])
    if "error" in d:
        print(f"{st}: error {d['error']}"); continue
    msg = d["message"]
    print(f"{st}: seq {msg['seq']} subject {msg['subject']} hdrs {bool(msg.get('hdrs'))}")
c.close()
PY

tl "F5 · lag: 20,000 more messages into SRC, how fast does each copy follow"
python3 topolab.py pubrate 4291 src.00001.evt 20000 128
for s in MIR SRCD COPY; do python3 topolab.py lagwait 4291 "$s" 220000 120; done
python3 topolab.py streaminfo 4291 SRC
for s in MIR SRCD COPY; do python3 topolab.py streaminfo 4291 "$s"; done
du1 SRC MIR SRCD COPY
snap "F5 after 20,000 more"

tl "F6 · what each shape does with a delete on the source"
$N stream info SRC --json 2>/dev/null | python3 -c 'import json,sys;print("SRC first_seq", json.load(sys.stdin)["state"]["first_seq"])'
python3 - <<'PY'
import json, sys, time
sys.path.insert(0, ".")
import topolab
c = topolab.Nats(4291, "del")
m = c.request("$JS.API.STREAM.MSG.DELETE.SRC", json.dumps({"seq": 5}).encode(), timeout=60)
print("delete seq 5 from SRC:", m[3][:200].decode())
time.sleep(2)
for st in ("SRC", "MIR", "SRCD", "COPY"):
    m = c.request(f"$JS.API.STREAM.MSG.GET.{st}", json.dumps({"seq": 5}).encode(), timeout=60)
    d = json.loads(m[3])
    print(f"  {st} seq 5:", "gone: " + json.dumps(d["error"]) if "error" in d else "still there: " + d["message"]["subject"])
c.close()
PY

tl "F7 · restart: what each shape costs at boot"
lab stop 1
python3 - <<'PY'
import subprocess, time, urllib.request
t0 = time.monotonic()
subprocess.run(["bash", "/Users/m64/space/64/nats-wiki/tools/lab/cluster.sh", "start", "1"],
               capture_output=True, text=True)
while time.monotonic() - t0 < 600:
    try:
        with urllib.request.urlopen("http://127.0.0.1:8291/healthz", timeout=5) as r:
            if r.status == 200: break
    except Exception: pass
    time.sleep(0.02)
print(f"restart with SRC + mirror + source + copy: /healthz 200 in {time.monotonic()-t0:.3f}s")
PY
grep "Restored .* messages for stream" "$LAB/n1/n1.log" | tail -5 | sed "s|$LAB|<lab>|"
grep "Took .* to start JetStream" "$LAB/n1/n1.log" | tail -1
snap "F7 after restart"

tl "done"
