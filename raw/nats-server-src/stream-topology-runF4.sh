#!/bin/bash
# Run F4 — what each replication shape can and cannot be configured to do: subjects on a mirror,
# a filtered mirror, a subject transform, several sources, and what happens to each when the origin
# stream is deleted. nats-server v2.14.6, nats CLI 0.4.0, one standalone server.
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
pkill -f 'nats sub' 2>/dev/null
lab down --purge >/dev/null 2>&1
NATS_LAB_WAIT=300 lab up 1 | tail -1

tl "I0 · ORIG on orig.>, 10,000 messages over 4 subjects"
$N stream add ORIG --subjects 'orig.>' --storage file --retention limits --replicas 1 --defaults >/dev/null
python3 topolab.py fill 4291 'orig.%01d.evt' 10000 128 4

tl "I1 · a stream that is a mirror AND has subjects of its own"
python3 - <<'PY'
import json, sys
sys.path.insert(0, ".")
import topolab
c = topolab.Nats(4291, "i1")
cases = {
 "mirror + subjects": {"name":"M1","subjects":["m1.>"],"mirror":{"name":"ORIG"},"storage":"file","num_replicas":1},
 "mirror + sources":  {"name":"M2","mirror":{"name":"ORIG"},"sources":[{"name":"ORIG"}],"storage":"file","num_replicas":1},
 "mirror, filtered":  {"name":"M3","mirror":{"name":"ORIG","filter_subject":"orig.1.evt"},"storage":"file","num_replicas":1},
 "mirror, transformed": {"name":"M4","mirror":{"name":"ORIG","subject_transform_dest":"copy.{{wildcard(1)}}",
                          "filter_subject":"orig.*.evt"},"storage":"file","num_replicas":1},
 "source + own subjects + transform": {"name":"S1","subjects":["own.>"],
                          "sources":[{"name":"ORIG","subject_transform_dest":"from-orig.{{wildcard(1)}}",
                                      "filter_subject":"orig.*.evt"}],"storage":"file","num_replicas":1},
 "two sources of the same stream": {"name":"S2","sources":[{"name":"ORIG","filter_subject":"orig.1.evt"},
                                      {"name":"ORIG","filter_subject":"orig.2.evt"}],"storage":"file","num_replicas":1},
}
for label, cfg in cases.items():
    m = c.request("$JS.API.STREAM.CREATE." + cfg["name"], json.dumps(cfg).encode(), timeout=60)
    d = json.loads(m[3])
    if "error" in d:
        print(f"  {label:36s} -> REFUSED {d['error']['err_code']} {d['error']['description']}")
    else:
        print(f"  {label:36s} -> created {cfg['name']}")
c.close()
PY
sleep 2
python3 - <<'PY'
import json, sys
sys.path.insert(0, ".")
import topolab
c = topolab.Nats(4291, "i1b")
for st in ("ORIG","M3","M4","S1","S2"):
    m = c.request("$JS.API.STREAM.INFO." + st, b"", timeout=60)
    d = json.loads(m[3])
    if "error" in d: print(f"  {st}: not there"); continue
    s = d["state"]
    print(f"  {st}: {s['messages']} messages, num_subjects {s.get('num_subjects')}, "
          f"subjects cfg {d['config'].get('subjects')}")
    m2 = c.request(f"$JS.API.STREAM.MSG.GET.{st}", b'{"seq":1}', timeout=60)
    d2 = json.loads(m2[3])
    if "error" not in d2:
        print(f"      seq 1 subject: {d2['message']['subject']}")
c.close()
PY

tl "I2 · adding subjects to an existing mirror by update"
python3 - <<'PY'
import json, sys
sys.path.insert(0, ".")
import topolab
c = topolab.Nats(4291, "i2")
d = json.loads(c.request("$JS.API.STREAM.INFO.M3", b"", timeout=60)[3])
cfg = d["config"]; cfg["subjects"] = ["m3.>"]
m = c.request("$JS.API.STREAM.UPDATE.M3", json.dumps(cfg).encode(), timeout=60)
r = json.loads(m[3])
print("  add subjects to a mirror:", "REFUSED %s %s" % (r["error"]["err_code"], r["error"]["description"])
      if "error" in r else "accepted, subjects now " + str(r["config"].get("subjects")))
d = json.loads(c.request("$JS.API.STREAM.INFO.S1", b"", timeout=60)[3])
cfg = d["config"]; cfg["subjects"] = ["own.>", "extra.>"]
m = c.request("$JS.API.STREAM.UPDATE.S1", json.dumps(cfg).encode(), timeout=60)
r = json.loads(m[3])
print("  add a subject to a sourcing stream:", "REFUSED %s %s" % (r["error"]["err_code"], r["error"]["description"])
      if "error" in r else "accepted, subjects now " + str(r["config"].get("subjects")))
c.close()
PY

tl "I3 · delete the origin: what happens to the mirror and to the sourcing stream"
$N stream rm ORIG -f 2>&1 | tail -1
sleep 3
python3 - <<'PY'
import json, sys
sys.path.insert(0, ".")
import topolab
c = topolab.Nats(4291, "i3")
for st in ("M3","M4","S1","S2"):
    d = json.loads(c.request("$JS.API.STREAM.INFO." + st, b"", timeout=60)[3])
    if "error" in d: print(f"  {st}: gone"); continue
    s = d["state"]
    print(f"  {st}: still here, {s['messages']} messages")
c.close()
PY
echo "--- and can you still read from the mirror ---"
python3 topolab.py apitime 4291 '$JS.API.DIRECT.GET.M3.orig.1.evt' 2>&1 | head -2
echo "--- the log ---"
tail -6 "$LAB/n1/n1.log" | sed "s|$LAB|<lab>|"

tl "done"
