#!/usr/bin/env bash
# client-lifecycle-run3.sh — run B3 of raw/nats-server-src/client-lifecycle-observed-v2.14.6.md,
# repeated after raw-watch.py was fixed (socket.makefile cannot be read from a socket with a
# timeout; the first attempt died at t=0.000 and left the server with no clients, which is why it
# shut down at once instead of waiting out the grace period).
#
# B3  the asynchronous INFO a client receives when its server enters lame duck: the `ldm` flag and
#     the `connect_urls` with the departing server removed, plus the 10 s the server waits before
#     it closes anything (DEFAULT_LAME_DUCK_GRACE_PERIOD).
# B4  the same with a second raw client on n2, to show the peers' INFO is not rewritten.
# B5  a client that has connected but never sent a PING: the server sends it no lame-duck INFO at
#     all, because sendAsyncInfoToClients skips every client without `firstPongSent`
#     (route.go:1026-1028). The first attempt at B3 hit this by accident.
set -uo pipefail
set -m
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../../../.." && pwd)"
LAB="$REPO/tools/lab/cluster.sh"
OUT="${OUT:-$HERE}"
LABDIR="${NATS_LAB_DIR:-${TMPDIR:-/tmp}/nats-lab}"; LABDIR="${LABDIR%/}"
say() { echo; echo "--- $*"; }
hdr() { echo; echo "### $*"; }
infos() {
  python3 - "$1" <<'PY'
import json,sys,re
for l in open(sys.argv[1]):
    m=re.search(r'<< INFO (\{.*\})\s*$', l)
    if not m: continue
    d=json.loads(m.group(1))
    print("%s server_name=%s ldm=%s client_id=%s connect_urls=%s" %
          (l.split()[0], d.get("server_name"), d.get("ldm"), d.get("client_id"), d.get("connect_urls")))
PY
}

hdr versions
nats-server --version; echo "date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
bash "$LAB" down --purge >/dev/null 2>&1 || true
bash "$LAB" up 3 | tail -1

hdr "B3 — the lame-duck INFO, and the grace period before anything is closed"
rm -f "$OUT"/b3-raw.log "$OUT"/b4-raw.log
python3 "$HERE/raw-watch.py" --port 4291 --wait 30 --sub 'orders.>' > "$OUT/b3-raw.log" 2>&1 &
RAW1=$!
python3 "$HERE/raw-watch.py" --port 4292 --wait 30 --sub 'orders.>' > "$OUT/b4-raw.log" 2>&1 &
RAW2=$!
python3 "$HERE/raw-watch.py" --port 4291 --wait 30 --sub 'orders.>' --no-ping > "$OUT/b5-raw.log" 2>&1 &
RAW3=$!
sleep 2
PID1="$(cat "$LABDIR/n1/n1.pid")"
echo "n1 pid $PID1 — signalling ldm at $(date -u +%H:%M:%S.%N | cut -c1-12)"
nats-server --signal ldm="$PID1"
wait $RAW1 2>/dev/null; wait $RAW2 2>/dev/null; wait $RAW3 2>/dev/null
say "B3: the client on n1 — every line, with seconds since its own CONNECT"
cat "$OUT/b3-raw.log"
say "B3: its INFO lines parsed"
infos "$OUT/b3-raw.log"
say "B4: the client on n2 (a peer, not the departing server) — its INFO lines"
infos "$OUT/b4-raw.log"
say "B5: the client on n1 that never sent a PING — what it saw"
cat "$OUT/b5-raw.log"

say "B3: n1's log from the lame-duck notice down"
sed -n '/lame duck/,$p' "$LABDIR/n1/n1.log" | head -8
say "B3: the two timestamps that matter"
grep -E 'Entering lame duck|Closing existing clients' "$LABDIR/n1/n1.log"
bash "$LAB" down >/dev/null 2>&1 || true
hdr done
