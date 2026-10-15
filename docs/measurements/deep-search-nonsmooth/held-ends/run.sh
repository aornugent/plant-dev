#!/bin/bash
# run.sh NAME [VAR=value ...]: adj_run.R at JT8_ins_3e-4_stop's settings on libJTstop;
# output, log and stderr (JTROOT lines) under the held-ends scratch dir.
D=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev
S=$D/schedtest
O=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/held-ends
name=$1; shift
echo "start $name $(date +%T)" >> $O/queue.out
env REGIME=dry TOL=3e-4 ATOL=1e-4 WEIGHT_SOIL=10 WEIGHT=$D/window/rule_A/weight_dry.rds \
  WEIGHT_MAX=100 HMAX=15 SHARE=0.1 SPLIT=1 TIMES=$S/P_out/sched/ins3c_dry.rds \
  LIB=$S/libJTstop OUT=$O/$name.rds "$@" \
  Rscript $S/adjmap/adj_run.R > $O/$name.log 2> $O/$name.err
echo "done $name $? $(date +%T)" >> $O/queue.out
