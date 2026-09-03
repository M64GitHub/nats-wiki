#!/bin/bash
# metrics-run.sh — prometheus-nats-exporter v0.20.2 and nats-surveyor v0.9.11 scraped once each
# against the lab (bash tools/lab/cluster.sh up 3, binary v2.14.6, node n1's monitoring port).
# Shape: one R3 file stream with 30 messages; a pull consumer holding 10 unacked messages that
# have each been delivered twice (fetched without ack, ack_wait expired, fetched again); an R1
# mirror and an R1 sourcing stream. Each exporter configuration is started, scraped with curl,
# and stopped; the scrapes are the metric list. OUT is where the scrapes and logs go.
set -u
S=${S:-nats://127.0.0.1:4291}
MON=${MON:-http://127.0.0.1:8291}
OUT=${OUT:-.}
EXP=${EXP:-$HOME/go/bin/prometheus-nats-exporter}
SUR=${SUR:-$HOME/go/bin/nats-surveyor}
n() { echo; echo "\$ nats $*"; nats --server "$S" "$@"; }

echo "== versions"
nats-server --version; nats --version
go version -m "$EXP" | grep -E '^\s+mod\s'
go version -m "$SUR" | grep -E '^\s+mod\s'

echo; echo "== shape"
n stream add ORDERS --subjects 'orders.>' --replicas 3 --storage file --defaults
n pub orders.new --count 30 'order {{Count}}'
n consumer add ORDERS shipping --pull --ack explicit --wait 3s --max-deliver=-1 --deliver all --filter 'orders.>' --defaults
n consumer next ORDERS shipping --count 10 --no-ack
sleep 4
n consumer next ORDERS shipping --count 10 --no-ack
n stream add ORDERS_MIRROR --mirror ORDERS --replicas 1 --storage file --defaults
n stream add ORDERS_AGG --source ORDERS --replicas 1 --storage file --defaults
sleep 2
n consumer info ORDERS shipping
n stream info ORDERS

echo; echo "== the endpoints the exporter reads, raw"
curl -s "$MON/varz" > "$OUT/varz-raw.json"; echo "varz-raw.json: $(wc -c < "$OUT/varz-raw.json") bytes"
curl -s "$MON/jsz?consumers=true&config=true&raft=true" > "$OUT/jsz-raw.json"; echo "jsz-raw.json: $(wc -c < "$OUT/jsz-raw.json") bytes"
curl -s "$MON/connz?auth=true" > "$OUT/connz-raw.json"; echo "connz-raw.json: $(wc -c < "$OUT/connz-raw.json") bytes"

scrape() { # name port
  local name=$1 port=$2 i
  for i in $(seq 1 50); do curl -s -o /dev/null "http://127.0.0.1:$port/metrics" && break; sleep 0.2; done
  curl -s -w '\n[http %{http_code}]\n' "http://127.0.0.1:$port/metrics" > "$OUT/scrape-$name.txt"
  echo "scrape-$name.txt: $(grep -c '^# HELP' "$OUT/scrape-$name.txt") HELP lines, $(grep -cvE '^#|^\[|^$' "$OUT/scrape-$name.txt") samples, $(tail -1 "$OUT/scrape-$name.txt")"
}
run_exporter() { # name flags...
  local name=$1; shift
  echo; echo "\$ prometheus-nats-exporter $* $MON"
  "$EXP" "$@" "$MON" > "$OUT/exporter-$name.log" 2>&1 &
  local pid=$!
  scrape "$name" 7777
  kill $pid 2>/dev/null; wait $pid 2>/dev/null
  sed -n '1,6p' "$OUT/exporter-$name.log"
}
ALL="-varz -connz -routez -subz -healthz -healthz_js_enabled_only -healthz_js_server_only -gatewayz -leafz -accountz -accstatz -jsz=all"
echo; echo "== exporter"
run_exporter A-default $ALL -port 7777
run_exporter B-prefix-nats -prefix nats $ALL -port 7777
run_exporter C-connz-detailed -connz_detailed -port 7777
run_exporter D-jsz-streams -jsz=streams -port 7777
run_exporter E-no-flags -port 7777
run_exporter F-jsz-only -jsz=all -port 7777
run_exporter G-server-name -use_internal_server_name -varz -port 7777

run_surveyor() { # name flags...
  local name=$1; shift
  echo; echo "\$ nats-surveyor -s $S --user sys --password sys -c 3 -p 7778 $*"
  "$SUR" -s "$S" --user sys --password sys -c 3 -p 7778 "$@" > "$OUT/surveyor-$name.log" 2>&1 &
  local pid=$!; sleep 3
  scrape "$name" 7778
  kill $pid 2>/dev/null; wait $pid 2>/dev/null
  sed -n '1,8p' "$OUT/surveyor-$name.log"
}
echo; echo "== surveyor"
run_surveyor S1-all --jsz all --accounts --raftz
run_surveyor S2-leaders-only --jsz all --accounts --raftz --jsz-leaders-only
run_surveyor S3-prefix --prefix x --jsz all
echo; echo "== done"
