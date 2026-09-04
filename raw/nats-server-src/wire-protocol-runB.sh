#!/bin/bash
# runB.sh — what a CONNECT must actually carry, and what +OK looks like. nats-server v2.14.6.
set -u
D=$(cd "$(dirname "$0")" && pwd); cd "$D"
nats-server -c base.conf >b-server.log 2>&1 &
S=$!; sleep 0.7
R() { python3 wire-raw.py --port 14222 --wait "$1" --label "$2" "${@:3}"; echo; }

R 0.6 "B1 · no CONNECT at all, just PING"                       --send 'PING'
R 0.6 "B2 · CONNECT {} then PING (every 'Required: true' field omitted)" --send 'CONNECT {}' --send 'PING'
R 0.6 "B3 · CONNECT {} then SUB/PUB — does traffic flow"        --send 'CONNECT {}' --send 'SUB foo 1' --send 'PUB foo 5' --send 'RAW hello' --send 'RAW 
' --send 'PING'
R 0.6 "B4 · CONNECT {\"verbose\":true} — the +OK per protocol message" --send 'CONNECT {"verbose":true}' --send 'SUB foo 1' --send 'PUB foo 0' --send 'RAW 
' --send 'PING'
R 0.6 "B5 · CONNECT {\"protocol\":2} — one above ClientProtoInfo" --send 'CONNECT {"protocol":2}' --send 'PING'
R 0.6 "B6 · CONNECT {\"protocol\":-1}"                            --send 'CONNECT {"protocol":-1}' --send 'PING'
R 0.6 "B7 · CONNECT {\"account\":\"APP\"} — the retired sandbox field" --send 'CONNECT {"account":"APP"}' --send 'PING'
R 0.6 "B8 · CONNECT {\"no_responders\":true} without headers"     --send 'CONNECT {"no_responders":true,"headers":false}' --send 'PING'
R 0.6 "B9 · CONNECT with a broken JSON body"                      --send 'CONNECT {oops}' --send 'PING'
R 0.6 "B10 · lowercase ops — connect/sub/pub/ping"                --send 'connect {}' --send 'sub foo 1' --send 'pub foo 0' --send 'RAW 
' --send 'ping'
R 0.6 "B11 · CONNECT {\"echo\":false} then publish to own sub"    --send 'CONNECT {"echo":false}' --send 'SUB foo 1' --send 'PUB foo 2' --send 'RAW hi' --send 'RAW 
' --send 'PING'
R 0.6 "B12 · a second CONNECT on a live connection"               --send 'CONNECT {}' --send 'SUB foo 1' --send 'CONNECT {"verbose":true}' --send 'PING'
kill $S 2>/dev/null; wait $S 2>/dev/null
