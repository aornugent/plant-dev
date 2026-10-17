#!/bin/bash
# run.sh NAME/CASE [NAME/CASE...]: one gradient run per item at the E6 committed setting (libS's
# exact source + node_drop.patch, no knot stops, 1e-4), MODE=map so the sweep also returns the
# node-drop map for COARSE = sched/NAME_coarse.rds; TIMES = sched/NAME.rds; output runs/NAME.rds.
# At most P (default 3) at a time, none started while the machine shows MAXR (default 4) or more R processes; with P = 3 that is 3 runs plus a driver.
L=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/loop
DEV=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev
H=/home/user/plant-dev/docs/measurements/schedule-search/rootcause
one() { name=${1%%/*}; cs=${1#*/}; seed=""; trait=""
  case $cs in
    episodic-lma) rec=episodic; trait="lma=0.25"; w=episodic ;;
    dry-p50) rec=dry; trait="root_P50=0.2"; w=dry ;;
    dry-flat) rec=dry-flat; w=dry ;;
    wet-adG2) rec=long-wet; trait="a_dG2=0.25"; w=long-wet ;;
    ld-102) rec=long-drought; seed=102; w=long-drought ;;
    ld-105) rec=long-drought; seed=105; w=long-drought ;;
    dry-lma125) rec=dry; seed=31; trait="lma=0.25"; w=dry ;;
    flat-al1125) rec=dry-flat; seed=31; trait="a_l1=0.25"; w=dry ;;
    wet-lma08) rec=long-wet; seed=31; trait="lma=-0.2"; w=long-wet ;;
    wet-hmat125) rec=long-wet; seed=31; trait="hmat=0.25"; w=long-wet ;;
    epi-hmat08) rec=episodic; seed=31; trait="hmat=-0.2"; w=episodic ;;
    epi-adG208) rec=episodic; seed=31; trait="a_dG2=-0.2"; w=episodic ;;
    ld104-p50125) rec=long-drought; seed=104; trait="root_P50=0.25"; w=long-drought ;;
    ld107-adG2125) rec=long-drought; seed=107; trait="a_dG2=0.25"; w=long-drought ;;
    *) rec=$cs; w=$cs ;;
  esac
  grep -q "^done 0 $name " $L/queue.out 2>/dev/null && [ -s $L/runs/$name.rds ] && return 0
  exec 9>$L/.gate.lock; flock 9
  nr() { local n=0; for p in $(pgrep -f "R --|Rscript|exec/R"); do c=$(ps -o comm= -p $p 2>/dev/null); case "$c" in R|Rscript) n=$((n + 1)) ;; esac; done; echo $n; }
  while [ $(nr) -ge ${MAXR:-4} ]; do sleep $((10 + RANDOM % 10)); done
  echo "start $name $(date +%T) (R procs $(nr); $(df -h / | awk 'NR==2{print $4}') free)" >> $L/queue.out
  env REGIME=$rec ${seed:+SEED=$seed} ${trait:+TRAIT_REL=$trait} TOL=1e-4 ATOL=1e-4 WEIGHT_SOIL=10 WEIGHT_MAX=100 HMAX=15 SHARE=0.1 SPLIT=1 KNOTS=0 \
    WEIGHT=$DEV/window/rule_A/weight_$w.rds LIB=$L/build/lib TIMES=$L/sched/$name.rds COARSE=$L/sched/${name}_coarse.rds MODE=map \
    OUT=$L/runs/$name.rds $EXTRA Rscript $H/dwr/adj_run_dwr.R > $L/logs/$name.log 2>&1 &
  pid=$!; sleep 10; flock -u 9; wait $pid; rc=$?
  echo "done $rc $name $(date +%T)" >> $L/queue.out; }
export -f one; export L DEV H EXTRA
printf "%s\n" "$@" | xargs -P ${P:-3} -I{} bash -c 'one {}'
