#!/bin/bash
# run.sh NAME [VAR=value ...]: one gradient run of the inset committed schedule on dry
# (adjmap/adj_run.R at the node_rule ladders' setting, as adjmap/one.sh), output
# deep/lean/NAME.{rds,log}; appends start/done lines to deep/lean/queue.out.
S=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest
DEV=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev
O=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/lean
name=$1; shift
grep -q "^done $name 0 " $O/queue.out 2>/dev/null && exit 0
echo "start $name $(date +%T)" >> $O/queue.out
env REGIME=dry TOL=3e-5 ATOL=1e-4 WEIGHT_SOIL=10 WEIGHT=$DEV/window/rule_A/weight_dry.rds \
  WEIGHT_MAX=100 HMAX=15 SHARE=0.1 SPLIT=1 TIMES=$S/P_out/sched/ins3c_dry.rds \
  LIB=$S/libJTstop OUT=$O/$name.rds "$@" \
  Rscript $S/adjmap/adj_run.R > $O/$name.log 2>&1
echo "done $name $? $(date +%T)" >> $O/queue.out
