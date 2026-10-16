#!/bin/bash
# h1_run.sh: H1's coarse companions, the E6 committed runs' setting with only TIMES changed
# (one_nk.sh's environment; libS, no knot stops, 1e-4), four at a time.
A=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap
DEV=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev
H1=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/h1
mkdir -p $H1/runs $H1/logs
one() { cs=$1; case $cs in
    episodic-lma) rec=episodic; extra="TRAIT_REL=lma=0.25"; w=episodic ;;
    dry-p50) rec=dry; extra="TRAIT_REL=root_P50=0.2"; w=dry ;;
    dry-flat) rec=dry-flat; extra=""; w=dry ;;
    wet-adG2) rec=long-wet; extra="TRAIT_REL=a_dG2=0.25"; w=long-wet ;;
    ld-102) rec=long-drought; extra="SEED=102"; w=long-drought ;;
    ld-105) rec=long-drought; extra="SEED=105"; w=long-drought ;;
    *) rec=$cs; extra=""; w=$cs ;;
  esac
  name=val_insx_x_$cs; [ -s $H1/runs/$name.rds ] && return 0
  env REGIME=$rec TOL=3e-5 ATOL=1e-4 WEIGHT_SOIL=10 WEIGHT=$DEV/window/rule_A/weight_$rec.rds \
    WEIGHT_MAX=100 HMAX=15 SHARE=0.1 SPLIT=1 OUT=$H1/runs/$name.rds \
    TIMES=$H1/sched/insx_$cs.rds WEIGHT=$DEV/window/rule_A/weight_$w.rds TOL=1e-4 LIB=$A/libS KNOTS=0 $extra \
    Rscript $A/adj_run_nk.R > $H1/logs/$name.log 2>&1
  echo "done $name $? $(date +%T)" >> $H1/queue.out; }
export -f one; export A DEV H1
printf "%s\n" ${@:-long-wet wet-adG2 long-drought ld-102 ld-105 dry-flat episodic dry episodic-lma dry-p50} | xargs -P 4 -I{} bash -c 'one {}'
echo "all done $(date +%T)" >> $H1/queue.out
