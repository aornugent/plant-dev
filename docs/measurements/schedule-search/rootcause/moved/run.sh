#!/bin/bash
# run.sh: each moved case on its parent's E6 committed grid (the committed setting, only
# TIMES changed), one R process at a time, waiting while more than 3 others run.
# First the forward guard G3: episodic-lma on its own grid, forward only.
A=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap
DEV=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev
MV=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/moved
D=/home/user/plant-dev/docs/measurements/schedule-search/rootcause/moved
gate() { while [ "$(pgrep -c -f 'R --|Rscript|exec/R')" -gt 3 ]; do sleep 30; done; }
gate; Rscript $D/prep.R > $MV/logs/prep.log 2>&1
one() { moved=$1 grid=$2 name=$3; shift 3
  case $moved in
    episodic-lma) rec=episodic; tr="lma=0.25" ;;
    dry-p50) rec=dry; tr="root_P50=0.2" ;;
    wet-adG2) rec=long-wet; tr="a_dG2=0.25" ;;
  esac
  [ -s $MV/runs/$name.rds ] && return 0
  gate; echo "start $name $(date +%T)" >> $MV/queue.out
  env "$@" REGIME=$rec ATOL=1e-4 WEIGHT_SOIL=10 WEIGHT_MAX=100 HMAX=15 SHARE=0.1 SPLIT=1 \
    WEIGHT=$DEV/window/rule_A/weight_$rec.rds TOL=1e-4 LIB=$A/libS KNOTS=0 TRAIT_REL=$tr \
    TIMES=$MV/sched/grid_$grid.rds OUT=$MV/runs/$name.rds \
    Rscript $A/adj_run_nk.R > $MV/logs/$name.log 2>&1
  echo "done $name $? $(date +%T)" >> $MV/queue.out; }
one episodic-lma episodic-lma g3_fwd_episodic-lma FORWARD=1
one episodic-lma episodic mv_episodic-lma_on_episodic
one dry-p50 dry mv_dry-p50_on_dry
one wet-adG2 long-wet mv_wet-adG2_on_long-wet
echo "all done $(date +%T)" >> $MV/queue.out
