#!/bin/bash
# core-delivery-run.sh — nats-server v2.14.6, nats CLI 0.4.0, macOS, 2026-09-03.
# Runs A–G of phase F step 1 (core NATS delivery, subjects and account-level mapping) on one standalone
# server — port 14222, monitoring 18222, configs written beside this script, one server per scene — and,
# for run D's system-account half, on the three-node lab of tools/lab/cluster.sh (n1, 4291, user sys).
# core-delivery-raw.py beside this file is the raw protocol writer (CONNECT + verbatim lines, prints what
# comes back). `nc` is used once, for the INFO line, exactly as the docs do.
set -u
cd "$(dirname "$0")"
PORT=14222; MON=18222
S="nats://127.0.0.1:$PORT"
LAB="nats://sys:sys@127.0.0.1:4291"
RAW()   { python3 core-delivery-raw.py --port $PORT "$@"; }
start() { nats-server -c "$1" -P server.pid > "$2" 2>&1 & sleep 0.7; }
stop()  { kill "$(cat server.pid)" 2>/dev/null; sleep 0.4; }
TAP=""
tap()   { local log=$1; shift; nats sub --server $S "$@" > "$log" 2>&1 & TAP=$!; sleep 0.5; }
untap() { sleep 0.4; kill $TAP 2>/dev/null; sleep 0.2; }
trap 'kill $(cat server.pid 2>/dev/null) 2>/dev/null; [ -n "$TAP" ] && kill $TAP 2>/dev/null' EXIT

echo "### versions"; nats-server --version; nats --version; python3 --version

cat > base.conf <<CONF
port: $PORT
http: $MON
server_name: corelab
CONF
cat > ldm.conf <<CONF
port: $PORT
http: $MON
server_name: corelab
lame_duck_grace_period: 1s
lame_duck_duration: 30s
CONF

# F8 — added after the first full run (2026-09-03, same binary): a *wildcard* source listed as its own
# destination, the "chaos testing trick" of the server's example config quoted in gh#5172; the docs say
# the loss trick "only works for a literal source". Run on its own with: bash core-delivery-run.sh f8
f8() {
  echo; echo "### F8 — a wildcard source listed as its own destination at weight 50"
  cat > map-loss-wc.conf <<CONF
port: $PORT
http: $MON
server_name: corelab
mappings {
  "orders.loss.>": [ { destination: "orders.loss.>", weight: 50 } ]
}
CONF
  nats-server -t -c map-loss-wc.conf; echo "exit (-t): $?"
  start map-loss-wc.conf f8.log
  tap f8-tap.log 'orders.>' --subjects-only
  nats pub --server $S orders.loss.a x --count 200 > /dev/null; sleep 0.5; untap
  echo "received: $(grep -c Received f8-tap.log) of 200 on orders.loss.a"
  stop
}
if [ "${1:-}" = f8 ]; then f8; rm -f server.pid; exit 0; fi

echo; echo "### A — the INFO line, a whitespace subject over the raw protocol, and the CLI's own check"
start base.conf a.log
echo "--- A1: nc prints the INFO line the moment it connects"
nc -w 1 127.0.0.1 $PORT </dev/null; echo
echo "--- A2: raw 'PUB orders.us created 0' (a space inside the subject) with a nats sub '>' tap"
tap a2-tap.log '>'
RAW --send 'PUB orders.us created 0' --send '' --send 'PING' --wait 1
untap; echo "the tap saw:"; cat a2-tap.log
echo "--- A3: nats pub with a space in the subject"
nats pub --server $S "orders.us created" x; echo "exit: $?"
echo "--- A4: nats sub with a space in the subject"
nats sub --server $S "orders.us created" --wait 1s; echo "exit: $?"
echo "--- A5: CONNECT asking for no_responders without headers"
RAW --connect '{"no_responders":true,"headers":false}' --send 'PING' --wait 1
stop

