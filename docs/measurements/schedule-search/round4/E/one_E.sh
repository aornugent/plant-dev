#!/bin/bash
# one_E.sh NAME REGIME [VAR=value ...]: agent E's adj_run_E.R at one.sh's proper setting.
A=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap
DEV=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev
O=$DEV/schedtest/E_out; mkdir -p $O/runs $O/logs
name=$1; rec=$2; shift 2
grep -q "^done $name 0 " $O/queue.out 2>/dev/null && exit 0
cp /home/user/plant-dev/docs/measurements/schedule-search/round4/E/adj_run_E.R $O/logs/$name.R
echo "start $name $(date +%T)" >> $O/queue.out
env REGIME=$rec TOL=3e-5 ATOL=1e-4 WEIGHT_SOIL=10 WEIGHT=$DEV/window/rule_A/weight_$rec.rds \
  WEIGHT_MAX=100 HMAX=15 SHARE=0.1 SPLIT=1 OUT=$O/runs/$name.rds "$@" \
  Rscript $O/logs/$name.R > $O/logs/$name.log 2>&1
echo "done $name $? $(date +%T)" >> $O/queue.out
