#!/bin/bash
# p4lam.sh NAME PIN TOL: the pinned run's sweep on libD printing the state adjoint at
# every step; kept (awk) only at the times in JT_out/P4_tlist_NAME.txt.
S=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest; O=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/JT_out
n=$1; pin=$2; tol=$3
env ODELIA_ADJOINT_TRACE=params ODELIA_TRACE_T0=0 ODELIA_TRACE_T1=41 LIB=$S/libD PIN=$pin TOL=$tol SWEEP=1 OUT=$O/P4_lam_$n.rds \
  Rscript /home/user/plant-dev/docs/measurements/schedule-search/round4/JT/probe.R 2>&1 >$O/P4_lam_$n.log | \
  awk -v f=$O/P4_tlist_$n.txt 'BEGIN{while((getline l < f)>0) keep[l]=1} /^LAMBDA/{t=sprintf("%.9f",$3); if (t in keep) print; next} /^PARAMS/{print; next}' > $O/P4_lam_$n.txt
echo "done $n"
