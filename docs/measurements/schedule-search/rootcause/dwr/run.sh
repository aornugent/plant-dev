#!/bin/bash
# run.sh MODE TAG CASE [COARSE_SUFFIX] [extra env...]: one pinned replay on the scratch build
# (libS + node_drop.patch) of the saved run that mk_drop2.R recorded for TAG, at the E6
# committed setting (as p50/run.sh, with its per-case record, seed, trait and weight). MODE map: the drop columns; MODE drop1:
# the coarse field at first order with the full sweep (SWEEP=1). One R process at a time.
DW=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/dwr
DEV=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev
H=/home/user/plant-dev/docs/measurements/schedule-search/rootcause/dwr
mode=$1; tag=$2; cs=$3; sfx=$4; shift 4
co=$DW/sched/coarse_${tag}${sfx:+_$sfx}_$cs.rds; [ "$mode" = plain ] && times=$co || times=$DW/sched/times_${tag}_$cs.rds
name=${mode}_${tag}${sfx:+_$sfx}_$cs
case $cs in
  episodic-lma) rec=episodic; extra="TRAIT_REL=lma=0.25"; w=episodic ;;
  dry-p50) rec=dry; extra="TRAIT_REL=root_P50=0.2"; w=dry ;;
  dry-flat) rec=dry-flat; extra=""; w=dry ;;
  wet-adG2) rec=long-wet; extra="TRAIT_REL=a_dG2=0.25"; w=long-wet ;;
  ld-102) rec=long-drought; extra="SEED=102"; w=long-drought ;;
  ld-105) rec=long-drought; extra="SEED=105"; w=long-drought ;;
  *) rec=$cs; extra=""; w=$cs ;;
esac
env REGIME=$rec $extra TOL=1e-4 ATOL=1e-4 WEIGHT_SOIL=10 WEIGHT_MAX=100 HMAX=15 SHARE=0.1 SPLIT=1 KNOTS=0 \
  WEIGHT=$DEV/window/rule_A/weight_$w.rds LIB=$DW/build/lib TIMES=$times \
  PIN=$(cat $DW/sched/pin_${tag}_$cs.txt) COARSE=$co MODE=$mode OUT=$DW/runs/$name.rds "$@" \
  Rscript $H/adj_run_dwr.R > $DW/logs/$name.log 2>&1
echo "$name exit $?" >> $DW/queue.out
