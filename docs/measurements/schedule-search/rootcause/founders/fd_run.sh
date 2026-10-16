#!/bin/bash
# fd_run.sh CASE TRAIT...: pinned forward runs of the lattice f64 schedule (lib, 3e-5,
# rain knots as stops: the lattice's own setting) at theta*(1 +- 0.01) for each TRAIT,
# and one unperturbed guard. Two at a time.
A=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap
DEV=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev
FO=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/founders
cs=$1; shift
case $cs in episodic-lma) rec=episodic; base="lma=0.25," ;; *) rec=$cs; base="" ;; esac
jobs=("guard:")
for t in "$@"; do jobs+=("$t+:${t}=0.01" "$t-:${t}=-0.01"); done
one() { tag=${1%%:*}; rel=${1#*:}; name=fd_${cs}_$tag; [ -s $FO/runs/$name.rds ] && return 0
  tr="${base}${rel}"; tr=${tr%,}
  env REGIME=$rec TOL=3e-5 ATOL=1e-4 WEIGHT_SOIL=10 WEIGHT=$DEV/window/rule_A/weight_$rec.rds WEIGHT_MAX=100 HMAX=15 SHARE=0.1 SPLIT=1 \
    FORWARD=1 TIMES=$FO/sched/tr64_$cs.rds PIN=$A/runs/lat_${cs}_f64_l70.rds TRAIT_REL="$tr" OUT=$FO/runs/$name.rds \
    Rscript $A/adj_run_nk.R > $FO/logs/$name.log 2>&1
  echo "done $name $? $(date +%T)" >> $FO/queue.out; }
export -f one; export A DEV FO cs rec base
printf "%s\n" "${jobs[@]}" | xargs -P ${P:-2} -I{} bash -c 'one "{}"'
