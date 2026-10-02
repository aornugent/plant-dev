#!/bin/bash
# Stage 2: lma's chord on the 1e-4 grid at r = 1e-4, 1e-3, 1e-5, 1e-2, three
# ways: plain (rp), the split with its crossings re-detected at each lma (sp),
# and the split on the base run's structure (fp). fp_0 checks that the frozen
# structure at lma itself reproduces the split's J.
source /tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/events/run.sh
OFF="TF24_DOMAIN_TOL=1e9"
SPLIT="LOCAL=1 MEMBER=1 EVENT_ETA=1e-10"
G=$R/g_1e-4.rds
S=$R/sl_1e-4.rds
# The split reading its field from the quintic through the step's midpoint,
# against the cubic through its ends: does the split's own move of J go?
run spq_1e-4 $NEW $LIB TOL=1e-4 PROGRAM=$G $OFF $SPLIT DENSE=quintic SPLIT_LOG=$R/slq_1e-4.rds OUT=$R/spq_1e-4.rds
run spq_3e-5 $NEW $LIB TOL=3e-5 PROGRAM=$R/g_3e-5.rds $OFF $SPLIT DENSE=quintic
run fp_0 $NEW $LIB TOL=1e-4 PROGRAM=$G $OFF $SPLIT STRUCTURE=$S
for r in 1e-4 -1e-4 1e-3 -1e-3 1e-5 -1e-5 1e-2 -1e-2; do
  run rp_lma_$r $NEW $LIB TOL=1e-4 PROGRAM=$G $OFF THETA=lma THETA_ALONE=1 THETA_REL=$r
  run sp_lma_$r $NEW $LIB TOL=1e-4 PROGRAM=$G $OFF $SPLIT THETA=lma THETA_ALONE=1 THETA_REL=$r SPLIT_LOG=$R/sl_lma_$r.rds CROSS_LOG=$R/cl_sp_lma_$r.rds
  run fp_lma_$r $NEW $LIB TOL=1e-4 PROGRAM=$G $OFF $SPLIT THETA=lma THETA_ALONE=1 THETA_REL=$r STRUCTURE=$S
done
echo "q2 finished"
