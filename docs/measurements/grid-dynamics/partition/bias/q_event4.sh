#!/bin/bash
# The first mortality event (legs 1-10): the positive control for stage six read
# late (rec with LATE6=1), and stagelin + defect with the coupling's error in the
# members' norm (CNORM=1) at three member tolerances.
B=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/partition_bias
REC=$B/out/rec_1e-7.rds
$B/run.sh ev_rec_late6_1e-6 split_stepper_rec.R TOL=1e-6 SOIL_TOL=3e-5 COUPLING=rec REC=$REC LATE6=1 LEGS=10 STATES=$B/out/ev_rec_late6_1e-6_states.rds
for tol in 1e-4 1e-5 1e-6; do
  $B/run.sh ev_fix_sld_$tol split_stepper_fix.R TOL=$tol SOIL_TOL=3e-5 COUPLING=stagelin DEFECT=1 CNORM=1 LEGS=10 STATES=$B/out/ev_fix_sld_${tol}_states.rds
done
