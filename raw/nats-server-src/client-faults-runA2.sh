#!/usr/bin/env bash
# Run A, second pass -- A4 redone (a sync subscription really floods this time)
# and A6, the server's *other* slow-consumer branch: max_pending rather than
# write_deadline. Also records what the cut client sees on its socket.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
BIN=${BIN:-nats-server}
S=nats://127.0.0.1:4222
say(){ printf '\n===== %s =====\n' "$*"; }
start(){ "$BIN" -c "$HERE/$1" -l "$HERE/$2" -DV & SRV=$!
  for i in $(seq 1 50); do curl -sf http://127.0.0.1:8222/healthz >/dev/null && break; sleep 0.1; done; }
stop(){ kill "$SRV" 2>/dev/null; wait "$SRV" 2>/dev/null; }

say "A4 -- a sync subscription: the default limit, and NextMsg after the overflow"
start base.conf a4-server.log
( cd "$HERE/go" && go build -o /tmp/slowsub . ) || exit 1
/tmp/slowsub -mode=sync -msgs=50 -sleep=20ms -wait=6s > "$HERE/a4-sync.out" 2> "$HERE/a4-sync.err" &
GOPID=$!
sleep 0.8
nats pub 'orders.created' '{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200}' --count 4000 -s "$S" 2>&1 | tail -1
wait $GOPID
cat "$HERE/a4-sync.out"; echo "--- stderr:"; cat "$HERE/a4-sync.err"
stop

say "A6 -- the server's max_pending branch (write_deadline 30s, max_pending 1MB)"
start mp.conf a6-server.log
python3 "$HERE/deadsub.py" > "$HERE/a6-deadsub.log" 2>&1 &
DPID=$!
sleep 1
nats pub 'orders.created' "$(python3 -c 'print("x"*4000)')" --count 20000 -s "$S" 2>&1 | tail -1
echo "--- waiting for the raw subscriber to wake and drain"
wait $DPID
cat "$HERE/a6-deadsub.log"
echo "--- /varz:"
curl -s http://127.0.0.1:8222/varz | python3 -c 'import json,sys;v=json.load(sys.stdin);print({k:v[k] for k in ("slow_consumers","slow_consumer_stats","max_pending","write_deadline")})'
echo "--- server log:"
grep -E 'Slow Consumer|connection closed' "$HERE/a6-server.log" | head -6
echo "--- /connz closed connections:"
curl -s 'http://127.0.0.1:8222/connz?state=closed' | python3 -c 'import json,sys;d=json.load(sys.stdin);print([(c["name"],c.get("reason")) for c in d["connections"]])'
stop
say "done"
