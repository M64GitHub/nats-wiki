#!/usr/bin/env bash
# client-lifecycle-run.sh — runs A, B, C and E of raw/nats-server-src/client-lifecycle-observed-v2.14.6.md
#
# What a client sees while the cluster underneath it goes away. Each scene is run twice, once with
# the client that dies being the subscriber and once the publisher, because the two sides lose
# different things:
#   A  n1 stopped (SIGTERM) under a live subscriber (A1) and under a live publisher (A2)
#   B  n1 asked to enter lame duck instead, same two shapes (B1, B2)
#   C  `nats reply` drained with Ctrl-C while requests are in flight
#   E  a JetStream pull consumer whose consumer leader's node stops mid-fetch
# Run D — the stale link — is a standalone server on a shortened ping interval and lives in
# client-lifecycle-stale-run.sh.
#
# `set -m` is deliberate: without job control a non-interactive bash sets SIGINT to *ignore* for
# every background job, so the Ctrl-C in run C would never reach `nats reply`.
#
# Needs tools/lab/cluster.sh, nats-server v2.14.6 and nats 0.4.0 on PATH. Writes into $OUT.
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
gap() {  # gap <log> — first/last/count/missing of the `ord N` payloads a subscriber printed
  python3 - "$1" <<'PY'
import re,sys
seen=[int(m.group(1)) for m in (re.search(r'^ord (\d+)$', l) for l in open(sys.argv[1])) if m]
if not seen: print("no payloads parsed"); raise SystemExit
s=set(seen); missing=[n for n in range(seen[0], seen[-1]+1) if n not in s]
print("first %d, last %d, received %d, missing inside the range %d" % (seen[0], seen[-1], len(seen), len(missing)))
if missing: print("  missing %d..%d" % (missing[0], missing[-1]))
PY
}
traces() { grep -vE '^\[#|^ord |^$' "$1" | head -20; }

hdr versions
nats-server --version; echo "nats CLI: $(nats --version)"; echo "date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"

hdr "reset the lab (3 nodes, purged)"
bash "$LAB" down --purge >/dev/null 2>&1 || true
bash "$LAB" up 3 | tail -2
bash "$LAB" status

# ---------------------------------------------------------------- A
hdr "A — n1 stopped with SIGTERM"

say "A1: the SUBSCRIBER is pinned to n1; the publisher runs on n2. n1 stops 3 s into 1000 messages"
rm -f "$OUT"/a1-sub.log "$OUT"/a1-pub.log
nats sub 'orders.new' --server "$S1" --connection-name warehouse --trace > "$OUT/a1-sub.log" 2>&1 &
SUB=$!; sleep 1
nats pub 'orders.new' 'ord {{Count}}' --count 1000 --sleep 10ms --server "$S2" --connection-name order-svc > "$OUT/a1-pub.log" 2>&1 &
PUB=$!; sleep 3
echo "stopping n1 at $(date -u +%H:%M:%S)"; bash "$LAB" stop 1
wait $PUB; echo "publisher exit: $?"
sleep 3; kill -INT $SUB 2>/dev/null; sleep 1; kill -TERM $SUB 2>/dev/null; wait $SUB 2>/dev/null
echo "what the subscriber received:"; gap "$OUT/a1-sub.log"
say "A1: every line the subscriber printed that was not a message"
traces "$OUT/a1-sub.log"
say "A1: the publisher's last two lines"
tail -2 "$OUT/a1-pub.log"
say "A1: restart n1"
bash "$LAB" start 1 | tail -1; sleep 3

