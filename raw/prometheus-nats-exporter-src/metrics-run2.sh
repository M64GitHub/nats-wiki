#!/bin/bash
# metrics-run2.sh — supplement to metrics-run.sh, same lab and shape, run right after it.
# (H1) acknowledge one message so the consumer has an ack time, then scrape node n2 — the leader
# of the R3 stream and consumer and the only holder of the R1 mirror and sourcing stream — and n1
# again; (H2) connz_detailed with one live client subscribed.
set -u
S=${S:-nats://127.0.0.1:4291}
OUT=${OUT:-.}
EXP=${EXP:-$HOME/go/bin/prometheus-nats-exporter}
n() { echo; echo "\$ nats $*"; nats --server "$S" "$@"; }
scrape() { local name=$1 port=$2 i
  for i in $(seq 1 50); do curl -s -o /dev/null "http://127.0.0.1:$port/metrics" && break; sleep 0.2; done
  curl -s -w '\n[http %{http_code}]\n' "http://127.0.0.1:$port/metrics" > "$OUT/scrape-$name.txt"
  echo "scrape-$name.txt: $(grep -c '^# HELP' "$OUT/scrape-$name.txt") HELP lines, $(grep -cvE '^#|^\[|^$' "$OUT/scrape-$name.txt") samples, $(tail -1 "$OUT/scrape-$name.txt")"; }
run_exporter() { local name=$1 mon=$2; shift 2
  echo; echo "\$ prometheus-nats-exporter $* $mon"
  "$EXP" "$@" "$mon" > "$OUT/exporter-$name.log" 2>&1 &
  local pid=$!; scrape "$name" 7777; kill $pid 2>/dev/null; wait $pid 2>/dev/null; sed -n '1,4p' "$OUT/exporter-$name.log"; }
echo "== H1: one ack, then n2 and n1"
n consumer next ORDERS shipping --count 1 --ack
n consumer info ORDERS shipping | sed -n '/^State/,$p'
run_exporter H1-n2 http://127.0.0.1:8292 -varz -jsz=all -port 7777
run_exporter H1-n1 http://127.0.0.1:8291 -varz -jsz=all -port 7777
echo; echo "== H2: connz_detailed with a live subscriber on n1"
nats --server "$S" sub 'orders.>' > "$OUT/h2-sub.log" 2>&1 &
SUBPID=$!; sleep 1
run_exporter H2-connz-detailed http://127.0.0.1:8291 -connz_detailed -port 7777
kill $SUBPID 2>/dev/null; wait $SUBPID 2>/dev/null
echo "== done"
