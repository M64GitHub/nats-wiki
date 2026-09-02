#!/bin/bash
# redelivery-runG.sh — issue #6921's own reproduction recipe, on the lab's standalone v2.14.6
# (bash tools/lab/cluster.sh up 1). The stream and publishes are the reporter's lines verbatim;
# the consumer is the reporter's C#/Go config expressed as nats CLI flags.
S=${S:-nats://127.0.0.1:4291}
n() { echo; echo "\$ nats $*"; nats --server "$S" "$@"; }
nats-server --version; nats --version
n stream add FIVE --subjects "five.>" --max-msgs-per-subject=5 --max-age 1h --storage file --defaults
for i in 1 2 3 4 5; do n pub five.$i 1; n pub five.$i 2; done
n stream info FIVE
n consumer add FIVE Consumer --pull --deliver subject --filter '>' --ack explicit --max-pending 1 --max-deliver 3 --wait 30s --defaults
for i in 1 2 3 4 5 6; do n consumer next FIVE Consumer --ack --timeout 3s; done
n consumer info FIVE Consumer