echo; echo "### B — max_payload: the client's check, the server's on a raw PUB, and headers counted in an HPUB"
start base.conf b.log
echo "--- B1: a 2 MB nats pub"
head -c 2000000 /dev/zero | tr '\0' x | nats pub --server $S orders.created --force-stdin; echo "exit: $?"
echo "--- B2: raw PUB of 1048577 bytes (max_payload + 1)"
RAW --send 'PUBBIG orders.created 1048577' --send 'PING' --wait 1
echo "--- B3: raw PUB of 1048576 bytes (exactly max_payload), with an orders.> tap"
tap b3-tap.log 'orders.>' --subjects-only
RAW --send 'PUBBIG orders.created 1048576' --send 'PING' --wait 1
untap; echo "the tap saw:"; cat b3-tap.log
echo "--- B4: raw HPUB, 600000 header bytes + 500000 body bytes = 1100000 total"
RAW --send 'HPUBBIG orders.created 600000 500000' --send 'PING' --wait 1
echo "--- B5: raw HPUB, 600000 header bytes + 400000 body bytes = 1000000 total, with a --headers-only tap"
tap b5-tap.log 'orders.>' --headers-only
RAW --send 'HPUBBIG orders.created 600000 400000' --send 'PING' --wait 1
untap; echo "the tap saw (first 120 bytes):"; head -c 120 b5-tap.log; echo
echo "--- server log lines (ERR/WRN) for B"
grep -E '\[ERR\]|\[WRN\]' b.log
stop
echo "--- B6: nats pub -H against a server with no_header_support: true"
cat > nohdr.conf <<CONF
port: $PORT
http: $MON
server_name: corelab
no_header_support: true
CONF
start nohdr.conf b6.log
nc -w 1 127.0.0.1 $PORT </dev/null; echo
nats pub --server $S orders.created x -H 'Content-Type:application/json'; echo "exit: $?"
echo "--- B7: CONNECT with headers:true and no_responders:true against the same server"
RAW --connect '{"no_responders":true,"headers":true}' --send 'PING' --wait 1
stop

echo; echo "### C — subscribe- and publish-side wildcard checks, pedantic mode, max_subscription_tokens"
start base.conf c.log
echo "--- C1: raw 'SUB orders.>.created 1', then PING"
RAW --send 'SUB orders.>.created 1' --send 'PING' --wait 1
echo "--- C2: raw 'PUB orders.*.created 0' from a default (non-pedantic) CONNECT; taps on orders.>, orders.*.created, orders.us.created"
tap c2-all.log 'orders.>'
nats sub --server $S 'orders.*.created' > c2-star.log 2>&1 & T2=$!
nats sub --server $S 'orders.us.created' > c2-us.log 2>&1 & T3=$!; sleep 0.5
RAW --send 'PUB orders.*.created 0' --send '' --send 'PING' --wait 1
untap; kill $T2 $T3 2>/dev/null; sleep 0.2
echo "orders.> tap:"; cat c2-all.log; echo "orders.*.created tap:"; cat c2-star.log; echo "orders.us.created tap:"; cat c2-us.log
echo "--- C3: the same PUB from a pedantic CONNECT, orders.> tap"
tap c3-all.log 'orders.>'
RAW --connect '{"pedantic":true}' --send 'PUB orders.*.created 0' --send '' --send 'PING' --wait 1
untap; echo "orders.> tap:"; cat c3-all.log
echo "--- C4: raw SUB with an empty token and with a tab, then PING"
RAW --send 'SUB orders..created 1' --send 'PING' --wait 1
stop
echo "--- C5: max_subscription_tokens: 3 — SUB with four tokens, SUB with three, PUB with four"
cat > tok.conf <<CONF
port: $PORT
http: $MON
server_name: corelab
max_subscription_tokens: 3
CONF
start tok.conf c5.log
tap c5-tap.log 'a.>'
RAW --send 'SUB a.b.c.d 1' --send 'SUB a.b.c 2' --send 'PUB a.b.c.d 0' --send '' --send 'PING' --wait 1
untap; echo "a.> tap:"; cat c5-tap.log
echo "server log:"; grep -E '\[ERR\]|\[WRN\]' c5.log
echo "--- C6: reload with max_subscription_tokens changed 3 -> 4"
sed -i '' 's/max_subscription_tokens: 3/max_subscription_tokens: 4/' tok.conf
nats-server --signal reload="$(cat server.pid)"; echo "signal exit: $?"; sleep 0.6; tail -n 2 c5.log
RAW --send 'SUB a.b.c.d 1' --send 'PING' --wait 1
stop
echo "--- C7: max_subscription_tokens: 0 and 256 through nats-server -t"
for v in 0 256; do sed "s/max_subscription_tokens: 4/max_subscription_tokens: $v/" tok.conf > tok$v.conf; nats-server -t -c tok$v.conf; echo "exit: $?"; done

