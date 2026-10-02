#!/bin/bash
# Stage 3. First lma's chord on the quintic split's frozen structure (fq), then
# the record's seven tolerances within 5% of 1e-4: each tolerance's plain grid
# (g), the quintic split's J on it with its structure (spq, slq), the plain
# gradient by reverse mode on lib_v12t (ad: the record's own instrument, on the
# driver's grid), and central differences at r = 1e-5 in each trait alone on
# the quintic split's frozen structure (fq). At 1e-4 the plain arm is also taken
# by the driver's differences (rp), which checks the two instruments agree.
source /tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/events/run.sh
OFF="TF24_DOMAIN_TOL=1e9"
SPLIT="LOCAL=1 MEMBER=1 EVENT_ETA=1e-10 DENSE=quintic"
G=$R/g_1e-4.rds
# The adaptive forward with the quintic split in it: its cost in leaf solves.
run gaq_1e-4 $NEW $LIB TOL=1e-4 LOCAL=1 MEMBER=1 EVENT_ETA=1e-10 DENSE=quintic OUT=$R/gaq_1e-4.rds
for r in 1e-4 -1e-4 1e-3 -1e-3 1e-5 -1e-5 1e-2 -1e-2; do
  run fq_lma_$r $NEW $LIB TOL=1e-4 PROGRAM=$G $OFF $SPLIT THETA=lma THETA_ALONE=1 THETA_REL=$r STRUCTURE=$R/slq_1e-4.rds
done
# The quintic split with its crossings re-detected at lma (1 +- 1e-4): the jump a
# vanishing dip or a crossing changing step makes when the field is accurate.
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
for T in 1e-4 9.5e-5 1.05e-4 9.7e-5 1.03e-4 9.85e-5 1.015e-4; do
  run g_$T $NEW $LIB TOL=$T OUT=$R/g_$T.rds
  run spq_$T $NEW $LIB TOL=$T PROGRAM=$R/g_$T.rds $OFF $SPLIT SPLIT_LOG=$R/slq_$T.rds
  ad $T
  for trait in a_dG1 d_I a_dG2 lma; do
    for r in 1e-5 -1e-5; do
      if [ "$trait" = lma ] && [ "$T" = 1e-4 ]; then continue; fi
      if [ "$T" = 1e-4 ]; then
        run rp_${T}_${trait}_$r $NEW $LIB TOL=$T PROGRAM=$R/g_$T.rds $OFF THETA=$trait THETA_ALONE=1 THETA_REL=$r
      fi
      run fq_${T}_${trait}_$r $NEW $LIB TOL=$T PROGRAM=$R/g_$T.rds $OFF $SPLIT THETA=$trait THETA_ALONE=1 THETA_REL=$r STRUCTURE=$R/slq_$T.rds
    done
  done
done
echo "q3 finished"
