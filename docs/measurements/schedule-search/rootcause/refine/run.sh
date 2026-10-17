#!/bin/bash
# run.sh JOB [JOB...], JOB = KIND/NAME/CASE/TOL, at most P (default 3) at a time, none started
# while MAXR (default 4) R processes run.
#   map    adj_run_dwr.R MODE=map on the scratch build (libS + node_drop.patch), the E6
#          committed setting; TIMES sched/NAME.rds, COARSE sched/NAME_coarse.rds
#   plain  the same build and setting, no map
#   ref    adj_run_nk.R on adjmap/lib, knots as stops, NAME = uNNN uniform nodes (the
#          held-out reference recipe)
# Output runs/NAME.rds (ref: runs/ref_CASE_NAME.rds); "done RC NAME" in queue.out.
O=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/refine
DEV=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev
A=$DEV/schedtest/adjmap
H=/home/user/plant-dev/docs/measurements/schedule-search/rootcause
one() { IFS=/ read kind name cs tol <<< "$1"; seed=""; trait=""
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
  out=$name; [ "$kind" = ref ] && out=ref_${cs}_$name
  grep -q "^done 0 $out " $O/queue.out 2>/dev/null && [ -s $O/runs/$out.rds ] && return 0
  exec 9>$O/.gate.lock; flock 9
  nr() { local n=0; for p in $(pgrep -f "R --|Rscript|exec/R"); do c=$(ps -o comm= -p $p 2>/dev/null); case "$c" in R|Rscript) n=$((n + 1)) ;; esac; done; echo $n; }
  while [ $(nr) -ge ${MAXR:-4} ]; do sleep $((10 + RANDOM % 10)); done
  echo "start $out $(date +%T) (R procs $(nr); $(df -h / | awk 'NR==2{print $4}') free)" >> $O/queue.out
  common="REGIME=$rec ${seed:+SEED=$seed} ${trait:+TRAIT_REL=$trait} ATOL=1e-4 WEIGHT_SOIL=10 WEIGHT=$DEV/window/rule_A/weight_$w.rds WEIGHT_MAX=100 HMAX=15 SHARE=0.1 SPLIT=1"
  case $kind in
    map)   env $common TOL=$tol KNOTS=0 LIB=$O/build/lib TIMES=$O/sched/$name.rds COARSE=$O/sched/${name}_coarse.rds MODE=map \
             OUT=$O/runs/$out.rds Rscript $H/dwr/adj_run_dwr.R > $O/logs/$out.log 2>&1 & ;;
    plain) env $common TOL=$tol KNOTS=0 LIB=$O/build/lib TIMES=$O/sched/$name.rds MODE=plain \
             OUT=$O/runs/$out.rds Rscript $H/dwr/adj_run_dwr.R > $O/logs/$out.log 2>&1 & ;;
    ref)   env $common TOL=$tol LIB=$A/lib NODES=${name#u} OUT=$O/runs/$out.rds \
             Rscript $A/adj_run_nk.R > $O/logs/$out.log 2>&1 & ;;
  esac
  pid=$!; sleep 10; flock -u 9; wait $pid; rc=$?
  echo "done $rc $out $(date +%T)" >> $O/queue.out; }
export -f one; export O DEV A H MAXR
printf "%s\n" "$@" | xargs -P ${P:-3} -I{} bash -c 'one {}'
