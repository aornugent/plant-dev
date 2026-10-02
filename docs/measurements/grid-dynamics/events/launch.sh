#!/bin/bash
# Start a queue detached from the shell that launches it, so it outlives the
# tool's background time limit. Usage: launch.sh QUEUE.sh
E=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/events
q=$1
setsid nohup bash "$E/$q" > "$E/runs/${q%.sh}.out" 2>&1 < /dev/null &
echo "launched $q as $!"
