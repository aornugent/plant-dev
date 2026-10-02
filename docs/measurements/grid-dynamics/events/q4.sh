#!/bin/bash
# Stage 3, its differences at r = 1e-6. At r = 1e-5 on the 1e-4 grid both arms
# straddle a non-smooth point in lma: a crossing passing a stage (plain) and
# one leaving its frozen step, where the frozen structure is continuous but not
# C1 (one dip vanishes inside +1e-5). So: the head of q3 (the quintic adaptive
# forward, lma's chord on the quintic's frozen structure, the quintic split
# re-detected at +-1e-4); at 1e-4 the r = 1e-6 differences against reverse mode
# and against r = 1e-5; then the six nudges at r = 1e-6.
E=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/events
source $E/run.sh
OFF="TF24_DOMAIN_TOL=1e9"
SPLIT="LOCAL=1 MEMBER=1 EVENT_ETA=1e-10 DENSE=quintic"
G=$R/g_1e-4.rds
while pgrep -f "R --no-echo --no-restore --file=.*scratchpad/dev/events/" > /dev/null; do sleep 15; done
run gaq_1e-4 $NEW $LIB TOL=1e-4 LOCAL=1 MEMBER=1 EVENT_ETA=1e-10 DENSE=quintic OUT=$R/gaq_1e-4.rds
for r in 1e-4 -1e-4 1e-3 -1e-3 1e-5 -1e-5 1e-2 -1e-2 1e-6 -1e-6; do
  run fq_lma_$r $NEW $LIB TOL=1e-4 PROGRAM=$G $OFF $SPLIT THETA=lma THETA_ALONE=1 THETA_REL=$r STRUCTURE=$R/slq_1e-4.rds
done
for r in 1e-6 -1e-6; do
  run rp_lma_$r $NEW $LIB TOL=1e-4 PROGRAM=$G $OFF THETA=lma THETA_ALONE=1 THETA_REL=$r
done
for r in 1e-4 -1e-4; do
  run sq_lma_$r $NEW $LIB TOL=1e-4 PROGRAM=$G $OFF $SPLIT THETA=lma THETA_ALONE=1 THETA_REL=$r SPLIT_LOG=$R/slq_lma_$r.rds
done
ad() {
  local T=$1
  if ! grep -q "elasticity d_I" $R/ad_$T.log 2>/dev/null; then
    ( cd $E && env PLANT_LIB=$V12T TOL=$T OUT=$R/ad_$T.rds nice Rscript $E/ad_check.R ) > $R/ad_$T.log 2>&1
  fi
  echo "done ad_$T: $(head -1 $R/ad_$T.log)"
}
# 1e-4: the pool traits at r = 1e-6 on both arms, and a_dG1 at r = 1e-5 too.
T=1e-4
for trait in a_dG1 d_I a_dG2; do
  rs="1e-6 -1e-6"; [ "$trait" = a_dG1 ] && rs="1e-6 -1e-6 1e-5 -1e-5"
  for r in $rs; do
    run rp_${T}_${trait}_$r $NEW $LIB TOL=$T PROGRAM=$G $OFF THETA=$trait THETA_ALONE=1 THETA_REL=$r
    run fq_${T}_${trait}_$r $NEW $LIB TOL=$T PROGRAM=$G $OFF $SPLIT THETA=$trait THETA_ALONE=1 THETA_REL=$r STRUCTURE=$R/slq_$T.rds
  done
done
for T in 9.5e-5 1.05e-4 9.7e-5 1.03e-4 9.85e-5 1.015e-4; do
  run g_$T $NEW $LIB TOL=$T OUT=$R/g_$T.rds
  run spq_$T $NEW $LIB TOL=$T PROGRAM=$R/g_$T.rds $OFF $SPLIT SPLIT_LOG=$R/slq_$T.rds
  ad $T
  for trait in a_dG1 d_I a_dG2 lma; do
    for r in 1e-6 -1e-6; do
      run fq_${T}_${trait}_$r $NEW $LIB TOL=$T PROGRAM=$R/g_$T.rds $OFF $SPLIT THETA=$trait THETA_ALONE=1 THETA_REL=$r STRUCTURE=$R/slq_$T.rds
    done
  done
done
echo "q4 finished"
