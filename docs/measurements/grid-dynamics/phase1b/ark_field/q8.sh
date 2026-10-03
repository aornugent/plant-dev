#!/bin/bash
# The split's field on phase 1a's ARK grids (arkc: METHOD=ark TOL_SOIL=100,
# soil estimate from the chain alone), 3e-5 first, then 1e-4. lib_v12t, as arkc.
source /tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/phase1b/run.sh
E=$P/events
G=$DEV/phase1a/t2/runs
for T in 3e-5 1e-4; do
  script dca_$T $E dense_check_ark.R $V12T METHOD=ark TOL=$T TOL_SOIL=100 GRID=$G/arkc_$T.rds OUT=$R/dca_$T.rds
done
echo "q8 finished"
