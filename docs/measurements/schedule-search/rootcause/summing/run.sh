#!/bin/bash
# run.sh JOBS: each line "NAME SCHED CASE RULE LIB [VAR=value ...]" is one run at the E6
# committed setting (no knot stops, 1e-4, one_nk.sh's environment, each case's weight,
# seed and trait move as in jobs_insk.txt) with TIMES = sched/SCHED_CASE.rds, output
# runs/NAME_CASE.rds, PLANT_SIMPSON = RULE (off, all, or lo:hi windows), on build
# build/LIB; RULE @X reads the case's window from sched/rule_X.txt. Two at a time (P).
# A run already started is skipped. At most `maxr` (a file; 2 if absent) runs at once; while
# the file `hold` exists no new run starts.
A=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap
DEV=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev
SU=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/summing
one() { set -- $1; nm=$1; sc=$2; cs=$3; rule=$4; lib=$5; shift 5
  case $cs in
    episodic-lma) rec=episodic; extra="TRAIT_REL=lma=0.25"; w=episodic ;;
    dry-p50) rec=dry; extra="TRAIT_REL=root_P50=0.2"; w=dry ;;
    dry-flat) rec=dry-flat; extra=""; w=dry ;;
    wet-adG2) rec=long-wet; extra="TRAIT_REL=a_dG2=0.25"; w=long-wet ;;
    ld-102) rec=long-drought; extra="SEED=102"; w=long-drought ;;
    ld-105) rec=long-drought; extra="SEED=105"; w=long-drought ;;
    *) rec=$cs; extra=""; w=$cs ;;
  esac
  case $rule in @*) rule=$(grep "^$cs " $SU/sched/rule_${rule#@}.txt | cut -d' ' -f2) ;; esac
  name=${nm}_$cs; grep -q "^start $name " $SU/queue.out 2>/dev/null && return 0
  # At most `maxr` of these runs at once, across every queue; none starts while `hold` exists.
  exec 9>$SU/.lock
  while true; do flock 9
    n=$(( $(grep -c '^start ' $SU/queue.out) - $(grep -c '^done ' $SU/queue.out) ))
    mx=$(cat $SU/maxr 2>/dev/null || echo 2)
    if [ ! -e $SU/hold ] && [ $n -lt $mx ]; then
      echo "start $name $(date +%T) rule=${rule:0:40} lib=$lib $*" >> $SU/queue.out; flock -u 9; break; fi
    flock -u 9; sleep 5; done
  s0=$(date +%s)
  env REGIME=$rec ATOL=1e-4 WEIGHT_SOIL=10 WEIGHT_MAX=100 HMAX=15 SHARE=0.1 SPLIT=1 OUT=$SU/runs/$name.rds \
    TIMES=$SU/sched/${sc}_$cs.rds WEIGHT=$DEV/window/rule_A/weight_$w.rds TOL=1e-4 LIB=$SU/build/$lib KNOTS=0 \
    PLANT_SIMPSON=$rule $extra "$@" \
    Rscript $A/adj_run_nk.R > $SU/logs/$name.log 2>&1
  st=$?
  echo "done $name $st $(date +%T) wall $(( $(date +%s) - s0 ))" >> $SU/queue.out; }
export -f one; export A DEV SU
grep -v '^#' "$1" | grep -v '^ *$' | xargs -P ${P:-2} -I{} bash -c 'one "{}"'
echo "jobs done $1 $(date +%T)" >> $SU/queue.out
