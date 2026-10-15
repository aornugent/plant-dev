#!/bin/bash
# X1 (not pre-registered): the cheapest stable variant (stop on steps over 0.25 d,
# starting before b = 25) at tighter tolerances, each with its -5% nudge, to find where
# it reaches unstopped 1e-4's error against the reference.
L=/home/user/plant-dev/docs/measurements/deep-search-nonsmooth/lean
T=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/libJTstopTmax
for t in 1.5e-4 1.425e-4 1e-4 9.5e-5; do echo "X1_both_$t TOL=$t JT_STOP=1 JT_STOP_LOG=1 JT_STOP_TMAX=25 JT_STOP_HMIN=0.000684932 LIB=$T"; done |
  xargs -P 3 -L 1 $L/gate.sh $L/run.sh
