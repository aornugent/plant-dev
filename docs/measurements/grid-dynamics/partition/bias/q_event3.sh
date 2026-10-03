#!/bin/bash
# The first mortality event (legs 1-10) with the member step capped at HMAX days,
# on the stepper that lands a capped step within rounding of its target
# (split_stepper_cap.R): stagelin + defect and pc + defect at member tol 1e-6.
B=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/partition_bias
for hm in 2 1 0.5 0.25; do
  $B/run.sh evc_sld_1e-6_h$hm split_stepper_cap.R TOL=1e-6 SOIL_TOL=3e-5 COUPLING=stagelin DEFECT=1 LEGS=10 HMAX=$hm STATES=$B/out/evc_sld_1e-6_h${hm}_states.rds
done
for hm in 1 0.25; do
  $B/run.sh evc_pc1d_1e-6_h$hm split_stepper_cap.R TOL=1e-6 SOIL_TOL=3e-5 COUPLING=pc PC_ITER=1 DEFECT=1 LEGS=10 HMAX=$hm STATES=$B/out/evc_pc1d_1e-6_h${hm}_states.rds
done
