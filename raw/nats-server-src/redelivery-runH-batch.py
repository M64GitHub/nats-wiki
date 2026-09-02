#!/usr/bin/env python3
"""redelivery-runH-batch.py — the pull half of run H: one pull request of batch 100 kept open
against each consumer, every message acked the moment it arrives (the shape of a client's
consume loop), deliveries counted per stream sequence from the $JS.ACK reply subject
($JS.ACK.<stream>.<consumer>.<delivered>.<sseq>.<cseq>.<ts>.<pending>). Uses the stdlib-only
probe client in raw/nats-server-src/nats-probe-client.py."""
import importlib.util, json, sys, time, collections
spec = importlib.util.spec_from_file_location("probe", sys.argv[1]); probe = importlib.util.module_from_spec(spec); spec.loader.exec_module(probe)
HOST, PORT = "127.0.0.1", 4291
import os
ACK_DELAY=float(os.environ.get("ACK_DELAY","0")); PULLS=int(os.environ.get("PULLS","1"))
def run(stream, consumer, batch=int(os.environ.get("BATCH","100")), window=3.0):
    nc = probe.Nats(HOST, PORT, name=f"runH-{consumer}")
    inbox = f"_INBOX.runH.{consumer}"; nc.sub(inbox); nc.flush()
    t0 = time.monotonic(); seen = collections.OrderedDict(); rows = []
    for pull in range(PULLS):
        nc.pub(f"$JS.API.CONSUMER.MSG.NEXT.{stream}.{consumer}", json.dumps({"batch": batch, "expires": int(window*1e9)}), reply=inbox)
        rows.append((round(time.monotonic()-t0, 4), "(pull)", f"pull #{pull+1}: batch={batch} expires={window:.0f}s", None, None))
        tp = time.monotonic(); got = 0
        while time.monotonic() - tp < window + 0.5:
            m = nc.get(0.2)
            if not m:
                if got >= batch: break
                continue
            if not m["reply"]:            # a status (408/409 …) or the pull's expiry
                rows.append((round(time.monotonic()-t0, 4), m["subject"], m["headers"].strip().replace("\r\n", " | "), None, None)); break
            tok = m["reply"].split("."); delivered, sseq = int(tok[4]), int(tok[5])
            if ACK_DELAY: time.sleep(ACK_DELAY)   # a handler that does some work before acking
            nc.pub(m["reply"], "+ACK")
            got += 1
            seen.setdefault(sseq, []).append(delivered)
            rows.append((round(time.monotonic()-t0, 4), m["subject"], m["payload"], delivered, sseq))
            if got >= batch: break
    nc.close()
    print(f"\n### {stream} / {consumer}: {PULLS} pull(s) of batch={batch} expires={window:.0f}s, ack {'after ' + str(int(ACK_DELAY*1000)) + ' ms' if ACK_DELAY else 'on arrival'}")
    for t, subj, payload, d, s in rows:
        print(f"  t={t:7.4f}s  {subj:<16} {'status ' + payload if d is None else f'sseq={s:<3} delivered={d}  {payload}'}")
    per = collections.Counter(len(v) for v in seen.values())
    print(f"  => {sum(len(v) for v in seen.values())} deliveries of {len(seen)} messages; deliveries per message: " + ", ".join(f"{n}x for {c} msgs" for n, c in sorted(per.items())))
for stream, consumer in [(a.split("/")[0], a.split("/")[1]) for a in sys.argv[2:]]:
    run(stream, consumer)
