#!/bin/bash
# Run F2 — shape (iii) again, after run F's push consumer delivered nothing into COPY. Two questions:
# does the push consumer deliver at all (a plain subscriber on the deliver subject), and does a
# second stream whose subject covers that deliver subject store what it sees?
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

tl "G1 · SRC2 with 1000 messages, COPY2 on copy2.>, and no subscriber anywhere"
$N stream add SRC2 --subjects 'src2.>' --storage file --retention limits --replicas 1 --defaults >/dev/null
python3 topolab.py fill 4291 'src2.%03d.evt' 1000 128 10
$N stream add COPY2 --subjects 'copy2.>' --storage file --retention limits --replicas 1 --defaults >/dev/null
echo "--- does COPY2's subscription show up in the account sublist? ---"
curl -s "http://127.0.0.1:$HP/subsz?subs=1&acc=\$G" | python3 -c '
import json,sys
d=json.load(sys.stdin)
print("num_subscriptions", d.get("num_subscriptions"))
for s in d.get("subscriptions_list", []):
    print("  ", s.get("subject"), "sid", s.get("sid"), "account", s.get("account"))' | head -20
python3 - <<'PY'
import json, sys, time
sys.path.insert(0, ".")
import topolab
c = topolab.Nats(4291, "pc")
cfg = {"stream_name": "SRC2", "config": {"durable_name": "TOCOPY", "ack_policy": "none",
        "deliver_policy": "all", "deliver_subject": "copy2.evt", "replay_policy": "instant"}}
m = c.request("$JS.API.CONSUMER.DURABLE.CREATE.SRC2.TOCOPY", json.dumps(cfg).encode(), timeout=60)
d = json.loads(m[3])
print("create:", "error" in d and json.dumps(d["error"]) or "ok")
time.sleep(3)
m = c.request("$JS.API.CONSUMER.INFO.SRC2.TOCOPY", b"", timeout=60)
d = json.loads(m[3])
print("consumer after 3s: delivered", d["delivered"], "num_pending", d["num_pending"],
      "push_bound", d.get("push_bound"))
m = c.request("$JS.API.STREAM.INFO.COPY2", b"", timeout=60)
print("COPY2 messages:", json.loads(m[3])["state"]["messages"])
c.close()
PY

tl "G2 · the same consumer with a real subscriber on copy2.evt"
nats --server nats://127.0.0.1:4291 sub 'copy2.evt' --count 5 > g2-sub.txt 2>&1 &
SUBPID=$!
sleep 2
python3 - <<'PY'
import json, sys, time
sys.path.insert(0, ".")
import topolab
c = topolab.Nats(4291, "pc2")
m = c.request("$JS.API.CONSUMER.INFO.SRC2.TOCOPY", b"", timeout=60)
d = json.loads(m[3])
print("consumer with a subscriber: delivered", d["delivered"], "num_pending", d["num_pending"],
      "push_bound", d.get("push_bound"))
m = c.request("$JS.API.STREAM.INFO.COPY2", b"", timeout=60)
print("COPY2 messages:", json.loads(m[3])["state"]["messages"])
c.close()
PY
wait $SUBPID 2>/dev/null
echo "--- what the subscriber saw ---"
head -12 g2-sub.txt
python3 - <<'PY'
import json, sys
sys.path.insert(0, ".")
import topolab
c = topolab.Nats(4291, "pc3")
m = c.request("$JS.API.STREAM.INFO.COPY2", b"", timeout=60)
print("COPY2 messages after the subscriber ran:", json.loads(m[3])["state"]["messages"])
m = c.request("$JS.API.STREAM.MSG.GET.COPY2", b'{"seq":1}', timeout=60)
d = json.loads(m[3])
print("COPY2 seq 1:", json.dumps(d.get("error")) if "error" in d else
      (d["message"]["subject"], "hdrs" in d["message"]))
c.close()
PY

tl "G3 · the shape that actually works: a client that pulls from SRC2 and publishes into COPY2"
$N stream add COPY3 --subjects 'copy3.>' --storage file --retention limits --replicas 1 --defaults >/dev/null
python3 - <<'PY'
import json, sys, time, os, queue
sys.path.insert(0, ".")
import topolab
c = topolab.Nats(4291, "relay")
cfg = {"stream_name": "SRC2", "config": {"durable_name": "RELAY", "ack_policy": "none",
        "deliver_policy": "all", "replay_policy": "instant", "max_ack_pending": 1000}}
c.request("$JS.API.CONSUMER.DURABLE.CREATE.SRC2.RELAY", json.dumps(cfg).encode(), timeout=60)
inbox = "_INBOX.relay." + os.urandom(6).hex()
c.sub(inbox)
f = topolab.Filler(c, window=500)
t0 = time.monotonic()
got = 0
while got < 1000 and time.monotonic() - t0 < 120:
    c.pub("$JS.API.CONSUMER.MSG.NEXT.SRC2.RELAY",
          json.dumps({"batch": 200, "expires": 5_000_000_000}).encode(), inbox)
    deadline = time.monotonic() + 5
    n = 0
    while n < 200 and time.monotonic() < deadline:
        try:
            m = c.q.get(timeout=1)
        except queue.Empty:
            break
        if m[2].startswith(b"NATS/1.0"):
            n = 200; break
        f.send("copy3." + m[0].split(".", 1)[1], m[3])
        got += 1; n += 1
f.finish()
dt = time.monotonic() - t0
print(f"relay: {got} messages pulled from SRC2 and republished into COPY3 in {dt:.2f}s "
      f"({got/dt:.0f} msg/s), {f.errs} publish errors")
m = c.request("$JS.API.STREAM.INFO.COPY3", b"", timeout=60)
st = json.loads(m[3])["state"]
print("COPY3:", st["messages"], "messages,", st["bytes"], "bytes, first_seq", st["first_seq"])
m = c.request("$JS.API.STREAM.MSG.GET.COPY3", b'{"seq":1}', timeout=60)
d = json.loads(m[3])
print("COPY3 seq 1:", d["message"]["subject"], "hdrs", bool(d["message"].get("hdrs")))
c.close()
PY
du -sk "$STORE/jetstream/\$G/streams/"* | sed "s|$LAB|<lab>|"

tl "done"
