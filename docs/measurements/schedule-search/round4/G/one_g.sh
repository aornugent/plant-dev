#!/bin/bash
# one_g.sh NAME REGIME [VAR=value ...]: as adjmap/one.sh, on G's copy of adj_run.R
# (adds KNOT_MAX), writing to G_out/runs.
A=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap
DEV=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev
O=$DEV/schedtest/G_out; mkdir -p $O/runs $O/logs
name=$1; rec=$2; shift 2
[ -f $O/runs/$name.rds ] && exit 0
echo "start $name $(date +%T)" >> $O/queue.out
env REGIME=$rec TOL=3e-5 ATOL=1e-4 WEIGHT_SOIL=10 WEIGHT=$DEV/window/rule_A/weight_$rec.rds \
  WEIGHT_MAX=100 HMAX=15 SHARE=0.1 SPLIT=1 OUT=$O/runs/$name.rds "$@" \
  nice Rscript /home/user/plant-dev/docs/measurements/schedule-search/round4/G/adj_run_g.R > $O/logs/$name.log 2>&1
echo "done $name $? $(date +%T)" >> $O/queue.out
