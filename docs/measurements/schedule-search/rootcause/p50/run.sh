#!/bin/bash
# run.sh KIND/CASE [KIND/CASE...]: the E6 committed runs' setting (one_nk.sh's environment; libS,
# no knot stops, 1e-4) with TIMES = sched/KIND_CASE.rds; at most two at a time (P=2).
# FORWARD=1 skips the gradient; extra env (e.g. TRAJ=1) passes through.
A=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap
DEV=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev
P5=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/p50
RUNNER=${RUNNER:-$A/adj_run_nk.R}
one() { kind=${1%%/*}; cs=${1#*/}; case $cs in
    episodic-lma) rec=episodic; extra="TRAIT_REL=lma=0.25"; w=episodic ;;
    dry-p50) rec=dry; extra="TRAIT_REL=root_P50=0.2"; w=dry ;;
    dry-flat) rec=dry-flat; extra=""; w=dry ;;
    wet-adG2) rec=long-wet; extra="TRAIT_REL=a_dG2=0.25"; w=long-wet ;;
    ld-102) rec=long-drought; extra="SEED=102"; w=long-drought ;;
    ld-105) rec=long-drought; extra="SEED=105"; w=long-drought ;;
    *) rec=$cs; extra=""; w=$cs ;;
  esac
  name=p5_${kind}_$cs; [ -s $P5/runs/$name.rds ] && return 0
  echo "start $name $(date +%T)" >> $P5/queue.out
  env REGIME=$rec TOL=3e-5 ATOL=1e-4 WEIGHT_SOIL=10 WEIGHT_MAX=100 HMAX=15 SHARE=0.1 SPLIT=1 OUT=$P5/runs/$name.rds \
    TIMES=$P5/sched/${kind}_$cs.rds WEIGHT=$DEV/window/rule_A/weight_$w.rds TOL=1e-4 LIB=$A/libS KNOTS=0 $extra \
    Rscript $RUNNER > $P5/logs/$name.log 2>&1
  echo "done $name $? $(date +%T)" >> $P5/queue.out; }
export -f one; export A DEV P5 RUNNER
printf "%s\n" "$@" | xargs -P ${P:-2} -I{} bash -c 'one {}'
