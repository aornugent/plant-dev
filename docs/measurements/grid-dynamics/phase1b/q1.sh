#!/bin/bash
# Stage 1: Dormand-Prince on the driver at three tolerances (lib_v12t, tied
# tolerance), and Cash-Karp at 1e-4 through the patched driver against the
# recording it must reproduce bit for bit.
source /tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/phase1b/run.sh
H=$P/harness
run dp_1e-4 $H $V12T METHOD=dp TOL=1e-4 OUT=$R/dp_1e-4.rds
run ck_1e-4_check $H $V12T METHOD=ck TOL=1e-4 OUT=$R/ck_1e-4_check.rds REF=$DEV/events/runs/v0_1e-4.rds
run dp_3e-5 $H $V12T METHOD=dp TOL=3e-5 OUT=$R/dp_3e-5.rds
run dp_1e-5 $H $V12T METHOD=dp TOL=1e-5 OUT=$R/dp_1e-5.rds
echo "q1 finished"
