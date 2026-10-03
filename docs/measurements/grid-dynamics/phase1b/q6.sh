#!/bin/bash
# After q5: the CK quartic's frozen structure replayed at theta itself, which
# must give the split's own J (sp_ck4_1e-4) bit for bit.
source /tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/phase1b/run.sh
E=$P/events
OFF="TF24_DOMAIN_TOL=1e9"
CKG=$DEV/events/runs
until grep -q "q5 finished" $R/q5.out 2>/dev/null; do sleep 20; done
run fq_ck4_1e-4_0 $E $PROBE METHOD=ck TOL=1e-4 PROGRAM=$CKG/g_1e-4.rds $OFF LOCAL=1 MEMBER=1 EVENT_ETA=1e-10 DENSE=ck4 \
  STRUCTURE=$R/sl_ck4_1e-4.rds
echo "q6 finished"
