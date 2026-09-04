#!/bin/bash
# Run E — subject cardinality on one axis: the same 1,000,000 messages over 10, 10,000 and
# 1,000,000 distinct subjects. RSS, index.db against the len(subject)+4 arithmetic, `nats stream
# subjects`, the STREAM.INFO subject-details paging, a filtered first fetch, and the restart.
# nats-server v2.14.6, nats CLI 0.4.0, one standalone server per scene (a fresh lab each time, so
# the RSS delta belongs to that scene alone).
set -u
D=$(cd "$(dirname "$0")" && pwd)
REPO=/Users/m64/space/64/nats-wiki
cd "$D"
N="nats --server nats://127.0.0.1:4291 --timeout=600s"
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

scene() {   # scene <label> <nsubjects>
  local label="$1" nsub="$2"
  tl "E · $label — 1,000,000 x 128 B over $nsub subject(s)"
  lab down --purge >/dev/null 2>&1
  NATS_LAB_WAIT=600 lab up 1 | tail -2
  snap "$label baseline"
  $N stream add CARD --subjects 'c.>' --storage file --retention limits --replicas 1 --defaults >/dev/null
  python3 topolab.py fill 4291 'c.%07d.evt' 1000000 128 "$nsub"
  snap "$label filled"
  echo "--- stream info ---"
  python3 topolab.py streaminfo 4291 CARD
  echo "--- subject details: STREAM.INFO with subjects_filter '>' ---"
  python3 topolab.py subjdetails 4291 CARD '>' 0
  echo "--- and at offset 100000 (JSMaxSubjectDetails = 100,000 at v2.14.6) ---"
  python3 topolab.py subjdetails 4291 CARD '>' 100000
  echo "--- nats stream subjects ---"
  python3 - "$nsub" <<'PY'
import subprocess, time, sys
t0 = time.monotonic()
r = subprocess.run(["nats","--server","nats://127.0.0.1:4291","--timeout=600s","stream","subjects","CARD"],
                   capture_output=True, text=True)
print(f"nats stream subjects CARD: {time.monotonic()-t0:.2f}s, "
      f"{len(r.stdout.splitlines())} stdout lines, {len(r.stderr.splitlines())} stderr lines")
print("  first stderr line:", (r.stderr.splitlines() or [""])[0][:160])
PY
  echo "--- a filtered consumer's first fetch, on one subject and on the wildcard ---"
  python3 topolab.py firstfetch 4291 CARD 'c.0000001.evt' one-subject
  python3 topolab.py firstfetch 4291 CARD 'c.*.evt' wildcard
  echo "--- clean stop, then the index.db the stop wrote ---"
  lab stop 1
  find "$STORE/jetstream/\$G/streams/CARD" -name 'index.db' -exec ls -l {} \; | awk '{print $5, $9}' | sed "s|$LAB|<lab>|"
  python3 - "$nsub" <<'PY'
import sys
n = int(sys.argv[1])
# the subject format is c.%07d.evt -> 1 + 1 + 7 + 1 + 3 = 13 bytes
print(f"predicted sum(len(subject) + 4) = {n} x (13 + 4) = {n * 17} bytes")
PY
  restart "$label restart after a clean stop"
  snap "$label after restart"
  grep "Took .* to start JetStream" "$LAB/n1/n1.log" | tail -1
  echo "--- and once more, after a SIGKILL that follows a write ---"
  python3 topolab.py pubrate 4291 c.9999999.evt 1000 128
  lab stop 1 -9
  python3 - <<'PY'
import time, subprocess
# `cluster.sh stop k -9` returns before the process is gone; `start` then refuses on a bound port.
for _ in range(200):
    if subprocess.run(["pgrep", "-f", "nats-server -c"], capture_output=True).returncode != 0:
        break
    time.sleep(0.05)
PY
  restart "$label restart after SIGKILL"
  snap "$label after the SIGKILL restart"
  grep "Took .* to start JetStream" "$LAB/n1/n1.log" | tail -1
  grep -c "will rebuild" "$LAB/n1/n1.log"
}

tl "versions"; nats-server --version; nats --version
scene "E1 ten subjects" 10
scene "E2 ten thousand subjects" 10000
scene "E3 one million subjects" 1000000
tl "done"
