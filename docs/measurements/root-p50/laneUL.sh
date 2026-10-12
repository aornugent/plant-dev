#!/bin/bash
# laneUL.sh REC K...: the late-uniform ladder at +-2% root_P50 on dry or dry-flat.
S=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest; D=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/..; rec=$1; shift
for k in "$@"; do for s in 0.02 -0.02; do
  name=rp_UL${k}_${s}_$rec; h=/home/user/plant-dev; [ "$rec" = dry-flat ] && h=$S/rp50/hflat
  echo "start $name $(date +%T)" >> $S/placed2/queue.out
  (cd $h && env PLANT_LIB=$D/lib_109 REGIME=$rec TOL=3e-5 ATOL=1e-4 WEIGHT_SOIL=10 WEIGHT=$D/window/rule_A/weight_dry.rds WEIGHT_MAX=100 HMAX=15 SHARE=0.1 SPLIT=1 \
    OUT=$S/placed2/runs/$name.rds TIMES=$S/rp50/UL$k.rds FORWARD=1 TRAIT_REL=root_P50=$s Rscript harness/run_record.R > $S/placed2/logs/$name.log 2>&1)
  echo "done $name $? $(date +%T)" >> $S/placed2/queue.out
done; done
