#!/bin/bash
# run.sh MODE TAG CASE [COARSE_SUFFIX] [extra env...]: one pinned replay on the scratch build
# (libS + node_drop.patch) of the saved run that mk_drop2.R recorded for TAG, at the E6
# committed setting (as p50/run.sh, dry weights). MODE map: the drop columns; MODE drop1:
# the coarse field at first order with the full sweep (SWEEP=1). One R process at a time.
DW=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/dwr
DEV=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev
H=/home/user/plant-dev/docs/measurements/schedule-search/rootcause/dwr
mode=$1; tag=$2; cs=$3; sfx=$4; shift 4
co=$DW/sched/coarse_${tag}${sfx:+_$sfx}_$cs.rds
name=${mode}_${tag}${sfx:+_$sfx}_$cs
env REGIME=$cs TOL=1e-4 ATOL=1e-4 WEIGHT_SOIL=10 WEIGHT_MAX=100 HMAX=15 SHARE=0.1 SPLIT=1 KNOTS=0 \
  WEIGHT=$DEV/window/rule_A/weight_$cs.rds LIB=$DW/build/lib TIMES=$DW/sched/times_${tag}_$cs.rds \
  PIN=$(cat $DW/sched/pin_${tag}_$cs.txt) COARSE=$co MODE=$mode OUT=$DW/runs/$name.rds "$@" \
  Rscript $H/adj_run_dwr.R > $DW/logs/$name.log 2>&1
echo "$name exit $?" >> $DW/queue.out
