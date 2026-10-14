#!/bin/bash
# one_S.sh NAME REGIME [VAR=value ...]: adj_run_S.R at one.sh's setting, on libS,
# writing to S_out. KNOTS=0 drops the knot stops.
S=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest
DEV=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev
O=$S/S_out; mkdir -p $O/runs $O/logs
name=$1; rec=$2; shift 2
echo "start $name $(date +%T)" >> $O/queue.out
env REGIME=$rec TOL=3e-5 ATOL=1e-4 WEIGHT_SOIL=10 WEIGHT=$DEV/window/rule_A/weight_$rec.rds \
  WEIGHT_MAX=100 HMAX=15 SHARE=0.1 SPLIT=1 LIB=$S/adjmap/libS OUT=$O/runs/$name.rds "$@" \
  Rscript /home/user/plant-dev/docs/measurements/schedule-search/round4/S/adj_run_S.R > $O/logs/$name.log 2>&1
echo "done $name $? $(date +%T)" >> $O/queue.out
