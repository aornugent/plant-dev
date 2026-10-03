#!/bin/bash
# One mrw driver run (harness_w's copy, from w/ so its command line reads harness/), bounded setting.
#   drv_w2.sh NAME RECORD [VAR=value ...]
D=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev
M=$D/pf_soil/mr
name=$1; rec=$2; shift 2
cd "$M/w" || exit 1
echo "start $name $(date +%T) load $(cut -d' ' -f1 /proc/loadavg)" >> $M/queue.out
env PLANT_LIB=$D/lib_sw METHOD=ck TOL=3e-5 ATOL=1e-4 TOL_SOIL=10 \
  WEIGHT=$D/window/rule_A/weight_$rec.rds HMAX=15 WEIGHT_MAX=100 MR_SHARE=0.1 MR_COUPLE=member \
  TIMES=$D/window/t/t_u108.rds REGIME=$rec OUT=$M/runs/$name.rds "$@" \
  nice -n 10 Rscript harness/ark_prototype.R > $M/logs/$name.log 2>&1
echo "done $name status $? $(date +%T)" >> $M/queue.out
