#!/bin/bash
# traj.sh TRAIT RUN DIR: run RUN's (A 3e-4, B 2.85e-4) pinned forward at theta(1 +- 1e-4)
# along TRAIT on libJTstop, trajectory kept; writes DIR/TRAIT_RUN_{up,dn}.rds.
S=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest
tr=$1; run=$2; d=$3
case $run in
  A) pin=$S/P_out/runs/P_ins3c_dry.rds; tol=3e-4 ;;
  B) pin=$S/X_out/runs/X_ins3c_2.85e-4_dry.rds; tol=2.85e-4 ;;
esac
for s in up dn; do
  r=1e-4; [ $s = dn ] && r=-1e-4
  env PIN=$pin TOL=$tol LIB=$S/libJTstop TRAIT_REL=$tr=$r SAVETRAJ=1 STOPONLY=1 OUT=$d/${tr}_${run}_$s.rds \
    Rscript /home/user/plant-dev/docs/measurements/deep-search-nonsmooth/correction/traj.R > $d/${tr}_${run}_$s.log 2>&1 || echo "FAIL $tr $run $s" >> $d/../fail.txt
done
