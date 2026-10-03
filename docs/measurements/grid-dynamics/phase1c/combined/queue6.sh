#!/bin/bash
# After lane b of queue5: the rebuilt lib_sw with WEIGHT_MAX unset, episodic's
# stand alone, against lib_guard's spot-check run (bit for bit expected).
D=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev
C=$D/phase1c/combined
until grep -q "queue5 lane b finished" $C/queue.out 2>/dev/null; do sleep 20; done
cd $C/snap2 || exit 1
echo "start chk_epi_forward_rebuilt $(date +%T)" >> $C/queue.out
env PLANT_LIB=$D/lib_sw TOL=3e-5 ATOL=1e-4 TIMES=$D/window/t/t_u108.rds REGIME=episodic FORWARD=1 \
  OUT=$C/full/chk_epi_forward_rebuilt.rds nice -n 10 Rscript harness/run_record.R > $C/full/chk_epi_forward_rebuilt.log 2>&1
echo "done chk_epi_forward_rebuilt $(date +%T)" >> $C/queue.out
