#!/bin/bash
# run.sh: layout D and its pinned drop per case, one R process at a time in this lane,
# waiting while four or more R processes run. libS, E6 committed setting, gradient on.
# Usage: bash run.sh case ...
DEV=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev
A=$DEV/schedtest/adjmap
E=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/evidence
gate() { while [ "$(pgrep -c -f 'R --|Rscript|exec/R')" -ge 4 ]; do sleep 20; done; }
log() { echo "$1 $2 $(date +%T) $(df -h / | awk 'NR==2{print $4}') free" >> $E/queue.out; }
spec() { case $1 in
    dry) rec=dry; tr=""; w=dry ;;
    long-wet) rec=long-wet; tr=""; w=long-wet ;;
    episodic-lma) rec=episodic; tr=lma=0.25; w=episodic ;;
  esac; }
one() { spec $1; name=$2_$1; gate; log start $name
  env REGIME=$rec SEED=31 TRAIT_REL=$tr ATOL=1e-4 WEIGHT_SOIL=10 WEIGHT=$DEV/window/rule_A/weight_$w.rds WEIGHT_MAX=100 HMAX=15 SHARE=0.1 SPLIT=1 \
    TOL=1e-4 LIB=$A/libS KNOTS=0 TIMES=$E/sched/$2_$1.rds PIN=$3 OUT=$E/runs/$name.rds \
    Rscript $A/adj_run_nk.R > $E/logs/$name.log 2>&1
  log "done $?" $name; }
for cs in "$@"; do one $cs D ""; one $cs Dd $E/runs/D_$cs.rds; done
log "all done" "$*"
