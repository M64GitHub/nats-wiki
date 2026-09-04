#!/usr/bin/env bash
# client-lifecycle-run2.sh — the second pass of raw/nats-server-src/client-lifecycle-observed-v2.14.6.md
#
# Three scenes the first pass could not answer:
#   A3  the at-most-once gap, made visible: the same subscriber-on-the-dying-node shape as A1, but
#       with the publisher running flat out instead of at 89 msg/s, so the reconnect gap is wider
#       than one message interval.
#   B3  the lame-duck INFO as a client actually receives it — a raw client watching n1's socket
#       while n1 is signalled, plus n1's whole lame-duck log.
#   C4  `nats reply` drained under one request per process, so each reply is printed or not printed
#       and the count after the Ctrl-C is unambiguous (the first pass counted a progress bar).
#   E8  a pull consumer fetching one message at a time in a loop while its leader's node stops.
#   E9  messages fetched with --no-ack, the leader's node stopped, and what comes back after
#       ack_wait.
set -uo pipefail
set -m
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../../../.." && pwd)"
LAB="$REPO/tools/lab/cluster.sh"
OUT="${OUT:-$HERE}"
LABDIR="${NATS_LAB_DIR:-${TMPDIR:-/tmp}/nats-lab}"; LABDIR="${LABDIR%/}"
S1=nats://127.0.0.1:4291; S2=nats://127.0.0.1:4292; S3=nats://127.0.0.1:4293
say() { echo; echo "--- $*"; }
hdr() { echo; echo "### $*"; }
gap() {
  python3 - "$1" <<'PY'
import re,sys
seen=[int(m.group(1)) for m in (re.search(r'^ord (\d+)$', l) for l in open(sys.argv[1])) if m]
if not seen: print("no payloads parsed"); raise SystemExit
s=set(seen); missing=[n for n in range(seen[0], seen[-1]+1) if n not in s]
print("first %d, last %d, received %d, missing inside the range %d" % (seen[0], seen[-1], len(seen), len(missing)))
if missing:
    runs=[]; start=prev=missing[0]
    for n in missing[1:]:
        if n==prev+1: prev=n; continue
        runs.append((start,prev)); start=prev=n
    runs.append((start,prev))
    print("  gaps: " + ", ".join("%d-%d (%d)" % (a,b,b-a+1) for a,b in runs))
PY
}

hdr versions
nats-server --version; echo "nats CLI: $(nats --version)"; echo "date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
bash "$LAB" down --purge >/dev/null 2>&1 || true
bash "$LAB" up 3 | tail -1

# ---------------------------------------------------------------- A3
hdr "A3 — the gap, at full publish rate"
say "A3: subscriber pinned to n1, publisher on n2 with no sleep; n1 stopped 2 s in"
rm -f "$OUT"/a3-sub.log "$OUT"/a3-pub.log
nats sub 'orders.new' --server "$S1" --connection-name warehouse --trace > "$OUT/a3-sub.log" 2>&1 &
SUB=$!; sleep 1
nats pub 'orders.new' 'ord {{Count}}' --count 200000 --server "$S2" --connection-name order-svc > "$OUT/a3-pub.log" 2>&1 &
PUB=$!; sleep 2
echo "stopping n1 at $(date -u +%H:%M:%S.%N | cut -c1-12)"; bash "$LAB" stop 1
wait $PUB; echo "publisher exit: $?"
sleep 2; kill -INT $SUB 2>/dev/null; sleep 1; kill -TERM $SUB 2>/dev/null; wait $SUB 2>/dev/null
echo "publisher's own rate line: $(grep -o 'done!.*' "$OUT/a3-pub.log" | tail -1)"
echo "what the subscriber received:"; gap "$OUT/a3-sub.log"
say "A3: the subscriber's non-message lines"
grep -vE '^\[#|^ord |^$' "$OUT/a3-sub.log" | head -10
bash "$LAB" start 1 | tail -1; sleep 3

