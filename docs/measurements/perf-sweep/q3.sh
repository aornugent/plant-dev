#!/bin/bash
# After the container restart of 23:04: what was still needed, one heavy job at
# a time. The cut under the tapestats shim on both builds; the spread build's
# callgrind of the cut's sweep (the first was cut off by the restart); u108 on
# both builds (plain forward, recorded forward, sweep, tape stats).
SPD=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/sweep_profile
DEV=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev
SHIM="SP_ODELIA_SO=$DEV/lib_guard/odelia/libs/odelia.so LD_PRELOAD=$SPD/tapestats.so"
P=$SPD/logs/q3.progress
echo "start $(date -u +%FT%TZ)" >> $P
bash $SPD/job.sh tape5_guard $DEV/lib_guard - sp_tape.R T=5 $SHIM SP_TAPESTATS=$SPD/out/tape5_guard.tsv
bash $SPD/job.sh tape5_spread $DEV/comb/lib3 8 sp_tape.R T=5 $SHIM SP_TAPESTATS=$SPD/out/tape5_spread.tsv
echo "tape5 done $(date -u +%FT%TZ)" >> $P
bash $SPD/sp_cg.sh spread5 $DEV/comb/lib3 8 5
echo "spread5 done $(date -u +%FT%TZ)" >> $P
bash $SPD/job.sh u108_guard $DEV/lib_guard - sp_time.R T=0 NODES=108 $SHIM SP_TAPESTATS=$SPD/out/u108_guard.tsv
echo "u108_guard done $(date -u +%FT%TZ)" >> $P
bash $SPD/job.sh u108_spread $DEV/comb/lib3 8 sp_time.R T=0 NODES=108 $SHIM SP_TAPESTATS=$SPD/out/u108_spread.tsv
echo "Q3 DONE $(date -u +%FT%TZ)" >> $P
