#!/bin/bash
# Every two minutes: time, load average, the probe's two CPU times.   bash probe_loop.sh OUT
P=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/refine2perf/probe/probe
while true; do echo "$(date +%T) $(cut -d' ' -f1 /proc/loadavg) $($P)" >> $1; sleep 120; done
