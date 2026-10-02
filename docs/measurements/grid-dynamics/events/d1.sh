#!/bin/bash
# Where the quintic split's frozen structure stops being smooth: the frozen arm
# at lma (1 +- 1e-5) again, now keeping every split's crossing, to set against
# the base run's.
E=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/events
source $E/run.sh
OFF="TF24_DOMAIN_TOL=1e9"
SPLIT="LOCAL=1 MEMBER=1 EVENT_ETA=1e-10 DENSE=quintic"
while pgrep -f "R --no-echo --no-restore --file=.*scratchpad/dev/events/" > /dev/null; do sleep 10; done
for r in 1e-5 -1e-5; do
  run dq_lma_$r $NEW $LIB TOL=1e-4 PROGRAM=$R/g_1e-4.rds $OFF $SPLIT THETA=lma THETA_ALONE=1 THETA_REL=$r STRUCTURE=$R/slq_1e-4.rds SPLIT_LOG=$R/sldq_lma_$r.rds
done
echo "d1 finished"
