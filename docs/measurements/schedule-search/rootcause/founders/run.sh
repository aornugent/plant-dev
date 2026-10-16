#!/bin/bash
# run.sh TAG [CASE ...]: the E6 committed runs' setting (libS, no knot stops, 1e-4,
# one_nk.sh's environment, each case's weight, seed and trait move as in jobs_insk.txt)
# with only TIMES changed to sched/TAG_CASE.rds. P at a time (default 2). EXTRA adds env settings.
A=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap
DEV=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev
FO=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/founders
RUNNER=${RUNNER:-$A/adj_run_nk.R}
TAG=$1; shift
one() { cs=$1; case $cs in
    episodic-lma) rec=episodic; extra="TRAIT_REL=lma=0.25"; w=episodic ;;
    dry-p50) rec=dry; extra="TRAIT_REL=root_P50=0.2"; w=dry ;;
    dry-flat) rec=dry-flat; extra=""; w=dry ;;
    wet-adG2) rec=long-wet; extra="TRAIT_REL=a_dG2=0.25"; w=long-wet ;;
    ld-102) rec=long-drought; extra="SEED=102"; w=long-drought ;;
    ld-105) rec=long-drought; extra="SEED=105"; w=long-drought ;;
    *) rec=$cs; extra=""; w=$cs ;;
  esac
  name=${TAG}_$cs; [ -s $FO/runs/$name.rds ] && return 0
  echo "start $name $(date +%T)" >> $FO/queue.out
  env REGIME=$rec ATOL=1e-4 WEIGHT_SOIL=10 WEIGHT_MAX=100 HMAX=15 SHARE=0.1 SPLIT=1 OUT=$FO/runs/$name.rds \
    TIMES=$FO/sched/${TAG}_$cs.rds WEIGHT=$DEV/window/rule_A/weight_$w.rds TOL=1e-4 LIB=$A/libS KNOTS=0 $extra $EXTRA \
    Rscript $RUNNER > $FO/logs/$name.log 2>&1
  echo "done $name $? $(date +%T)" >> $FO/queue.out; }
export -f one; export A DEV FO TAG RUNNER EXTRA
printf "%s\n" "$@" | xargs -P ${P:-2} -I{} bash -c 'one {}'
echo "all done $TAG $(date +%T)" >> $FO/queue.out
