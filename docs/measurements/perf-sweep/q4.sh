#!/bin/bash
# After q3: the cut without the zero-depth pulses, under the shim, to measure
# what the insertion rows cost the sweep per row.
SPD=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/sweep_profile
DEV=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev
SHIM="SP_ODELIA_SO=$DEV/lib_guard/odelia/libs/odelia.so LD_PRELOAD=$SPD/tapestats.so"
until grep -q "Q3 DONE" $SPD/logs/q3.progress 2>/dev/null; do sleep 5; done
bash $SPD/job.sh tape5_guard_nostops $DEV/lib_guard - sp_tape.R T=5 NOSTOPS=1 $SHIM SP_TAPESTATS=$SPD/out/tape5_guard_nostops.tsv
echo "Q4 DONE $(date -u +%FT%TZ)" >> $SPD/logs/q3.progress
