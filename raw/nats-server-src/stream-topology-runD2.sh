#!/bin/bash
# Run D2 — the rest of run D: the tenant's full `nats account info` (D0 and D4 were cut at 40 lines),
# what a publish does at the very edge of max_file, and whether a delete gives the budget back.
set -u
D=$(cd "$(dirname "$0")" && pwd); cd "$D"
T="nats --server nats://t:t@127.0.0.1:4321 --timeout=20s"
tl() { python3 - "$@" <<'PY'
import sys, time
print(f"### [{time.strftime('%H:%M:%S')}] " + " ".join(sys.argv[1:]))
PY
}
tl "D7 · the tenant's own view of its limits, in full"
$T account info 2>&1 | sed -n '/JetStream Account Information/,$p'

tl "D8 · five single publishes at the edge of max_file"
for i in 1 2 3 4 5; do
  NLAB_USER=t NLAB_PASS=t python3 topolab.py apitime 4321 "s1.edge$i" 'x' 2>&1 | tail -1
done
curl -s "http://127.0.0.1:8321/jsz?accounts=1" | python3 -c '
import json,sys
d=json.load(sys.stdin)
for a in d.get("account_details",[]):
    if a["name"]=="TENANT":
        print("TENANT storage", a["storage"], "reserved_storage", a["reserved_storage"],
              "headroom", a["reserved_storage"]-a["storage"])'

tl "D9 · purge S1: does the budget come back, and what does the tenant see"
$T stream purge S1 -f 2>&1 | tail -2
$T account info 2>&1 | sed -n '/Account Usage/,/^$/p'
NLAB_USER=t NLAB_PASS=t python3 topolab.py apitime 4321 's1.after-purge' 'x' 2>&1 | tail -1

tl "D10 · and the fourth stream, once one of the three is deleted"
$T stream rm S3 -f >/dev/null 2>&1
$T stream add S4 --subjects 's4.>' --storage file --retention limits --replicas 1 --defaults 2>&1 | tail -2
$T stream ls -n 2>&1 | tail -5

tl "done"
