#!/bin/bash
# stagelin + defect over the first three legs at three member tolerances, states kept.
B=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/partition_bias
for tol in 1e-4 1e-5 1e-6; do
  $B/run.sh early_sld_$tol split_stepper_orig.R TOL=$tol SOIL_TOL=3e-5 COUPLING=stagelin DEFECT=1 LEGS=3 STATES=$B/out/early_sld_${tol}_states.rds
done
