#!/bin/bash
# After queue1: lib_sw with no weights at 1e-5 on long drought, the stand alone,
# to check that the assessment's ld_1e-5 reference (build unrecorded) has this
# build's trajectory. One R process at a time, under nice, from the snapshot.
D=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev
C=$D/phase1c/combined
T108=$D/window/t/t_u108.rds
until grep -q "queue finished" $C/queue.out 2>/dev/null; do sleep 20; done
cd $C/snap || exit 1
note() { echo "$1 $(date +%T)" >> $C/queue.out; }
note "start chk_ld_1e-5_forward"
env PLANT_LIB=$D/lib_sw TOL=1e-5 ATOL=1e-4 TIMES=$T108 REGIME=long-drought FORWARD=1 OUT=$C/full/chk_ld_1e-5_forward.rds \
  nice -n 10 Rscript harness/run_record.R > $C/full/chk_ld_1e-5_forward.log 2>&1
note "done chk_ld_1e-5_forward"
note "queue2 finished"
