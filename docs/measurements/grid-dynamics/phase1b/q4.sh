#!/bin/bash
# After the CK quartic's nudges: the cubic and quintic splits on DP's 1e-4 grid
# (J and cost beside DP's contd5). DP's own nudges did not fit the budget.
source /tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/phase1b/run.sh
E=$P/events
OFF="TF24_DOMAIN_TOL=1e9"
SPLIT="LOCAL=1 MEMBER=1 EVENT_ETA=1e-10"
until grep -q "q3b finished" $R/q3b.out 2>/dev/null; do sleep 20; done
run sp_dpq_1e-4 $E $PROBE METHOD=dp TOL=1e-4 PROGRAM=$R/g_dp_1e-4.rds $OFF $SPLIT DENSE=quintic
run sp_dpc_1e-4 $E $PROBE METHOD=dp TOL=1e-4 PROGRAM=$R/g_dp_1e-4.rds $OFF $SPLIT DENSE=cubic
echo "q4 finished"
