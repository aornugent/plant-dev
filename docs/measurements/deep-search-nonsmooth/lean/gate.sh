#!/bin/bash
# gate.sh CMD ...: start CMD once fewer than three R processes run (machine-wide), one
# starter at a time; waits for CMD.
O=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/lean
exec 9>$O/gate.lock
flock 9
while [ "$(pgrep -xc R)" -ge 3 ]; do sleep 5; done
"$@" 9>&- &
pid=$!
sleep 8
flock -u 9
exec 9>&-
wait $pid
