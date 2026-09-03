#!/bin/bash
# request-reply-run4.sh — the fourth pass (same binary, nats-server v2.14.6, nats CLI 0.4.0, 2026-09-03): run H5 of
# request-reply-run3.sh repeated three times, and two more shapes (H6, H7), to pin the skew between the hub's own
# members that H5 showed (148 / 52) when a leaf also holds members of the group. Same hub.conf / leaf.conf.
set -u
cd "$(dirname "$0")"
HUB=nats://127.0.0.1:14222; LEAF=nats://127.0.0.1:14223
trap 'kill $(jobs -p) 2>/dev/null' EXIT
echo "### versions"; nats-server --version; nats --version
nats-server -c hub.conf > h4-hub.log 2>&1 & sleep 0.7
nats-server -c leaf.conf > h4-leaf.log 2>&1 & sleep 1.2
grep -c 'Leafnode connection created' h4-hub.log
run() { local label=$1 pub=$2; shift 2; local pids=() names=()
  echo "--- $label"
  for m in "$@"; do local url=${m%%|*}; local name=${m#*|}; nats sub --server "$url" orders.created --queue workers > "h4-$name.log" 2>&1 & pids+=($!); names+=("$name"); done
  sleep 1.5
  nats pub --server "$pub" orders.created x --count 400 > /dev/null; sleep 1.0
  local out=""; for n in "${names[@]}"; do out="$out$n $(grep -c Received "h4-$n.log") · "; done; echo "${out% · }"
  kill "${pids[@]}" 2>/dev/null; sleep 0.8
}
for i in 1 2 3; do run "H5.$i: two on the hub, two on the leaf; 400 publishes on the hub" $HUB "$HUB|hub-e1-$i" "$HUB|hub-e2-$i" "$LEAF|leaf-e1-$i" "$LEAF|leaf-e2-$i"; done
run "H6: two on the hub, one on the leaf; 400 publishes on the hub" $HUB "$HUB|hub-f1" "$HUB|hub-f2" "$LEAF|leaf-f"
run "H7: three on the hub, two on the leaf; 400 publishes on the hub" $HUB "$HUB|hub-g1" "$HUB|hub-g2" "$HUB|hub-g3" "$LEAF|leaf-g1" "$LEAF|leaf-g2"
run "H8: two on the hub, no leaf member; 400 publishes on the hub (the control)" $HUB "$HUB|hub-h1" "$HUB|hub-h2"
kill $(jobs -p) 2>/dev/null
echo; echo "### done"