say "A2: the PUBLISHER is pinned to n1; the subscriber runs on n2. n1 stops 3 s in"
rm -f "$OUT"/a2-sub.log "$OUT"/a2-pub.log
nats sub 'orders.new' --server "$S2" --connection-name warehouse --trace > "$OUT/a2-sub.log" 2>&1 &
SUB=$!; sleep 1
nats pub 'orders.new' 'ord {{Count}}' --count 1000 --sleep 10ms --server "$S1" --connection-name order-svc --trace > "$OUT/a2-pub.log" 2>&1 &
PUB=$!; sleep 3
echo "stopping n1 at $(date -u +%H:%M:%S)"; bash "$LAB" stop 1
wait $PUB; echo "publisher exit: $?"
sleep 3; kill -INT $SUB 2>/dev/null; sleep 1; kill -TERM $SUB 2>/dev/null; wait $SUB 2>/dev/null
echo "what the subscriber received:"; gap "$OUT/a2-sub.log"
say "A2: the publisher's non-progress lines — did a one-URL client fail over"
traces "$OUT/a2-pub.log"
say "A2: restart n1"
bash "$LAB" start 1 | tail -1; sleep 3; bash "$LAB" status

# ---------------------------------------------------------------- B
hdr "B — n1 asked to enter lame duck instead of being stopped"

say "B1: the SUBSCRIBER is pinned to n1; publisher on n2; ldm 3 s in"
rm -f "$OUT"/b1-sub.log "$OUT"/b1-pub.log
nats sub 'orders.new' --server "$S1" --connection-name warehouse --trace > "$OUT/b1-sub.log" 2>&1 &
SUB=$!; sleep 1
nats pub 'orders.new' 'ord {{Count}}' --count 1000 --sleep 10ms --server "$S2" --connection-name order-svc > "$OUT/b1-pub.log" 2>&1 &
PUB=$!; sleep 3
PID1="$(cat "$LABDIR/n1/n1.pid")"
echo "n1 pid $PID1 — signalling ldm at $(date -u +%H:%M:%S)"
nats-server --signal ldm="$PID1"
wait $PUB; echo "publisher exit: $?"
sleep 3; kill -INT $SUB 2>/dev/null; sleep 1; kill -TERM $SUB 2>/dev/null; wait $SUB 2>/dev/null
echo "what the subscriber received:"; gap "$OUT/b1-sub.log"
say "B1: the subscriber's non-message lines"
traces "$OUT/b1-sub.log"
say "B1: n1's log around the lame-duck notice"
bash "$LAB" logs 1 -n 12 2>/dev/null || echo "(n1 gone)"
say "B1: is n1 still up?"
bash "$LAB" status

say "B2: restart the lab, then the PUBLISHER pinned to n1 and ldm 3 s in"
bash "$LAB" down >/dev/null 2>&1; bash "$LAB" up 3 | tail -1
rm -f "$OUT"/b2-sub.log "$OUT"/b2-pub.log
nats sub 'orders.new' --server "$S2" --connection-name warehouse --trace > "$OUT/b2-sub.log" 2>&1 &
SUB=$!; sleep 1
nats pub 'orders.new' 'ord {{Count}}' --count 1000 --sleep 10ms --server "$S1" --connection-name order-svc --trace > "$OUT/b2-pub.log" 2>&1 &
PUB=$!; sleep 3
PID1="$(cat "$LABDIR/n1/n1.pid")"
echo "n1 pid $PID1 — signalling ldm at $(date -u +%H:%M:%S)"
nats-server --signal ldm="$PID1"
wait $PUB; echo "publisher exit: $?"
sleep 3; kill -INT $SUB 2>/dev/null; sleep 1; kill -TERM $SUB 2>/dev/null; wait $SUB 2>/dev/null
echo "what the subscriber received:"; gap "$OUT/b2-sub.log"
say "B2: the publisher's non-progress lines"
traces "$OUT/b2-pub.log"
say "B2: rebuild the lab for the next runs"
bash "$LAB" down >/dev/null 2>&1; bash "$LAB" up 3 | tail -1; bash "$LAB" status

