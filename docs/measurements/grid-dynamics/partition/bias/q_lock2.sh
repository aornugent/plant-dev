#!/bin/bash
# After q_rec3.sh: decisive run (a) on finer pinned steps, the tol 1e-7 reference's
# 34 301: the exact exchange must reproduce that run's J, and held + defect's
# exchange error must fall from its value on the 3e-5 run's 17 684 steps.
B=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/partition_bias
P=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/ark/ck_u108_1e-7.rds
until grep -q "=== full_rec_1e-5_s1e-6 end" $B/logs/runs.log; do sleep 10; done
$B/run.sh lock_helddef_ref1e-7 split_stepper_lock.R TOL=3e-5 SOIL_TOL=3e-5 COUPLING=lock LOCK_UP=held DEFECT=1 PROGRAM=$P
$B/run.sh lock_true_ref1e-7 split_stepper_lock.R TOL=3e-5 SOIL_TOL=3e-5 COUPLING=lock LOCK_UP=true PROGRAM=$P
