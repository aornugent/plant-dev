#!/bin/bash
# run.sh KIND/CASE [KIND/CASE...]: the E6 committed runs' setting (one_nk.sh's environment;
# libS, no knot stops, 1e-4) with TIMES = sched/KIND_CASE.rds, output runs/h5_KIND_CASE.rds.
# At most P (default 2) of this round's at a time, none started unless the machine shows 3 or
# fewer R processes (pgrep, the shared gate). FORWARD=1, TOL=..., TRAIT_EXTRA=... pass through.
A=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap
DEV=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev
H5=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/u
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
  exec 9>$H5/.gate.lock; flock 9                                  # one lane checks the gate at a time
  mine() { echo $(( $(grep -c '^start' $H5/queue.out 2>/dev/null) - $(grep -c '^done' $H5/queue.out 2>/dev/null) )); }
  nr() { local n=0; for p in $(pgrep -f "R --|Rscript|exec/R"); do c=$(ps -o comm= -p $p 2>/dev/null); case "$c" in R|Rscript) n=$((n + 1)) ;; esac; done; echo $n; }   # real R processes
  while [ $(nr) -ge 4 ] || [ $(mine) -ge $(cat $H5/.maxmine 2>/dev/null || echo 2) ]; do sleep $((5 + RANDOM % 10)); done   # .maxmine: this round's lanes
  echo "start $name $(date +%T) (R procs $(nr))" >> $H5/queue.out
  env REGIME=$rec TOL=3e-5 ATOL=1e-4 WEIGHT_SOIL=10 WEIGHT_MAX=100 HMAX=15 SHARE=0.1 SPLIT=1 OUT=$H5/runs/$name.rds \
    TIMES=$H5/sched/${sk}_$cs.rds WEIGHT=$DEV/window/rule_A/weight_$w.rds TOL=${RTOL:-1e-4} LIB=$A/libS KNOTS=0 \
    ${extra} ${trait:+TRAIT_REL=$trait} Rscript $A/adj_run_nk.R > $H5/logs/$name.log 2>&1 &
  pid=$!; sleep 8; flock -u 9; wait $pid; rc=$?
  echo "done $name $rc $(date +%T)" >> $H5/queue.out; }
export -f one; export A DEV H5 TRAIT_EXTRA RTOL FORWARD
printf "%s\n" "$@" | xargs -P ${P:-2} -I{} bash -c 'one {}'
