#!/bin/bash
# The fix on the whole run: stagelin + defect with the coupling's error in the
# members' norm (CNORM=1) at three member tolerances; then decisive run (b).
B=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/partition_bias
for tol in 1e-4 1e-5 1e-6; do
  $B/run.sh fix_sld_$tol split_stepper_fix.R TOL=$tol SOIL_TOL=3e-5 COUPLING=stagelin DEFECT=1 CNORM=1
done
bash $B/q_rec_full.sh
