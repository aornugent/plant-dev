#!/bin/bash
# One driver run from pf_soil/mr/harness_w (the multirate step, MR_COUPLE), bounded setting.
#   drv.sh NAME RECORD [VAR=value ...]
D=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev
M=$D/pf_soil/mr
name=$1; rec=$2; shift 2
cd "$M" || exit 1
mkdir -p runs logs
echo "start $name $(date +%T) load $(cut -d' ' -f1 /proc/loadavg)" >> queue.out
env PLANT_LIB=$D/lib_sw METHOD=ck TOL=3e-5 ATOL=1e-4 TOL_SOIL=10 \
  WEIGHT=$D/window/rule_A/weight_$rec.rds HMAX=15 WEIGHT_MAX=100 \
  TIMES=$D/window/t/t_u108.rds REGIME=$rec OUT=$M/runs/$name.rds "$@" \
  nice -n 10 Rscript harness_w/ark_prototype.R > logs/$name.log 2>&1
echo "done $name status $? $(date +%T)" >> queue.out
