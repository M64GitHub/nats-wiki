#!/usr/bin/env bash
# config-mutability-run2.sh — pass 2 (2026-09-03): a fresh stream CFG2 with no roll-up flag, for the cases pass 1's
# harness contaminated (it copied a config with allow_rollup_hdrs: true forward), and MSG.NEXT batch 300 on a
# consumer with no max_batch. Same lab, same binary.
set -u
S="--server nats://127.0.0.1:4291 --timeout 4s"
req() { nats $S req "$1" "$2" 2>&1 | grep -vE '^$|Sending|Received' ; }
show() { python3 -c 'import json,sys
for l in sys.stdin:
    l=l.strip()
    if not l.startswith("{"): print(l); continue
    d=json.loads(l); e=d.get("error"); print("  refused:", e["err_code"], e["description"]) if e else print("  accepted; " + ", ".join("%s=%s"%(k,d["config"].get(k)) for k in ("storage","retention","discard","num_replicas","sealed","deny_delete","deny_purge","allow_rollup_hdrs","allow_msg_counter","discard_new_per_subject","max_msgs_per_subject","mirror","subjects","max_age")))'; }
BASE='{"name":"CFG2","subjects":["cfg2.>"],"retention":"limits","max_consumers":-1,"max_msgs":-1,"max_bytes":-1,"max_age":0,"max_msgs_per_subject":-1,"max_msg_size":-1,"discard":"old","storage":"file","num_replicas":1,"duplicate_window":120000000000}'
echo "### create CFG2"; req '$JS.API.STREAM.CREATE.CFG2' "$BASE" | show
u() { printf '### update: %s\n' "$1"; req '$JS.API.STREAM.UPDATE.CFG2' "$(python3 -c "import json,sys; cfg=json.loads(sys.argv[1]); exec(sys.argv[2]); print(json.dumps(cfg))" "$BASE" "$2")" | show; }
u "discard_new_per_subject without discard new"        'cfg["discard_new_per_subject"]=True'
u "discard_new_per_subject with discard new, no per-subject limit" 'cfg["discard"]="new"; cfg["discard_new_per_subject"]=True'
u "discard_new_per_subject with discard new + max_msgs_per_subject 10" 'cfg["discard"]="new"; cfg["discard_new_per_subject"]=True; cfg["max_msgs_per_subject"]=10'
u "allow_msg_counter on (fresh stream, no TTL)"         'cfg["allow_msg_counter"]=True'
u "mirror added to a stream that has subjects"          'cfg["mirror"]={"name":"OTHER"}'
u "mirror added, subjects removed"                      'cfg["subjects"]=[]; cfg["mirror"]={"name":"OTHER"}'
u "deny_purge on"                                       'cfg["deny_purge"]=True'
BASE=$(python3 -c "import json,sys; cfg=json.loads(sys.argv[1]); cfg['deny_purge']=True; print(json.dumps(cfg))" "$BASE")
u "deny_purge off again"                                'cfg["deny_purge"]=False'
u "sealed on"                                           'cfg["sealed"]=True'
BASE=$(python3 -c "import json,sys; cfg=json.loads(sys.argv[1]); cfg['sealed']=True; print(json.dumps(cfg))" "$BASE")
u "sealed off again"                                    'cfg["sealed"]=False'
u "sealed stream: max_age 1h (sealed forces max_age 0)"  'cfg["max_age"]=3600000000000'
echo; echo "### STREAM.INFO CFG2 — what sealing changed"; req '$JS.API.STREAM.INFO.CFG2' '' | python3 -c 'import json,sys; d=json.loads([l for l in sys.stdin if l.startswith("{")][0]); c=d["config"]; print("  ", {k:c.get(k) for k in ("sealed","deny_delete","deny_purge","discard","max_age","allow_rollup_hdrs")})'
echo; echo "### consumer c2 on CFG2, no max_batch; 3 publishes; MSG.NEXT batch 300"
for s in cfg2.a cfg2.a cfg2.a; do nats $S pub $s "x" >/dev/null 2>&1; done
req '$JS.API.CONSUMER.CREATE.CFG2.c2' '{"stream_name":"CFG2","config":{"durable_name":"c2","ack_policy":"explicit","filter_subject":"cfg2.a"},"action":"create"}' | python3 -c 'import json,sys; d=json.loads([l for l in sys.stdin if l.startswith("{")][0]); c=d.get("config",{}); print("  created; max_batch=%s max_waiting=%s ack_wait=%s max_ack_pending=%s inactive_threshold=%s num_pending=%s" % (c.get("max_batch"),c.get("max_waiting"),c.get("ack_wait"),c.get("max_ack_pending"),c.get("inactive_threshold"),d.get("num_pending")))'
nats $S req '$JS.API.CONSUMER.MSG.NEXT.CFG2.c2' '{"batch":300,"no_wait":true}' --replies 4 2>&1 | grep -vE '^$|Sending' | cut -c1-120
echo "### MSG.NEXT batch 100000 (no_wait) on c2"; nats $S req '$JS.API.CONSUMER.MSG.NEXT.CFG2.c2' '{"batch":100000,"no_wait":true}' --replies 1 2>&1 | grep -vE '^$|Sending' | cut -c1-120
echo; echo "### an ephemeral consumer's inactive_threshold as stored"; req '$JS.API.CONSUMER.CREATE.CFG2' '{"stream_name":"CFG2","config":{"ack_policy":"none"},"action":"create"}' | python3 -c 'import json,sys; d=json.loads([l for l in sys.stdin if l.startswith("{")][0]); c=d.get("config",{}); print("  name=%s ack_policy=%s ack_wait=%s max_ack_pending=%s inactive_threshold=%s max_waiting=%s" % (d.get("name"),c.get("ack_policy"),c.get("ack_wait"),c.get("max_ack_pending"),c.get("inactive_threshold"),c.get("max_waiting")))'
echo; echo "### cleanup"; req '$JS.API.STREAM.DELETE.CFG2' '' | head -c 100; echo
