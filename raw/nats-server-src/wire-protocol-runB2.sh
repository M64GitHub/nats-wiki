#!/bin/bash
# runB2.sh — the +OK stream and echo, with well-formed PUB frames. nats-server v2.14.6.
set -u
D=$(cd "$(dirname "$0")" && pwd); cd "$D"
nats-server -c base.conf >b2-server.log 2>&1 &
S=$!; sleep 0.7
R() { python3 wire-raw.py --port 14222 --wait "$1" --label "$2" "${@:3}"; echo; }
R 0.6 "B13 · CONNECT {} — the default is verbose, so every op is acknowledged" --send 'CONNECT {}' --send 'SUB foo 1' --send 'PUBLINE foo hello' --send 'UNSUB 1' --send 'PING'
R 0.6 "B14 · CONNECT {\"verbose\":false} — the silent default every client sends" --send 'CONNECT {"verbose":false}' --send 'SUB foo 1' --send 'PUBLINE foo hello' --send 'PING'
R 0.6 "B15 · echo defaults to true — the publisher gets its own message" --send 'CONNECT {"verbose":false}' --send 'SUB foo 1' --send 'PUBLINE foo hi' --send 'PING'
R 0.6 "B16 · echo:false — the publisher does not"                         --send 'CONNECT {"verbose":false,"echo":false}' --send 'SUB foo 1' --send 'PUBLINE foo hi' --send 'PING'
R 0.6 "B17 · lowercase ops"                                               --send 'connect {"verbose":false}' --send 'sub foo 1' --send 'PUBLINE foo hi' --send 'ping'
R 0.6 "B18 · pedantic defaults to true — SUB to a bad subject"            --send 'CONNECT {"verbose":false}' --send 'SUB foo. 1' --send 'PING'
R 0.6 "B19 · HPUB and the headers a subscriber gets back"                 --send 'CONNECT {"verbose":false,"headers":true}' --send 'SUB foo 1' --send 'RAW HPUB foo 22 33
NATS/1.0
Bar: Baz

Hello NATS!
' --send 'PING'
R 0.6 "B20 · UNSUB 1 5 — auto-unsubscribe after 5"                        --send 'CONNECT {"verbose":false}' --send 'SUB foo 1' --send 'UNSUB 1 2' --send 'PUBLINE foo a' --send 'PUBLINE foo b' --send 'PUBLINE foo c' --send 'PING'
kill $S 2>/dev/null; wait $S 2>/dev/null
