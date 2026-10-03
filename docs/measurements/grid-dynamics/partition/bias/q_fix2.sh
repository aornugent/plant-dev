#!/bin/bash
# After q_lock2.sh: the fix at member tol 1e-6 with the soil's tolerance tied to
# it, so that neither error outside the member norm is held fixed.
B=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/partition_bias
until grep -q "=== lock_true_ref1e-7 end" $B/logs/runs.log; do sleep 10; done
$B/run.sh fix_sld_1e-6_s1e-6 split_stepper_fix.R TOL=1e-6 SOIL_TOL=1e-6 COUPLING=stagelin DEFECT=1 CNORM=1