# ---------------------------------------------------------------- B3
hdr "B3 — the lame-duck INFO a client receives, and n1's whole lame-duck log"
say "B3: a raw client on n1, then ldm; the async INFO is the interesting line"
rm -f "$OUT"/b3-raw.log
python3 "$HERE/raw-watch.py" --port 4291 --wait 25 --sub 'orders.>' > "$OUT/b3-raw.log" 2>&1 &
RAW=$!; sleep 2
PID1="$(cat "$LABDIR/n1/n1.pid")"
echo "n1 pid $PID1 — signalling ldm at $(date -u +%H:%M:%S.%N | cut -c1-12)"
nats-server --signal ldm="$PID1"
wait $RAW 2>/dev/null
say "B3: everything the raw client saw"
cat "$OUT/b3-raw.log"
say "B3: n1's lame-duck log, from the notice down"
sed -n '/lame duck/,$p' "$LABDIR/n1/n1.log" | head -12
say "B3: what the INFO's connect_urls held, parsed"
python3 - "$OUT/b3-raw.log" <<'PY'
import json,sys,re
for l in open(sys.argv[1]):
    m=re.search(r'<< INFO (\{.*\})\s*$', l)
    if not m: continue
    d=json.loads(m.group(1))
    print("%s  server_name=%s ldm=%s connect_urls=%s" % (l.split()[0], d.get("server_name"), d.get("ldm"), d.get("connect_urls")))
PY
bash "$LAB" down >/dev/null 2>&1; bash "$LAB" up 3 | tail -1

# ---------------------------------------------------------------- C4
hdr "C4 — nats reply drained with one request per process"
say "C4: responder sleeping 1 s per reply; 8 concurrent single requests; SIGINT 2 s in"
rm -f "$OUT"/c4-reply.log "$OUT"/c4-req-*.log
nats reply 'orders.check' 'ok' --sleep 1s --server "$S1" > "$OUT/c4-reply.log" 2>&1 &
REP=$!; sleep 1
for i in 1 2 3 4 5 6 7 8; do
  nats request 'orders.check' "q$i" --timeout 8s --server "$S1" > "$OUT/c4-req-$i.log" 2>&1 &
done
sleep 2
echo "SIGINT to nats reply at $(date -u +%H:%M:%S.%N | cut -c1-12)"
kill -INT $REP
wait $REP 2>/dev/null; echo "nats reply exit: $?"
wait
say "C4: what nats reply printed"
cat "$OUT/c4-reply.log"
say "C4: how each of the eight requests ended"
for i in 1 2 3 4 5 6 7 8; do
  printf "req %s: " "$i"
  if grep -q 'Received with rtt' "$OUT/c4-req-$i.log"; then echo "answered — $(grep -o 'rtt [0-9.a-zµ]*' "$OUT/c4-req-$i.log")"
  elif grep -q 'No responders' "$OUT/c4-req-$i.log"; then echo "no responders"
  else echo "nothing printed (timed out): $(tail -1 "$OUT/c4-req-$i.log" | tr -d '\r')"; fi
done
echo "answered: $(grep -l 'Received with rtt' "$OUT"/c4-req-*.log 2>/dev/null | wc -l | tr -d ' ') of 8"

# ---------------------------------------------------------------- E8 / E9
hdr "E8 — a pull consumer fetching one at a time while its leader's node stops"
nats --server "$S1" stream rm LIFE -f > /dev/null 2>&1 || true
nats --server "$S1" stream add LIFE --subjects 'life.>' --storage file --replicas 3 --defaults > /dev/null
nats --server "$S1" consumer add LIFE WORKER --pull --defaults > /dev/null
nats --server "$S1" pub 'life.a' 'm {{Count}}' --count 500 > /dev/null
CLEADER=$(nats --server "$S1" consumer info LIFE WORKER --json | python3 -c 'import json,sys; print(json.load(sys.stdin)["cluster"]["leader"])')
SLEADER=$(nats --server "$S1" stream info LIFE --json | python3 -c 'import json,sys; print(json.load(sys.stdin)["cluster"]["leader"])')
echo "stream leader $SLEADER, consumer leader $CLEADER"
K="${CLEADER#n}"
rm -f "$OUT/e8-loop.log"
( for i in $(seq 1 120); do
    S=$(date +%s.%N)
    OUTL=$(nats --server "$S1,$S2,$S3" consumer next LIFE WORKER --count 1 --timeout 5s 2>&1)
    RC=$?
    E=$(date +%s.%N)
    echo "iter $i rc=$RC dt=$(python3 -c "print('%.3f' % ($E-$S))") $(echo "$OUTL" | grep -o 'cons seq: [0-9]*' | head -1)$(echo "$OUTL" | grep -oiE 'error.*|timeout.*|no responders.*' | head -1)"
    sleep 0.05
  done ) > "$OUT/e8-loop.log" 2>&1 &
