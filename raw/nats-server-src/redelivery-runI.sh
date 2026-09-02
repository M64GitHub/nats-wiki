#!/bin/bash
# redelivery-runI.sh — what a redelivery loop looks like from the outside, on the lab's standalone
# v2.14.6 started with NATS_LAB_FLAGS=-DV: the CLI's `tries:`, `nats consumer info`, the JSON
# counters, and what the server log contains at the default level and at trace level.
S=${S:-nats://127.0.0.1:4291}
LOG=${LOG:-${TMPDIR:-/tmp}/nats-lab/n1/n1.log}
n() { echo; echo "\$ nats $*"; nats --server "$S" "$@"; }
n stream add LOOP --subjects 'loop.>' --storage file --defaults
for i in 1 2 3; do n pub loop.job "job $i"; done
n consumer add LOOP worker --pull --ack explicit --wait 2s --max-deliver=-1 --max-pending 1000 --deliver all --filter 'loop.>' --defaults
echo; echo "### first pass — fetch three, ack nothing"
for i in 1 2 3; do n consumer next LOOP worker --no-ack --timeout 3s; done
n consumer info LOOP worker
echo; echo "### sleep 3 (ack_wait is 2s), then fetch again"; sleep 3
for i in 1 2 3; do n consumer next LOOP worker --no-ack --timeout 3s; done
n consumer info LOOP worker
echo; echo "\$ nats consumer info LOOP worker --json | jq ..."
nats --server "$S" consumer info LOOP worker --json | jq -c '{num_ack_pending, num_redelivered, num_pending, ack_floor, delivered}'
echo; echo "### the server log: lines mentioning LOOP or loop.job at INF/WRN/ERR level, then the trace"
echo "\$ grep -E '\[(INF|WRN|ERR)\]' n1.log | grep -c 'LOOP\|loop.job'"; grep -E '\[(INF|WRN|ERR)\]' "$LOG" | grep -c 'LOOP\|loop.job'
echo "\$ grep -E 'loop.job|JS.ACK.LOOP' n1.log | head -14"; grep -E 'loop.job|JS.ACK.LOOP' "$LOG" | head -14
echo; echo "### ack them"
for i in 1 2 3; do n consumer next LOOP worker --ack --timeout 3s; done
n consumer info LOOP worker