echo; echo "### D — /subsz test=, and the two nats server request commands on a plain server and on the lab"
start base.conf d.log
tap d-tap.log 'orders.>'
nats sub --server $S orders.created --queue packers > d-q.log 2>&1 & TQ=$!; sleep 0.5
echo "--- D1: /subsz?subs=1&acc=\$G&test=orders.us.created with an orders.> subscriber and a queue subscriber on orders.created"
curl -s "http://127.0.0.1:$MON/subsz?subs=1&acc=\$G&test=orders.us.created" | python3 -m json.tool
echo "--- D2: /subsz?subs=1&acc=\$G — every subscription in \$G"
curl -s "http://127.0.0.1:$MON/subsz?subs=1&acc=\$G" | python3 -m json.tool
echo "--- D3: /subsz?subs=1 with no acc= — the count across accounts"
curl -s "http://127.0.0.1:$MON/subsz?subs=1" | python3 -c 'import json,sys; d=json.load(sys.stdin); print("num_subscriptions:", d["num_subscriptions"], "total:", d["total"]); print(sorted(set((s["account"], s["subject"].split(".")[0]) for s in d["subscriptions_list"])))'
untap; kill $TQ 2>/dev/null; sleep 0.3
echo "--- D4: the test= query again with no subscriber"
curl -s "http://127.0.0.1:$MON/subsz?subs=1&acc=\$G&test=orders.us.created" | python3 -m json.tool
echo "--- D5: nats server request subscriptions / connections on the plain server (no system-account user)"
nats server request subscriptions --server $S 2>&1 | head -n 5; echo "exit: ${PIPESTATUS[0]}"
nats server request connections --server $S 2>&1 | head -n 40; echo "exit: ${PIPESTATUS[0]}"
stop
echo "--- D6: the same two on the lab (tools/lab/cluster.sh up 3, user sys)"
bash ../../../../tools/lab/cluster.sh status | head -n 4
nats server request subscriptions --server $LAB 2>&1 | head -n 30; echo "exit: ${PIPESTATUS[0]}"
nats server request connections --server $LAB 2>&1 | head -n 30; echo "exit: ${PIPESTATUS[0]}"

echo; echo "### E — nats trace with no subscriber, with orders.>, and with --deliver"
start base.conf e.log
echo "--- E1: no subscriber"; nats trace --server $S orders.us.created; echo "exit: $?"
tap e-tap.log 'orders.>'
echo "--- E2: with an orders.> subscriber, no --deliver"; nats trace --server $S orders.us.created; echo "exit: $?"
echo "--- E3: with --deliver"; nats trace --server $S orders.us.created --deliver; echo "exit: $?"
untap; echo "the subscriber saw:"; cat e-tap.log
stop

