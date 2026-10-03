#!/bin/bash
# Start a queue detached from the launching shell. Usage: launch.sh QUEUE.sh
P=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/phase1b
q=$1
setsid nohup bash "$P/$q" > "$P/runs/${q%.sh}.out" 2>&1 < /dev/null &
echo "launched $q as $!"
