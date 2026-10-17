#!/bin/bash
# run.sh MODE CASE NAME [extra env...]: one replay on the scratch build (libS + dwr/node_drop.patch +
# single/active_drop.patch) pinned to the committed run val_insk_c_CASE, at the E6 committed
# setting (as dwr/run.sh, with its per-case record, trait and weight). MODE single / drop1a take
# DROPS=sched/drop_CASE.rds; MODE plain takes TIMES=... in the extra env (R0's coarse schedule).
SO=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/single
DEV=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev
H=/home/user/plant-dev/docs/measurements/schedule-search/rootcause/single
mode=$1; cs=$2; name=$3; shift 3
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
  WEIGHT=$DEV/window/rule_A/weight_$w.rds LIB=$SO/build/lib TIMES=$SO/sched/times_$cs.rds DROPS=$SO/sched/drop_$cs.rds \
  PIN=$(cat $SO/sched/pin_$cs.txt) MODE=$mode OUT=$SO/runs/$name.rds "$@" \
  Rscript $H/adj_run_single.R > $SO/logs/$name.log 2>&1
echo "$name exit $? $(date +%T)" >> $SO/queue.out
