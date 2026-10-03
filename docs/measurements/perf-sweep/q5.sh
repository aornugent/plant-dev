#!/bin/bash
# The canopy-spread configuration (TOL 3e-5, absolute 3e-9) at u108 on both
# builds, recorded forward and sweep under the tapestats shim: does the spread's
# sweep slowdown appear at the tolerance it was measured at?
SPD=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/sweep_profile
DEV=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev
SHIM="SP_ODELIA_SO=$DEV/lib_guard/odelia/libs/odelia.so LD_PRELOAD=$SPD/tapestats.so"
P=$SPD/logs/q5.progress
echo "start $(date -u +%FT%TZ)" >> $P
bash $SPD/job.sh t3e5_u108_guard $DEV/lib_guard - sp_tape.R T=0 NODES=108 TOL=3e-5 TOL_ABS=3e-9 $SHIM SP_TAPESTATS=$SPD/out/t3e5_u108_guard.tsv
echo "guard done $(date -u +%FT%TZ)" >> $P
bash $SPD/job.sh t3e5_u108_spread $DEV/comb/lib3 8 sp_tape.R T=0 NODES=108 TOL=3e-5 TOL_ABS=3e-9 $SHIM SP_TAPESTATS=$SPD/out/t3e5_u108_spread.tsv
echo "Q5 DONE $(date -u +%FT%TZ)" >> $P
