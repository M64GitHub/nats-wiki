#!/bin/bash
# request-reply-run3.sh — the third pass (same binary, nats-server v2.14.6, nats CLI 0.4.0, 2026-09-03): run H,
# a queue group with members on both sides of a leafnode — a standalone hub (port 14222, leafnode listener
# 17422) and a standalone leaf (port 14223) dialling it — publishing from each side.
set -u
cd "$(dirname "$0")"
HUB=nats://127.0.0.1:14222; LEAF=nats://127.0.0.1:14223
cat > hub.conf <<CONF
port: 14222
http: 18222
server_name: hub
leafnodes { port: 17422 }
CONF
cat > leaf.conf <<CONF
port: 14223
http: 18223
server_name: leaf
leafnodes { remotes: [ { url: nats-leaf://127.0.0.1:17422 } ] }
CONF
trap 'kill $(jobs -p) 2>/dev/null' EXIT
echo "### versions"; nats-server --version; nats --version
nats-server -c hub.conf > h-hub.log 2>&1 & sleep 0.7
nats-server -c leaf.conf > h-leaf.log 2>&1 & sleep 1.2
echo "--- the two logs (the leafnode connection):"; grep -iE 'leafnode' h-leaf.log | head -n 3; grep -iE 'leafnode' h-hub.log | head -n 3
run() { # $1 label, $2 publisher url, then "url:name" members
  local label=$1 pub=$2; shift 2; local pids=() names=()
  echo "--- $label"
  for m in "$@"; do local url=${m%%|*}; local name=${m#*|}; nats sub --server "$url" orders.created --queue workers > "h-$name.log" 2>&1 & pids+=($!); names+=("$name"); done
  sleep 1.5
  nats pub --server "$pub" orders.created x --count 200 > /dev/null; sleep 1.0
  local out=""; for n in "${names[@]}"; do out="$out$n $(grep -c Received "h-$n.log") · "; done; echo "${out% · }"
  kill "${pids[@]}" 2>/dev/null; sleep 0.8
}
run "H1: one member on the hub, one on the leaf; 200 publishes on the hub" $HUB "$HUB|hub-a" "$LEAF|leaf-a"
run "H2: the same members; 200 publishes on the leaf" $LEAF "$HUB|hub-b" "$LEAF|leaf-b"
run "H3: members only on the leaf (two); 200 publishes on the hub" $HUB "$LEAF|leaf-c1" "$LEAF|leaf-c2"
run "H4: two on the hub, one on the leaf; 200 publishes on the leaf" $LEAF "$HUB|hub-d1" "$HUB|hub-d2" "$LEAF|leaf-d"
run "H5: two on the hub, two on the leaf; 200 publishes on the hub" $HUB "$HUB|hub-e1" "$HUB|hub-e2" "$LEAF|leaf-e1" "$LEAF|leaf-e2"
echo "--- hub log lines (ERR/WRN):"; grep -E '\[ERR\]|\[WRN\]' h-hub.log; echo "--- leaf log lines (ERR/WRN):"; grep -E '\[ERR\]|\[WRN\]' h-leaf.log
kill $(jobs -p) 2>/dev/null
echo; echo "### done"
