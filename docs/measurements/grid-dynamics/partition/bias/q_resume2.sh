#!/bin/bash
# After the second restart: the fix at a third tolerance (3e-5, the quickest),
# decisive run (b) on the whole run at two tolerances, decisive run (a), then the
# fix at 1e-6. Each run is skipped if its log already exists (run.sh refuses).
B=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/partition_bias
REC=$B/out/rec_1e-7.rds
P=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/split/out/mono_3e-5.rds
$B/run.sh fix_sld_3e-5 split_stepper_fix.R TOL=3e-5 SOIL_TOL=3e-5 COUPLING=stagelin DEFECT=1 CNORM=1
$B/run.sh full_rec_1e-4 split_stepper_rec.R TOL=1e-4 SOIL_TOL=3e-5 COUPLING=rec REC=$REC
$B/run.sh full_rec_1e-5 split_stepper_rec.R TOL=1e-5 SOIL_TOL=3e-5 COUPLING=rec REC=$REC
$B/run.sh lock_true_mono3e-5 split_stepper_lock.R TOL=3e-5 SOIL_TOL=3e-5 COUPLING=lock LOCK_UP=true PROGRAM=$P
$B/run.sh fix_sld_1e-6_r2 split_stepper_fix.R TOL=1e-6 SOIL_TOL=3e-5 COUPLING=stagelin DEFECT=1 CNORM=1
$B/run.sh lock_helddef_mono3e-5 split_stepper_lock.R TOL=3e-5 SOIL_TOL=3e-5 COUPLING=lock LOCK_UP=held DEFECT=1 PROGRAM=$P
