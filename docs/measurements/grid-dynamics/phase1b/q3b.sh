#!/bin/bash
# Stage 2 (iv) on CK's quartic split, on the spike's seven CK grids (whose plain
# reverse-mode and quintic arms are measured): each tolerance's split replay
# (its SPLIT_LOG the frozen structure), then each trait's elasticity by central
# differences at r = 1e-3 on that structure, traits in the pre-registered order.
source /tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/phase1b/run.sh
E=$P/events
OFF="TF24_DOMAIN_TOL=1e9"
SPLIT="LOCAL=1 MEMBER=1 EVENT_ETA=1e-10 DENSE=ck4"
CKG=$DEV/events/runs
WAIT_FOR=${WAIT_FOR:-q2}
until grep -q "$WAIT_FOR finished" $R/$WAIT_FOR.out 2>/dev/null; do sleep 20; done
# P3 for the quartic: CK's adaptive forward with the split at 1e-4.
run ga_ck4_1e-4 $E $PROBE METHOD=ck TOL=1e-4 $SPLIT OUT=$R/ga_ck4_1e-4.rds
TOLS="1e-4 9.5e-5 1.05e-4 9.7e-5 1.03e-4 9.85e-5 1.015e-4"
for T in $TOLS; do
  run sp_ck4_$T $E $PROBE METHOD=ck TOL=$T PROGRAM=$CKG/g_$T.rds $OFF $SPLIT SPLIT_LOG=$R/sl_ck4_$T.rds
done
for trait in d_I a_dG1 a_dG2 lma; do
  for T in $TOLS; do
    for r in 1e-3 -1e-3; do
      run fq_ck4_${T}_${trait}_$r $E $PROBE METHOD=ck TOL=$T PROGRAM=$CKG/g_$T.rds $OFF $SPLIT \
        THETA=$trait THETA_ALONE=1 THETA_REL=$r STRUCTURE=$R/sl_ck4_$T.rds
    done
  done
done
echo "q3b finished"
