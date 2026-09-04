#!/usr/bin/env bash
# Run A -- the two slow consumers, client-side and server-side.
#
#   A1  no async error callback set      -> what nats.go writes, and where
#   A2  an explicit callback             -> fires per transition, not per drop
#   A3  SetPendingLimits(0, -1)          -> ErrInvalidArg; negative = unlimited
#   A4  a sync subscription              -> NextMsg returns ErrSlowConsumer once
#   A5  server-side: write_deadline      -> the log line, /varz, the disconnect
#   A6  server-side: max_pending         -> the other log line, same counter
#
# nats-server v2.14.6, nats CLI 0.4.0, nats.go v1.53.1, Go 1.27.0.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
BIN=${BIN:-nats-server}
S=nats://127.0.0.1:4222
say(){ printf '\n===== %s =====\n' "$*"; }

start(){ # $1 conf $2 logfile
  "$BIN" -c "$HERE/$1" -l "$HERE/$2" -DV &
  SRV=$!
  for i in $(seq 1 50); do curl -sf http://127.0.0.1:8222/healthz >/dev/null && break; sleep 0.1; done
}
stop(){ kill "$SRV" 2>/dev/null; wait "$SRV" 2>/dev/null; }

say "versions"
"$BIN" --version; nats --version; (cd "$HERE/go" && grep '^require\|nats.go' go.mod)

start base.conf a-server.log

for mode in default callback; do
  say "A$( [ $mode = default ] && echo 1 || echo 2 ) -- client-side slow consumer, mode=$mode"
  ( cd "$HERE/go" && go run . -mode="$mode" -msgs=100 -sleep=20ms -wait=5s ) \
      > "$HERE/a-$mode.out" 2> "$HERE/a-$mode.err" &
  GOPID=$!
  sleep 1.5
  echo "--- flooding: nats pub orders.created --count 5000"
  nats pub 'orders.created' \
    '{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}' \
    --count 5000 -s "$S" 2>&1 | tail -2
  wait $GOPID
  echo "--- stdout:"; cat "$HERE/a-$mode.out"
  echo "--- stderr (this is where defaultErrHandler writes):"; cat "$HERE/a-$mode.err"
done

say "A3 -- SetPendingLimits(0, -1) and what a negative limit means"
( cd "$HERE/go" && go run . -mode=zero ) 2>&1 | tee "$HERE/a-zero.out"

say "A4 -- a sync subscription after the overflow"
( cd "$HERE/go" && go run . -mode=sync -msgs=50 -sleep=20ms -wait=5s ) > "$HERE/a-sync.out" 2> "$HERE/a-sync.err" &
GOPID=$!
sleep 1.5
nats pub 'orders.created' '{"order_id":"ord_8w2k"}' --count 4000 -s "$S" 2>&1 | tail -1
wait $GOPID
cat "$HERE/a-sync.out"; echo "--- stderr:"; cat "$HERE/a-sync.err"

say "A-varz -- the server saw no slow consumer at all in A1-A4"
curl -s http://127.0.0.1:8222/varz | python3 -c 'import json,sys;v=json.load(sys.stdin);print({k:v[k] for k in ("slow_consumers","slow_consumer_stats","max_pending","write_deadline")})'
stop

say "A5/A6 -- the server-side slow consumer (write_deadline 100ms, max_pending 1MB)"
start wd.conf a-wd-server.log
curl -s http://127.0.0.1:8222/varz | python3 -c 'import json,sys;v=json.load(sys.stdin);print({k:v[k] for k in ("slow_consumers","max_pending","write_deadline")})'
python3 "$HERE/deadsub.py" > "$HERE/a-deadsub.log" 2>&1 &
DPID=$!
sleep 1
echo "--- flooding a subscriber that never reads its socket"
nats pub 'orders.created' "$(python3 -c 'print("x"*4000)')" --count 20000 -s "$S" 2>&1 | tail -2
sleep 2
echo "--- the raw subscriber's view:"; cat "$HERE/a-deadsub.log"
echo "--- /varz after:"
curl -s http://127.0.0.1:8222/varz | python3 -c 'import json,sys;v=json.load(sys.stdin);print({k:v[k] for k in ("slow_consumers","slow_consumer_stats")})'
echo "--- the server log lines:"
grep -E 'Slow Consumer|slow consumer' "$HERE/a-wd-server.log" | head -10
kill $DPID 2>/dev/null
stop
say "done"
