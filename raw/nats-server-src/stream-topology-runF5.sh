#!/bin/bash
# Run F5 — the two cases run F4 got wrong: the transform field on a mirror/source is
# `subject_transforms: [{src, dest}]` (stream.go:411 and :174 at v2.14.6), not the flat
# `subject_transform_dest` the CLI's flag name suggests. Redone, plus the sourcing stream's own
# subjects alongside a transform, and what a mirror costs on disk against its origin.
set -u
D=$(cd "$(dirname "$0")" && pwd)
REPO=/Users/m64/space/64/nats-wiki
cd "$D"
N="nats --server nats://127.0.0.1:4291 --timeout=60s"
LAB="${TMPDIR:-/tmp}"; LAB="${LAB%/}/nats-lab"
STORE="$LAB/n1/store"
lab() { bash "$REPO/tools/lab/cluster.sh" "$@"; }
tl()  { python3 - "$@" <<'PY'
import sys, time
print(f"### [{time.strftime('%H:%M:%S')}] " + " ".join(sys.argv[1:]))
PY
}

tl "versions"; nats-server --version; nats --version
lab down --purge >/dev/null 2>&1
NATS_LAB_WAIT=300 lab up 1 | tail -1

tl "J0 · ORIG on orig.>, 10,000 messages over 4 subjects"
$N stream add ORIG --subjects 'orig.>' --storage file --retention limits --replicas 1 --defaults >/dev/null
python3 topolab.py fill 4291 'orig.%01d.evt' 10000 128 4

tl "J1 · a transformed mirror and a sourcing stream with its own subjects and a transform"
python3 - <<'PY'
import json, sys, time
sys.path.insert(0, ".")
import topolab
c = topolab.Nats(4291, "j1")
cases = {
 "mirror + subject_transforms": {"name":"M4","mirror":{"name":"ORIG",
     "subject_transforms":[{"src":"orig.*.evt","dest":"copy.{{wildcard(1)}}"}]},
     "storage":"file","num_replicas":1},
 "source + own subjects + transform": {"name":"S1","subjects":["own.>"],
     "sources":[{"name":"ORIG","subject_transforms":[{"src":"orig.*.evt","dest":"from-orig.{{wildcard(1)}}"}]}],
     "storage":"file","num_replicas":1},
}
for label, cfg in cases.items():
    m = c.request("$JS.API.STREAM.CREATE." + cfg["name"], json.dumps(cfg).encode(), timeout=60)
    d = json.loads(m[3])
    print(f"  {label:36s} -> " + ("REFUSED %s %s" % (d["error"]["err_code"], d["error"]["description"])
          if "error" in d else "created " + cfg["name"]))
time.sleep(2)
for st in ("ORIG","M4","S1"):
    d = json.loads(c.request("$JS.API.STREAM.INFO." + st, b"", timeout=60)[3])
    if "error" in d: print(f"  {st}: not there"); continue
    s = d["state"]
    print(f"  {st}: {s['messages']} messages, num_subjects {s.get('num_subjects')}, "
          f"cfg subjects {d['config'].get('subjects')}")
    m2 = c.request(f"$JS.API.STREAM.MSG.GET.{st}", b'{"seq":1}', timeout=60)
    d2 = json.loads(m2[3])
    if "error" not in d2:
        print(f"      seq 1 subject: {d2['message']['subject']}  hdrs {bool(d2['message'].get('hdrs'))}")
print("  --- publish own.thing into the sourcing stream ---")
m = c.request("own.thing", b"mine", timeout=30)
print("     ", m[3][:120].decode())
c.close()
PY

tl "J2 · disk: origin, mirror, sourcing stream, for the same 10,000 messages"
du -sk "$STORE/jetstream/\$G/streams/"* | sed "s|$LAB|<lab>|"
python3 - <<'PY'
import json, sys
sys.path.insert(0, ".")
import topolab
c = topolab.Nats(4291, "j2")
for st in ("ORIG","M4","S1"):
    d = json.loads(c.request("$JS.API.STREAM.INFO." + st, b"", timeout=60)[3])
    if "error" in d: continue
    s = d["state"]
    print(f"  {st}: {s['messages']} messages, {s['bytes']} bytes "
          f"({s['bytes']/max(s['messages'],1):.1f} B/msg)")
c.close()
PY

tl "done"
