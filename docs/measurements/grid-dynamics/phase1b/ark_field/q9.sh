#!/bin/bash
# After q8: how far a plain replay of arkc's 3e-5 grid drifts from its recorded soil states.
source /tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/phase1b/run.sh
until grep -q "q8 finished" $R/q8.out 2>/dev/null; do sleep 10; done
script rdiff_3e-5 $P/events replay_diff.R $V12T METHOD=ark TOL=3e-5 GRID=$DEV/phase1a/t2/runs/arkc_3e-5.rds STEPS=1000000
echo "q9 finished"
