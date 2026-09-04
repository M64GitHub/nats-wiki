#!/usr/bin/env python3
"""snap.py <http-port> <label> [store_dir] — one line of process and JetStream state.

Reads /varz and /jsz from the monitoring port, `ps -o rss=` for the process, and (when a store
directory is given) `du -sk` plus the file and directory counts under it.
"""
import sys, json, os, subprocess, urllib.request

port = sys.argv[1]; label = sys.argv[2]
store = sys.argv[3] if len(sys.argv) > 3 else ""
pidfile = sys.argv[4] if len(sys.argv) > 4 else os.path.join(
    os.environ.get("TMPDIR", "/tmp").rstrip("/"), "nats-lab", "n1", "n1.pid")

def get(path):
    with urllib.request.urlopen(f"http://127.0.0.1:{port}{path}", timeout=30) as r:
        return json.load(r)

v = get("/varz")
j = get("/jsz")
pid = int(open(pidfile).read().strip())   # /varz carries no pid; the lab writes one (-P)
rss = subprocess.run(["ps", "-o", "rss=", "-p", str(pid)], capture_output=True, text=True).stdout.strip()
rss_mib = int(rss) / 1024 if rss else -1
mem_mib = v["mem"] / 1048576

print(f"[{label}]")
print(f"  varz mem {v['mem']} B = {mem_mib:.1f} MiB   ps rss {rss_mib:.1f} MiB   "
      f"cpu {v.get('cpu')}%   subs {v.get('subscriptions')}   conns {v.get('connections')}")
print(f"  jsz streams {j.get('streams')} consumers {j.get('consumers')} messages {j.get('messages')} "
      f"bytes {j.get('bytes')} memory {j.get('memory')} storage {j.get('storage')} "
      f"api_total {j.get('api', {}).get('total')} api_errors {j.get('api', {}).get('errors')}")
if store and os.path.isdir(store):
    du = subprocess.run(["du", "-sk", store], capture_output=True, text=True).stdout.split()[0]
    nf = nd = 0
    for _root, dirs, files in os.walk(store):
        nd += len(dirs); nf += len(files)
    print(f"  store {store}: {int(du)} KiB = {int(du)/1024:.1f} MiB, {nd} dirs, {nf} files")
