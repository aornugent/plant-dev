#!/bin/bash
# The frozen quintic structure with interior dips cut in three: at lma itself
# (must reproduce the split's J bit for bit) and at lma (1 + 1e-5), where the
# base grid's dip merges into one step.
E=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/events
source $E/run.sh
OFF="TF24_DOMAIN_TOL=1e9"
SPLIT="LOCAL=1 MEMBER=1 EVENT_ETA=1e-10 DENSE=quintic"
while pgrep -f "R --no-echo --no-restore --file=.*scratchpad/dev/events/" > /dev/null; do sleep 10; done
run fqd_0 $NEW $LIB TOL=1e-4 PROGRAM=$R/g_1e-4.rds $OFF $SPLIT STRUCTURE=$R/slq_1e-4.rds
run fqd_lma_1e-5 $NEW $LIB TOL=1e-4 PROGRAM=$R/g_1e-4.rds $OFF $SPLIT THETA=lma THETA_ALONE=1 THETA_REL=1e-5 STRUCTURE=$R/slq_1e-4.rds SPLIT_LOG=$R/slfqd_lma_1e-5.rds
echo "d2 finished"
