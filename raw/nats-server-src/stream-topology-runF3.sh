#!/bin/bash
# Run F3 — two things run F2 left open: is the push consumer's silence about *streams* or about
# *wildcards* (sublist.go:169-190 registers a deliver-subject notification only for a subscription
# whose subject is literally equal), and what the working "copy with a consumer" shape costs when a
# client does it (run F2's relay ate its own pulls: one connection cannot both pull and ack-window).
set -u
D=$(cd "$(dirname "$0")" && pwd)
REPO=/Users/m64/space/64/nats-wiki
cd "$D"
N="nats --server nats://127.0.0.1:4291 --timeout=60s"
HP=8291
LAB="${TMPDIR:-/tmp}"; LAB="${LAB%/}/nats-lab"
STORE="$LAB/n1/store"
lab() { bash "$REPO/tools/lab/cluster.sh" "$@"; }
tl()  { python3 - "$@" <<'PY'
import sys, time
print(f"### [{time.strftime('%H:%M:%S')}] " + " ".join(sys.argv[1:]))
PY
}

tl "versions"; nats-server --version; nats --version
pkill -f 'nats sub' 2>/dev/null
lab down --purge >/dev/null 2>&1
NATS_LAB_WAIT=300 lab up 1 | tail -1

tl "H1 · a push consumer with only a WILDCARD subscriber on its deliver subject"
$N stream add S --subjects 's.>' --storage file --retention limits --replicas 1 --defaults >/dev/null
python3 topolab.py fill 4291 's.%03d.evt' 1000 128 10
echo "--- subscriber: nats sub 'd.>' (a wildcard that covers d.evt) ---"
nats --server nats://127.0.0.1:4291 sub 'd.>' --count 3 > h1-wild.txt 2>&1 &
WPID=$!
sleep 1.5
python3 - <<'PY'
import json, sys, time
sys.path.insert(0, ".")
import topolab
c = topolab.Nats(4291, "h1")
cfg = {"stream_name": "S", "config": {"durable_name": "W", "ack_policy": "none",
        "deliver_policy": "all", "deliver_subject": "d.evt", "replay_policy": "instant"}}
m = c.request("$JS.API.CONSUMER.DURABLE.CREATE.S.W", json.dumps(cfg).encode(), timeout=60)
print("create:", "ok" if "error" not in json.loads(m[3]) else m[3][:200].decode())
time.sleep(3)
d = json.loads(c.request("$JS.API.CONSUMER.INFO.S.W", b"", timeout=60)[3])
print("with only a WILDCARD subscriber d.> : delivered", d["delivered"]["consumer_seq"],
      "num_pending", d["num_pending"])
c.close()
PY
echo "--- what the wildcard subscriber saw ---"
grep -c "Received on" h1-wild.txt || true
kill $WPID 2>/dev/null; wait $WPID 2>/dev/null

tl "H2 · now an EXACT subscriber on d.evt, same consumer"
nats --server nats://127.0.0.1:4291 sub 'd.evt' --count 3 > h2-exact.txt 2>&1 &
EPID=$!
sleep 2
python3 - <<'PY'
import json, sys
sys.path.insert(0, ".")
import topolab
c = topolab.Nats(4291, "h2")
d = json.loads(c.request("$JS.API.CONSUMER.INFO.S.W", b"", timeout=60)[3])
print("with an EXACT subscriber d.evt : delivered", d["delivered"]["consumer_seq"],
      "num_pending", d["num_pending"])
c.close()
PY
grep -c "Received on" h2-exact.txt || true
kill $EPID 2>/dev/null; wait $EPID 2>/dev/null

tl "H3 · the working relay: pull from S, publish into COPY, on two connections"
$N stream add COPY --subjects 'copy.>' --storage file --retention limits --replicas 1 --defaults >/dev/null
python3 - <<'PY'
import json, sys, time, os, queue
sys.path.insert(0, ".")
import topolab
pull = topolab.Nats(4291, "relay-pull")
push = topolab.Nats(4291, "relay-push")
cfg = {"stream_name": "S", "config": {"durable_name": "RELAY", "ack_policy": "none",
        "deliver_policy": "all", "replay_policy": "instant"}}
pull.request("$JS.API.CONSUMER.DURABLE.CREATE.S.RELAY", json.dumps(cfg).encode(), timeout=60)
inbox = "_INBOX.relay." + os.urandom(6).hex()
pull.sub(inbox)
f = topolab.Filler(push, window=500)
t0 = time.monotonic(); got = 0
while got < 1000 and time.monotonic() - t0 < 120:
    pull.pub("$JS.API.CONSUMER.MSG.NEXT.S.RELAY",
             json.dumps({"batch": 250, "expires": 5_000_000_000}).encode(), inbox)
    n = 0
    while n < 250:
        try:
            m = pull.q.get(timeout=3)
        except queue.Empty:
            break
        if m[2].startswith(b"NATS/1.0"):
            break
        f.send("copy." + m[0].split(".", 1)[1], m[3])
        got += 1; n += 1
f.finish()
dt = time.monotonic() - t0
print(f"relay: {got} messages pulled from S and republished into COPY in {dt:.2f}s "
      f"({got/dt:.0f} msg/s), {f.errs} publish errors")
d = json.loads(push.request("$JS.API.STREAM.INFO.COPY", b"", timeout=60)[3])["state"]
print("COPY:", d["messages"], "messages,", d["bytes"], "bytes, first_seq", d["first_seq"])
m = push.request("$JS.API.STREAM.MSG.GET.COPY", b'{"seq":1}', timeout=60)
msg = json.loads(m[3])["message"]
print("COPY seq 1:", msg["subject"], "hdrs", bool(msg.get("hdrs")))
d = json.loads(push.request("$JS.API.STREAM.INFO.S", b"", timeout=60)[3])["state"]
print("S:", d["messages"], "messages,", d["bytes"], "bytes")
pull.close(); push.close()
PY
du -sk "$STORE/jetstream/\$G/streams/"* | sed "s|$LAB|<lab>|"

tl "H4 · and the same 1000 messages copied by a mirror, for the price comparison"
$N stream add MIR2 --mirror S --storage file --replicas 1 --defaults >/dev/null 2>&1
python3 topolab.py lagwait 4291 MIR2 1000 60
du -sk "$STORE/jetstream/\$G/streams/"* | sed "s|$LAB|<lab>|"
python3 topolab.py conslist 4291 S

tl "done"
