#!/usr/bin/env bash
# client-lifecycle-stale-run.sh — run D of raw/nats-server-src/client-lifecycle-observed-v2.14.6.md
#
# The stale link, from both ends, on a standalone nats-server v2.14.6.
#   D1  the SERVER's side, with ping_interval shortened from the 2-minute default to 5 s so the
#       arithmetic is visible in seconds: a raw client that never answers PING, timed to the
#       server's `Stale Connection` and its log line.
#   D2  the control — the same client answering PONG.
#   D3  the CLIENT's side, at nats.go's own defaults (2 m interval, 2 outstanding pings): `nats sub
#       --trace` against a server that is SIGSTOPped for 7.5 minutes. This is the measurement that
#       settles whether detection lands on the second or the third unanswered ping — ADR-40 says
#       two consecutive missed PONGs, the docs and nats.go say the third ping.
set -uo pipefail
set -m
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="${OUT:-$HERE}"
PORT=14222; HTTP=18222
say() { echo; echo "--- $*"; }
hdr() { echo; echo "### $*"; }

hdr versions
nats-server --version; echo "nats CLI: $(nats --version)"; echo "date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"

cat > "$OUT/ping.conf" <<CONF
listen: 127.0.0.1:$PORT
http: 127.0.0.1:$HTTP
ping_interval: "5s"
ping_max: 2
CONF
say "the config for D1 and D2"
cat "$OUT/ping.conf"
rm -f "$OUT/d-server.log"
nats-server -c "$OUT/ping.conf" -l "$OUT/d-server.log" &
SRV=$!
sleep 1

hdr "D1 — a client that never answers PING (server ping_interval 5s, ping_max 2)"
python3 "$HERE/stale-client.py" --port $PORT --wait 40 2>&1 | tee "$OUT/d1-client.log"
say "D1: what the server logged"
grep -iE 'stale|slow|:.*cid' "$OUT/d-server.log" | tail -6
say "D1: /varz"
curl -s "http://127.0.0.1:$HTTP/varz" | python3 -c 'import json,sys; d=json.load(sys.stdin); print("connections", d["connections"], "total_connections", d["total_connections"], "ping_interval(ns)", d.get("ping_interval"), "ping_max", d.get("ping_max"), "slow_consumers", d.get("slow_consumers"))'

hdr "D2 — the control: the same client answering PONG"
python3 "$HERE/stale-client.py" --port $PORT --wait 22 --answer 2>&1 | tee "$OUT/d2-client.log"
say "D2: the server's log since D1"
tail -3 "$OUT/d-server.log"
kill -TERM $SRV 2>/dev/null; wait $SRV 2>/dev/null

hdr "D3 — the client's side at nats.go's defaults: the server SIGSTOPped for 7.5 minutes"
cat > "$OUT/plain.conf" <<CONF
listen: 127.0.0.1:$PORT
http: 127.0.0.1:$HTTP
CONF
rm -f "$OUT/d3-server.log" "$OUT/d3-sub.log"
nats-server -c "$OUT/plain.conf" -l "$OUT/d3-server.log" &
SRV=$!
sleep 1
nats sub 'stale.>' --server "nats://127.0.0.1:$PORT" --connection-name warehouse --trace > "$OUT/d3-sub.log" 2>&1 &
SUB=$!
sleep 3
echo "SIGSTOP to the server (pid $SRV) at $(date -u +%H:%M:%S)"
kill -STOP $SRV
python3 - "$OUT/d3-sub.log" <<'PY'
import os, sys, time
path = sys.argv[1]; t0 = time.time(); deadline = t0 + 460
seen = set()
while time.time() < deadline:
    try:
        for l in open(path):
            l = l.rstrip()
            if l and l not in seen and ('>>>' in l or 'stale' in l.lower()):
                seen.add(l); print("  +%6.1f s  %s" % (time.time() - t0, l), flush=True)
                if 'Disconnected' in l or 'closed' in l: deadline = min(deadline, time.time() + 20)
    except FileNotFoundError:
        pass
    time.sleep(1)
print("  watcher done after %.1f s" % (time.time() - t0))
PY
echo "SIGCONT at $(date -u +%H:%M:%S)"
kill -CONT $SRV
sleep 10
kill -INT $SUB 2>/dev/null; sleep 1; kill -TERM $SUB 2>/dev/null; wait $SUB 2>/dev/null
say "D3: everything the subscriber printed"
cat "$OUT/d3-sub.log"
say "D3: the server's log after it was resumed"
tail -6 "$OUT/d3-server.log"
kill -TERM $SRV 2>/dev/null; wait $SRV 2>/dev/null
hdr done
