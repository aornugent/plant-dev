#!/bin/bash
# Decisive run (b) on the whole run: the soil's draw read from the tol 1e-7
# monolithic recording while the members keep their own long steps, at three
# member tolerances.
B=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/partition_bias
REC=$B/out/rec_1e-7.rds
for tol in 1e-4 1e-5 1e-6; do
  $B/run.sh full_rec_$tol split_stepper_rec.R TOL=$tol SOIL_TOL=3e-5 COUPLING=rec REC=$REC
done
