#!/bin/bash
# Run C — filtered consumers on one big stream: the sparse seek gh#3405 claims is indexed, the cost
# of 1/10/100/300 consumers, the cost of 1..1000 disjoint filters on *one* consumer, and the same
# fan-out built as N small streams instead.
# nats-server v2.14.6, nats CLI 0.4.0, one standalone server (tools/lab/cluster.sh up 1).
set -u
D=$(cd "$(dirname "$0")" && pwd)
REPO=/Users/m64/space/64/nats-wiki
cd "$D"
N="nats --server nats://127.0.0.1:4291 --timeout=300s"
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

tl "versions"; nats-server --version; nats --version

tl "fresh lab: down --purge, up 1"
lab down --purge >/dev/null 2>&1
NATS_LAB_WAIT=300 lab up 1
snap "C0 baseline"

tl "C1 · BIG: 1,000,000 x 128 B over 1000 subjects, with one needle in the middle"
$N stream add BIG --subjects 'big.>' --storage file --retention limits --replicas 1 --defaults >/dev/null
python3 topolab.py fill 4291 'big.%05d.evt' 500000 128 1000
$N pub big.needle.one 'the one message on this subject' >/dev/null
python3 topolab.py fill 4291 'big.%05d.evt' 500000 128 1000
snap "C1 BIG filled"
$N stream info BIG 2>&1 | grep -iE "messages|bytes|subjects|First|Last" | head -8
python3 topolab.py streaminfo 4291 BIG

tl "C1b · the seek: a filter with ONE match in the middle of a million"
python3 topolab.py firstfetch 4291 BIG 'big.needle.one' needle
python3 topolab.py firstfetch 4291 BIG 'big.needle.one' needle-again
echo "--- against a dense filter (1000 matches, the first at sequence 1) ---"
python3 topolab.py firstfetch 4291 BIG 'big.00001.evt' dense
echo "--- against the whole stream ---"
python3 topolab.py firstfetch 4291 BIG 'big.>' all
echo "--- and a filter that matches nothing at all ---"
python3 topolab.py firstfetch 4291 BIG 'big.absent.subject' absent

tl "C2 · N consumers with one filter each: 1, 10, 100, 300"
for n in 1 10 100 300; do
  python3 topolab.py mkcons 4291 BIG "$n" 'big.%05d.evt' C
  snap "C2 $n filtered consumers on BIG"
  python3 topolab.py pubrate 4291 big.00001.evt 20000 128
  python3 topolab.py conslist 4291 BIG
done

tl "C2b · 1000 consumers on the one stream"
python3 topolab.py mkcons 4291 BIG 1000 'big.%05d.evt' C
snap "C2b 1000 filtered consumers on BIG"
python3 topolab.py pubrate 4291 big.00001.evt 20000 128
python3 topolab.py conslist 4291 BIG
echo "--- what one consumer info costs at that count ---"
python3 topolab.py apitime 4291 '$JS.API.CONSUMER.INFO.BIG.C0500' 2>&1 | head -2

tl "C2c · restart with 1000 consumers on one stream"
lab stop 1
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
    time.sleep(0.02)
print(f"C2c clean restart, 1 stream / 1,020,000 msgs / 1000 consumers: /healthz 200 in {time.monotonic()-t0:.3f}s (code {code})")
PY
snap "C2c after restart"
grep "Took .* to start JetStream" "$LAB/n1/n1.log" | tail -1

tl "C3 · ONE consumer with N disjoint filters (the 2.10 multi-filter form)"
for n in 1 10 100 300 1000; do
  python3 topolab.py multifetch 4291 BIG "$n" 'big.%05d.evt'
done
echo "--- 2000 and 5000, to find where it stops being reasonable ---"
python3 topolab.py multifetch 4291 BIG 2000 'big.%05d.evt'
python3 topolab.py multifetch 4291 BIG 5000 'big.%05d.evt'
echo "--- the wildcard that covers all 1000, for comparison ---"
python3 topolab.py firstfetch 4291 BIG 'big.*.evt' wildcard

tl "C4 · the same fan-out as 300 small streams with one consumer each"
lab down --purge >/dev/null 2>&1
NATS_LAB_WAIT=300 lab up 1
snap "C4 baseline"
python3 topolab.py mkstreams 4291 300 S 1 file
python3 - <<'PY'
import subprocess, time, sys
sys.path.insert(0, ".")
import topolab
c = topolab.Nats(4291, "mk1")
import json
t0 = time.monotonic()
for i in range(1, 301):
    st = f"S{i:05d}"
    cfg = {"stream_name": st, "config": {"durable_name": "WORKER", "ack_policy": "explicit",
           "deliver_policy": "all", "max_ack_pending": 1000}}
    c.request(f"$JS.API.CONSUMER.DURABLE.CREATE.{st}.WORKER", json.dumps(cfg).encode(), timeout=60)
print(f"one consumer on each of 300 streams: {time.monotonic()-t0:.2f}s")
c.close()
PY
snap "C4 300 streams, 300 consumers (one each)"
python3 topolab.py fill 4291 's.%05d.evt' 300000 128 300
snap "C4 filled with 300,000 messages"
python3 topolab.py pubrate 4291 s.00001.evt 20000 128
echo "--- the same 300,000 messages and 300 consumers on ONE stream, for the comparison ---"
lab down --purge >/dev/null 2>&1
NATS_LAB_WAIT=300 lab up 1
$N stream add ONE --subjects 'one.>' --storage file --retention limits --replicas 1 --defaults >/dev/null
python3 topolab.py mkcons 4291 ONE 300 'one.%05d.evt' W
snap "C4b ONE stream, 300 filtered consumers"
python3 topolab.py fill 4291 'one.%05d.evt' 300000 128 300
snap "C4b filled with the same 300,000 messages"
python3 topolab.py pubrate 4291 one.00001.evt 20000 128

tl "done"
