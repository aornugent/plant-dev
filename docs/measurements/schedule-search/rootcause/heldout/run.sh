#!/bin/bash
# run.sh: the held-out round, one R process at a time, waiting while more than 3 others run.
#   pilots  run_record.R forward, 54 uniform nodes, 3e-5 (the bank's pilot setting, with splits)
#   E6      adj_run_nk.R on libS, KNOTS=0, 1e-4: committed (c) and check (f) schedules
#   refs    adj_run_nk.R on lib, knots as stops, 3e-5, uniform 215 and 429 nodes
#           (one_nk.sh's environment: the bank's held-out reference recipe)
# Usage: bash run.sh [case ...]
A=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap
DEV=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev
O=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/heldout
D=/home/user/plant-dev/docs/measurements/schedule-search/rootcause/heldout
H=/home/user/plant-dev
CASES=${@:-dry-lma125 flat-al1125 wet-lma08 wet-hmat125 epi-hmat08 epi-adG208 ld104-p50125 ld107-adG2125}
gate() { while [ "$(pgrep -c -f 'R --|Rscript|exec/R')" -gt 3 ]; do sleep 30; done; }
log() { echo "$1 $2 $(date +%T) $(df -h / | awk 'NR==2{print $4}') free" >> $O/queue.out; }
spec() { case $1 in
    dry-lma125)    rec=dry;          seed=31;  tr=lma=0.25;      w=dry ;;
    flat-al1125)   rec=dry-flat;     seed=31;  tr=a_l1=0.25;     w=dry ;;
    wet-lma08)     rec=long-wet;     seed=31;  tr=lma=-0.2;      w=long-wet ;;
    wet-hmat125)   rec=long-wet;     seed=31;  tr=hmat=0.25;     w=long-wet ;;
    epi-hmat08)    rec=episodic;     seed=31;  tr=hmat=-0.2;     w=episodic ;;
    epi-adG208)    rec=episodic;     seed=31;  tr=a_dG2=-0.2;    w=episodic ;;
    ld104-p50125)  rec=long-drought; seed=104; tr=root_P50=0.25; w=long-drought ;;
    ld107-adG2125) rec=long-drought; seed=107; tr=a_dG2=0.25;    w=long-drought ;;
  esac; }
common() { echo REGIME=$rec SEED=$seed TRAIT_REL=$tr ATOL=1e-4 WEIGHT_SOIL=10 WEIGHT=$DEV/window/rule_A/weight_$w.rds WEIGHT_MAX=100 HMAX=15 SHARE=0.1 SPLIT=1; }
pilot() { spec $1; name=pilot_$1
  [ -s $O/runs/$name.rds ] && grep -q "failures;" $O/logs/$name.log && return 0
  gate; log start $name
  (cd $H && env PLANT_LIB=$DEV/lib_109 $(common) TOL=3e-5 NODES=54 FORWARD=1 OUT=$O/runs/$name.rds \
    Rscript harness/run_record.R > $O/logs/$name.log 2>&1)
  log "done $?" $name; }
e6() { spec $1; name=e6_$2_$1
  grep -q "^done 0 $name " $O/queue.out 2>/dev/null && return 0
  [ -s $O/sched/$2_$1.rds ] || { log "nosched" $name; return 1; }
  gate; log start $name
  env $(common) TOL=1e-4 LIB=$A/libS KNOTS=0 TIMES=$O/sched/$2_$1.rds OUT=$O/runs/$name.rds \
    Rscript $A/adj_run_nk.R > $O/logs/$name.log 2>&1
  log "done $?" $name; }
ref() { spec $1; name=ref_$1_u$2
  grep -q "^done 0 $name " $O/queue.out 2>/dev/null && return 0
  gate; log start $name
  env $(common) TOL=3e-5 LIB=$A/lib NODES=$2 OUT=$O/runs/$name.rds \
    Rscript $A/adj_run_nk.R > $O/logs/$name.log 2>&1
  log "done $?" $name; }
for cs in $CASES; do pilot $cs; done
gate; Rscript $D/mk_sched.R > $O/mk_sched.log 2>&1; log "done $?" mk_sched
for cs in $CASES; do e6 $cs c; e6 $cs f; ref $cs 215; ref $cs 429; done
log "all done" heldout
