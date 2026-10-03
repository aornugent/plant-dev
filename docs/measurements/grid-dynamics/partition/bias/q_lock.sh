#!/bin/bash
# Decisive run (a): the member steps pinned to the monolithic run's at 3e-5
# (PROGRAM), one soil step per member step on the same tableau (COUPLING=lock):
# the soil's stage uptake the member stage's own (the coupled step itself), then
# the hold at t with the defect correction.
B=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/partition_bias
P=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/split/out/mono_3e-5.rds
$B/run.sh lock_true_mono3e-5 split_stepper_lock.R TOL=3e-5 SOIL_TOL=3e-5 COUPLING=lock LOCK_UP=true PROGRAM=$P
$B/run.sh lock_helddef_mono3e-5 split_stepper_lock.R TOL=3e-5 SOIL_TOL=3e-5 COUPLING=lock LOCK_UP=held DEFECT=1 PROGRAM=$P
