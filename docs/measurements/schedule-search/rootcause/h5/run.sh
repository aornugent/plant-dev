#!/bin/bash
# run.sh KIND/CASE [KIND/CASE...]: the E6 committed runs' setting (one_nk.sh's environment;
# libS, no knot stops, 1e-4) with TIMES = sched/KIND_CASE.rds, output runs/h5_KIND_CASE.rds.
# At most P (default 2) of this round's at a time, and none started while the machine has 4
# or more R processes. FORWARD=1, TOL=..., TRAIT_EXTRA=... pass through.
A=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap
DEV=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev
H5=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/h5
one() { kind=${1%%/*}; cs=${1#*/}; sk=${kind%%@*}; trait=""
  case $cs in
    episodic-lma) rec=episodic; trait="lma=0.25"; w=episodic ;;
    dry-p50) rec=dry; trait="root_P50=0.2"; w=dry ;;
    dry-flat) rec=dry-flat; w=dry ;;
    wet-adG2) rec=long-wet; trait="a_dG2=0.25"; w=long-wet ;;
    ld-102) rec=long-drought; extra="SEED=102"; w=long-drought ;;
    ld-105) rec=long-drought; extra="SEED=105"; w=long-drought ;;
    *) rec=$cs; w=$cs ;;
  esac
  [ -n "$TRAIT_EXTRA" ] && trait=${trait:+$trait,}$TRAIT_EXTRA
  name=h5_${kind}_$cs; [ -s $H5/runs/$name.rds ] && return 0
  while [ $(pgrep -c -f "R --|Rscript|exec/R") -ge 4 ]; do sleep $((5 + RANDOM % 10)); done
  echo "start $name $(date +%T) (R procs $(pgrep -c -f 'R --|Rscript|exec/R'))" >> $H5/queue.out
  env REGIME=$rec TOL=3e-5 ATOL=1e-4 WEIGHT_SOIL=10 WEIGHT_MAX=100 HMAX=15 SHARE=0.1 SPLIT=1 OUT=$H5/runs/$name.rds \
    TIMES=$H5/sched/${sk}_$cs.rds WEIGHT=$DEV/window/rule_A/weight_$w.rds TOL=${RTOL:-1e-4} LIB=$A/libS KNOTS=0 \
    ${extra} ${trait:+TRAIT_REL=$trait} Rscript $A/adj_run_nk.R > $H5/logs/$name.log 2>&1
  echo "done $name $? $(date +%T)" >> $H5/queue.out; }
export -f one; export A DEV H5 TRAIT_EXTRA RTOL FORWARD
printf "%s\n" "$@" | xargs -P ${P:-2} -I{} bash -c 'one {}'
