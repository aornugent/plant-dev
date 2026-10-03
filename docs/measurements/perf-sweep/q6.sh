#!/bin/bash
# The spread build at u429 in the canopy-spread configuration (TOL 3e-5,
# absolute 3e-9), recorded forward and sweep under the tapestats shim: does the
# reported 3.4x sweep and 2x memory show in the tape?
SPD=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/sweep_profile
DEV=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev
SHIM="SP_ODELIA_SO=$DEV/lib_guard/odelia/libs/odelia.so LD_PRELOAD=$SPD/tapestats.so"
bash $SPD/job.sh t3e5_u429_spread $DEV/comb/lib3 8 sp_tape.R T=0 NODES=429 TOL=3e-5 TOL_ABS=3e-9 $SHIM SP_TAPESTATS=$SPD/out/t3e5_u429_spread.tsv
echo "Q6 DONE $(date -u +%FT%TZ)" >> $SPD/logs/q6.progress