echo; echo "### F — account-level mappings: dry runs, weights, the remainder, partition, reload"
echo "--- F1: nats server mappings dry runs (the docs' examples; the three order ids)"
nats server mappings "orders.placed" "orders.created" orders.placed
nats server mappings "orders.legacy.*" "orders.{{wildcard(1)}}.created" orders.legacy.us
for id in ord_8w2k ord_7mn3 ord_2zr9; do nats server mappings "orders.created.*" "orders.created.{{partition(3, 1)}}.{{wildcard(1)}}" orders.created.$id; done
echo "--- F2: weight 10 to a canary; 200 publishes counted on an orders.> tap"
cat > map-canary.conf <<CONF
port: $PORT
http: $MON
server_name: corelab
mappings {
  orders.created: [ { destination: orders.created.canary, weight: 10 } ]
}
CONF
start map-canary.conf f2.log
tap f2-tap.log 'orders.>' --subjects-only
nats pub --server $S orders.created x --count 200 > /dev/null; sleep 0.5; untap
sort f2-tap.log | uniq -c
echo "--- F3: reload after changing the weight to 50; 200 more"
sed -i '' 's/weight: 10/weight: 50/' map-canary.conf
nats-server --signal reload="$(cat server.pid)"; echo "signal exit: $?"; sleep 0.6; tail -n 2 f2.log
tap f3-tap.log 'orders.>' --subjects-only
nats pub --server $S orders.created x --count 200 > /dev/null; sleep 0.5; untap
sort f3-tap.log | uniq -c
stop
echo "--- F4: weights 60 + 50 on one source"
cat > map-over.conf <<CONF
port: $PORT
http: $MON
server_name: corelab
mappings {
  orders.created: [ { destination: orders.created.a, weight: 60 }, { destination: orders.created.b, weight: 50 } ]
}
CONF
nats-server -t -c map-over.conf; echo "exit (-t): $?"
nats-server -c map-over.conf > f4.log 2>&1; echo "exit (start): $?"; cat f4.log
echo "--- F5: the source listed as its own destination at weight 90 — 200 publishes"
cat > map-loss.conf <<CONF
port: $PORT
http: $MON
server_name: corelab
mappings {
  orders.created: [ { destination: orders.created, weight: 90 } ]
}
CONF
start map-loss.conf f5.log
tap f5-tap.log 'orders.>' --subjects-only
nats pub --server $S orders.created x --count 200 > /dev/null; sleep 0.5; untap
echo "received: $(wc -l < f5-tap.log | tr -d ' ') of 200"; sort f5-tap.log | uniq -c
stop
echo "--- F6: partition(3, 1) live; the three ids, one of them twice; then a subscriber on the pre-map subject"
cat > map-part.conf <<CONF
port: $PORT
http: $MON
server_name: corelab
mappings {
  "orders.created.*": "orders.created.{{partition(3, 1)}}.{{wildcard(1)}}"
}
CONF
start map-part.conf f6.log
tap f6-tap.log 'orders.>' --subjects-only
for id in ord_8w2k ord_7mn3 ord_2zr9 ord_8w2k; do nats pub --server $S orders.created.$id x > /dev/null; done; sleep 0.3; untap; cat f6-tap.log
tap f7-tap.log 'orders.created.ord_8w2k'
nats pub --server $S orders.created.ord_8w2k x > /dev/null; sleep 0.3; untap
echo "the pre-map subscriber received $(grep -c Received f7-tap.log) message(s)"
stop

echo; echo "### G — the client through a server restart and through lame duck"
start ldm.conf g.log
nats sub --server $S orders.created --trace > g-sub.log 2>&1 & GS=$!; sleep 0.7
echo "--- G1: publish one; stop the server; publish two (no server); start it; publish three"
nats pub --server $S orders.created one > /dev/null; sleep 0.2
stop; echo "server stopped"
nats pub --server $S orders.created two; echo "exit: $?"
start ldm.conf g2.log; sleep 4
nats pub --server $S orders.created three > /dev/null; sleep 0.5
echo "the subscriber's log:"; cat g-sub.log
echo "--- G2: --signal ldm with the subscriber attached (lame_duck_grace_period 1s, lame_duck_duration 30s — the minimum the server accepts)"
nats-server --signal ldm="$(cat server.pid)"; echo "signal exit: $?"; sleep 35
echo "server log:"; grep -iE 'lame|shutdown|exiting|closing' g2.log
echo "the subscriber's log after ldm:"; cat g-sub.log
kill $GS 2>/dev/null
f8
rm -f server.pid
echo; echo "### done"