LOOP=$!
sleep 4
echo "stopping $CLEADER (node $K) at $(date -u +%H:%M:%S.%N | cut -c1-12)"
bash "$LAB" stop "$K"
wait $LOOP
say "E8: the iterations around the stop"
grep -n 'rc=' "$OUT/e8-loop.log" | awk -F'rc=' '{split($2,a," "); if (a[1] != "0") print}' | head -10
echo "iterations with rc != 0: $(awk -F'rc=' '{split($2,a," "); if (a[1] != "0") c++} END {print c+0}' "$OUT/e8-loop.log") of $(wc -l < "$OUT/e8-loop.log" | tr -d ' ')"
say "E8: the five slowest iterations"
sort -t= -k3 -rn "$OUT/e8-loop.log" 2>/dev/null | head -1 >/dev/null
python3 - "$OUT/e8-loop.log" <<'PY'
import re,sys
rows=[]
for l in open(sys.argv[1]):
    m=re.search(r'iter (\d+) rc=(-?\d+) dt=([0-9.]+)(.*)', l)
    if m: rows.append((float(m.group(3)), int(m.group(1)), int(m.group(2)), m.group(4).strip()))
rows.sort(reverse=True)
for dt,i,rc,rest in rows[:5]: print("  iter %d rc=%d dt=%.3f %s" % (i,rc,dt,rest))
print("  total fetched: %d" % sum(1 for r in rows if 'cons seq' in r[3]))
PY
say "E8: consumer state now"
nats --server "$S2,$S3" consumer info LIFE WORKER --json | python3 -c 'import json,sys; d=json.load(sys.stdin); print("leader", d.get("cluster",{}).get("leader"), "delivered", d["delivered"]["consumer_seq"], "ack_floor", d["ack_floor"]["consumer_seq"], "ack_pending", d["num_ack_pending"], "redelivered", d["num_redelivered"])'
bash "$LAB" start "$K" | tail -1; sleep 3

hdr "E9 — messages held un-acked when the consumer leader's node stops"
say "E9: fetch 10 with --no-ack, stop the consumer leader, wait past ack_wait (30 s), fetch again"
CLEADER=$(nats --server "$S1" consumer info LIFE WORKER --json | python3 -c 'import json,sys; print(json.load(sys.stdin)["cluster"]["leader"])')
K="${CLEADER#n}"; echo "consumer leader $CLEADER"
nats --server "$S1,$S2,$S3" consumer next LIFE WORKER --count 10 --no-ack --timeout 10s > "$OUT/e9-first.log" 2>&1
echo "fetched un-acked: $(grep -c 'cons seq:' "$OUT/e9-first.log")"
nats --server "$S1,$S2,$S3" consumer info LIFE WORKER --json | python3 -c 'import json,sys; d=json.load(sys.stdin); print("before the stop: ack_pending", d["num_ack_pending"], "delivered", d["delivered"]["consumer_seq"], "ack_floor", d["ack_floor"]["consumer_seq"])'
echo "stopping $CLEADER at $(date -u +%H:%M:%S)"
bash "$LAB" stop "$K"
sleep 35
nats --server "$S1,$S2,$S3" consumer info LIFE WORKER --json | python3 -c 'import json,sys; d=json.load(sys.stdin); print("35 s after the stop: leader", d.get("cluster",{}).get("leader"), "ack_pending", d["num_ack_pending"], "delivered", d["delivered"]["consumer_seq"], "ack_floor", d["ack_floor"]["consumer_seq"], "redelivered", d["num_redelivered"])'
nats --server "$S1,$S2,$S3" consumer next LIFE WORKER --count 12 --timeout 10s > "$OUT/e9-second.log" 2>&1
say "E9: what came back — the tries counter says whether these are redeliveries"
grep -o 'tries: [0-9]* / cons seq: [0-9]* / str seq: [0-9]*' "$OUT/e9-second.log" | head -14
bash "$LAB" start "$K" | tail -1; sleep 3; bash "$LAB" status

hdr done
