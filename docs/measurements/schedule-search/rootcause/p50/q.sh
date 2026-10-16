#!/bin/bash
# q.sh JOBFILE: run jobs two at a time (P), each line "NAME KIND CASE [VAR=VAL ...]" in the E6
# committed setting (libS, no knot stops, 1e-4, one_nk.sh's environment) with TIMES =
# sched/KIND_CASE.rds; VAR=VAL adds settings (FORWARD=1, PIN=..., TRAIT_REL=..., SCRIPT=traj.R).
A=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap
DEV=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev
P5=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/p50
D=/home/user/plant-dev/docs/measurements/schedule-search/rootcause/p50
one() { read name kind cs more <<< "$1"; case $cs in
    dry-p50) rec=dry; extra="TRAIT_REL=root_P50=0.2"; w=dry ;;
    dry-flat) rec=dry-flat; extra=""; w=dry ;;
    *) rec=$cs; extra=""; w=$cs ;;
  esac
  [ -s $P5/runs/$name.rds ] && return 0
  script=$A/adj_run_nk.R; for kv in $more; do case $kv in SCRIPT=*) script=$D/${kv#SCRIPT=} ;; esac; done
  echo "start $name $(date +%T)" >> $P5/queue.out
  env REGIME=$rec ATOL=1e-4 WEIGHT_SOIL=10 WEIGHT_MAX=100 HMAX=15 SHARE=0.1 SPLIT=1 OUT=$P5/runs/$name.rds \
    TIMES=$P5/sched/${kind}_$cs.rds WEIGHT=$DEV/window/rule_A/weight_$w.rds TOL=1e-4 LIB=$A/libS KNOTS=0 $extra $more \
    Rscript $script > $P5/logs/$name.log 2>&1
  echo "done $name $? $(date +%T)" >> $P5/queue.out; }
export -f one; export A DEV P5 D
grep -v '^#' $1 | xargs -P ${P:-2} -d '\n' -I{} bash -c 'one "{}"'