# ---------------------------------------------------------------- C
hdr "C — nats reply drained with Ctrl-C while requests are in flight"
say "C1: one responder sleeping up to 1 s per reply, 50 sequential requests, SIGINT 2 s in"
rm -f "$OUT"/c-reply.log "$OUT"/c-req.log
nats reply 'orders.check' 'ok {{Count}}' --sleep 1s --server "$S1" > "$OUT/c-reply.log" 2>&1 &
REP=$!; sleep 1
nats request 'orders.check' 'q' --count 50 --timeout 3s --server "$S1" > "$OUT/c-req.log" 2>&1 &
REQ=$!; sleep 2
echo "SIGINT to nats reply at $(date -u +%H:%M:%S.%N | cut -c1-12)"
kill -INT $REP
wait $REP 2>/dev/null; echo "nats reply exit: $?"
wait $REQ 2>/dev/null; echo "nats request exit: $?"
say "C2: everything nats reply printed"
cat "$OUT/c-reply.log"
say "C3: how the 50 requests ended"
echo "replies received: $(grep -c 'Received with rtt' "$OUT/c-req.log")"
echo "no-responders lines: $(grep -c 'No responders' "$OUT/c-req.log")"
tail -8 "$OUT/c-req.log"

# ---------------------------------------------------------------- E
hdr "E — a JetStream pull consumer while its leader's node stops"
say "E1: R3 stream and a durable pull consumer, 500 messages in"
nats --server "$S1" stream rm LIFE -f > /dev/null 2>&1 || true
nats --server "$S1" stream add LIFE --subjects 'life.>' --storage file --replicas 3 --defaults > /dev/null
nats --server "$S1" consumer add LIFE WORKER --pull --defaults > /dev/null
nats --server "$S1" pub 'life.a' 'm {{Count}}' --count 500 > /dev/null
nats --server "$S1" stream info LIFE --json | python3 -c 'import json,sys; d=json.load(sys.stdin); print("stream leader", d["cluster"]["leader"], "replicas", [p["name"] for p in d["cluster"]["replicas"]], "msgs", d["state"]["messages"])'
CLEADER=$(nats --server "$S1" consumer info LIFE WORKER --json | python3 -c 'import json,sys; print(json.load(sys.stdin)["cluster"]["leader"])')
echo "consumer leader: $CLEADER"

say "E2: a quiet fetch of 100 first — the baseline"
nats --server "$S1" consumer next LIFE WORKER --count 100 --timeout 10s > "$OUT/e-first.log" 2>&1
echo "first fetch: exit $?, messages $(grep -c 'cons seq:' "$OUT/e-first.log")"

say "E3: fetch 100 more, and stop the consumer leader's node half a second in"
nats --server "$S2,$S3,$S1" consumer next LIFE WORKER --count 100 --timeout 20s > "$OUT/e-second.log" 2>&1 &
FET=$!; sleep 0.5
K="${CLEADER#n}"
echo "stopping $CLEADER (node $K) at $(date -u +%H:%M:%S.%N | cut -c1-12)"
bash "$LAB" stop "$K"
wait $FET; echo "second fetch exit: $?"
echo "messages received: $(grep -c 'cons seq:' "$OUT/e-second.log")"
echo "acknowledged: $(grep -c 'Acknowledged message' "$OUT/e-second.log")"
say "E4: the last 12 lines of that fetch"
tail -12 "$OUT/e-second.log"
say "E5: consumer state after the move"
sleep 3
nats --server "$S2,$S3" consumer info LIFE WORKER --json 2>/dev/null | python3 -c 'import json,sys; d=json.load(sys.stdin); c=d.get("cluster",{}); print("leader", c.get("leader"), "delivered", d["delivered"]["consumer_seq"], "/", d["delivered"]["stream_seq"], "ack_floor", d["ack_floor"]["consumer_seq"], "/", d["ack_floor"]["stream_seq"], "pending", d["num_pending"], "ack_pending", d["num_ack_pending"], "redelivered", d["num_redelivered"])' || echo "(consumer info failed)"
say "E6: a third fetch — which sequences come back, and with what tries count"
nats --server "$S2,$S3" consumer next LIFE WORKER --count 5 --timeout 10s > "$OUT/e-third.log" 2>&1
echo "third fetch exit: $?"
grep -E 'cons seq:|rror' "$OUT/e-third.log" | head -8
say "E7: restart the stopped node"
bash "$LAB" start "$K" | tail -1; sleep 3; bash "$LAB" status

hdr done
