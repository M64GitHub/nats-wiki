#!/usr/bin/env bash
# Run C -- the two sides of TLS handshake_first, and what each mismatch prints.
#
#   C1  a --tlsfirst client against a server that still sends the plaintext INFO
#   C2  a plain client against handshake_first: true
#   C3  a plain client against handshake_first: "auto"   (the 50 ms fallback)
#   C4  a plain client against handshake_first: "300ms"  (a named fallback)
#   C5  --tlsfirst against each of the three, for the matrix
#   C6  openssl s_client against plain TLS and against handshake_first
#
# nats-server v2.14.6, nats CLI 0.4.0. Every timing is `time` around one
# `nats pub`, so the fallback delay is visible rather than inferred.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
BIN=${BIN:-nats-server}
say(){ printf '\n===== %s =====\n' "$*"; }
cd "$HERE" || exit 1
start(){ "$BIN" -c "$HERE/$1" -l "$HERE/$2" -DV & SRV=$!
  for i in $(seq 1 60); do curl -sf http://127.0.0.1:8222/healthz >/dev/null && break; sleep 0.1; done
  if ! curl -sf http://127.0.0.1:8222/healthz >/dev/null; then echo "SERVER FAILED TO START ($1):"; tail -3 "$HERE/$2"; fi; }
stop(){ kill "$SRV" 2>/dev/null; wait "$SRV" 2>/dev/null; sleep 0.3; }
PAY='{"order_id":"ord_8w2k","customer":"acme-co","total_cents":4200,"ts":"2026-05-22T10:14:22Z"}'

pub(){ # $1 label, rest: extra nats flags
  local label=$1; shift
  printf -- '--- %s\n' "$label"
  local t0 t1
  t0=$(python3 -c 'import time;print(time.time())')
  nats pub orders.created "$PAY" -s tls://localhost:4222 --tlsca "$HERE/tls/ca.pem" \
      --connection-name order-svc --timeout 5s "$@" 2>&1 | tail -3
  t1=$(python3 -c 'import time;print(time.time())')
  python3 -c "print('    elapsed %.3f s' % ($t1-$t0))"
}

for scene in plain first auto d300; do
  say "server: tls-$scene.conf"
  start tls-$scene.conf c-$scene-server.log
  grep -iE 'handshake|\[WRN\]' "$HERE/c-$scene-server.log" | head -3
  pub "plain client (default handshake: expects the INFO first)"
  pub "--tlsfirst client" --tlsfirst
  stop
done

say "C6 -- openssl s_client, the diagnostic side effect"
for scene in plain first auto; do
  start tls-$scene.conf c6-$scene-server.log
  printf -- '--- s_client against handshake_first=%s\n' "$scene"
  echo | openssl s_client -connect 127.0.0.1:4222 -CAfile "$HERE/tls/ca.pem" -verify_return_error 2>&1 \
    | grep -iE 'verify return code|wrong version|Verification|CONNECTED|error' | head -4
  stop
done
say "done"
