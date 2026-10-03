#!/bin/bash
# After q4: where the field errors sit (kinked against smooth non-crossing
# members) on the CK and DP grids at 1e-4.
source /tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/phase1b/run.sh
E=$P/events
CKG=$DEV/events/runs
until grep -q "q4 finished" $R/q4.out 2>/dev/null; do sleep 20; done
script dk_ck_1e-4 $E dense_check3.R $PROBE METHOD=ck TOL=1e-4 GRID=$CKG/g_1e-4.rds OUT=$R/dk_ck_1e-4.rds
script dk_dp_1e-4 $E dense_check3.R $PROBE METHOD=dp TOL=1e-4 GRID=$R/g_dp_1e-4.rds OUT=$R/dk_dp_1e-4.rds
echo "q5 finished"
