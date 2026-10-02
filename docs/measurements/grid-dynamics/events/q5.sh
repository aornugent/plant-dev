#!/bin/bash
# Stage 3 at r = 1e-3. J(theta) on the driver carries a floating-point floor of
# about 2e-8 in ln J (4e-8 with the split), so a central difference over +-r
# has that over 2r of noise: at 1e-6 it swamps every pool trait, at 1e-3 it is
# under 0.12 eps/3 for d_I and far less for the rest, and the quintic split's
# frozen structure is smooth at that scale (its one-sided slopes differ by r H).
# The plain arm is reverse mode on lib_v12t at every tolerance; at 1e-4 the
# split arm is also taken at r = 1e-4 and the plain arm by differences at 1e-3,
# and a_dG1's plain difference at 1e-3 is taken at every tolerance as the
# control for what a difference this wide does to a plain gradient by itself.
E=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/events
source $E/run.sh
OFF="TF24_DOMAIN_TOL=1e9"
SPLIT="LOCAL=1 MEMBER=1 EVENT_ETA=1e-10 DENSE=quintic"
G=$R/g_1e-4.rds
while pgrep -f "R --no-echo --no-restore --file=.*scratchpad/dev/events/" > /dev/null; do sleep 15; done
run sq_lma_-1e-4 $NEW $LIB TOL=1e-4 PROGRAM=$G $OFF $SPLIT THETA=lma THETA_ALONE=1 THETA_REL=-1e-4 SPLIT_LOG=$R/slq_lma_-1e-4.rds
ad() {
  local T=$1
  if ! grep -q "elasticity d_I" $R/ad_$T.log 2>/dev/null; then
    ( cd $E && env PLANT_LIB=$V12T TOL=$T OUT=$R/ad_$T.rds nice Rscript $E/ad_check.R ) > $R/ad_$T.log 2>&1
  fi
  echo "done ad_$T: $(head -1 $R/ad_$T.log)"
}
T=1e-4
for trait in a_dG1 d_I a_dG2; do
  for r in 1e-3 -1e-3; do
    run fq_${T}_${trait}_$r $NEW $LIB TOL=$T PROGRAM=$G $OFF $SPLIT THETA=$trait THETA_ALONE=1 THETA_REL=$r STRUCTURE=$R/slq_$T.rds
    run rp_${T}_${trait}_$r $NEW $LIB TOL=$T PROGRAM=$G $OFF THETA=$trait THETA_ALONE=1 THETA_REL=$r
  done
  for r in 1e-4 -1e-4; do
    run fq_${T}_${trait}_$r $NEW $LIB TOL=$T PROGRAM=$G $OFF $SPLIT THETA=$trait THETA_ALONE=1 THETA_REL=$r STRUCTURE=$R/slq_$T.rds
  done
done
for T in 9.5e-5 1.05e-4 9.7e-5 1.03e-4 9.85e-5 1.015e-4; do
  run g_$T $NEW $LIB TOL=$T OUT=$R/g_$T.rds
  run spq_$T $NEW $LIB TOL=$T PROGRAM=$R/g_$T.rds $OFF $SPLIT SPLIT_LOG=$R/slq_$T.rds
  ad $T
  for trait in a_dG1 d_I a_dG2 lma; do
    for r in 1e-3 -1e-3; do
      run fq_${T}_${trait}_$r $NEW $LIB TOL=$T PROGRAM=$R/g_$T.rds $OFF $SPLIT THETA=$trait THETA_ALONE=1 THETA_REL=$r STRUCTURE=$R/slq_$T.rds
    done
  done
  for r in 1e-3 -1e-3; do
    run rp_${T}_a_dG1_$r $NEW $LIB TOL=$T PROGRAM=$R/g_$T.rds $OFF THETA=a_dG1 THETA_ALONE=1 THETA_REL=$r
  done
done
echo "q5 finished"
