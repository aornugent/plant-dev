#!/bin/bash
# Stage 3 with the frozen structure cutting a dip that lies inside one step in
# three (one sub-step per event interval), so the base grid's dip at the rain
# onset of t = 17.15 no longer makes J jump. Re-takes the 1e-4 grid's split
# points (the earlier ones are kept as *_v1.log), adds lma at r = 3e-4 on both
# arms (a second difference J's 2-4e-8 floor leaves about 1 of noise in, where
# 1e-4 leaves 8-16), then the six nudges at r = 1e-3.
E=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/events
source $E/run.sh
OFF="TF24_DOMAIN_TOL=1e9"
SPLIT="LOCAL=1 MEMBER=1 EVENT_ETA=1e-10 DENSE=quintic"
G=$R/g_1e-4.rds
while pgrep -f "R --no-echo --no-restore --file=.*scratchpad/dev/events/" > /dev/null; do sleep 15; done
ad() {
  local T=$1
  if ! grep -q "elasticity d_I" $R/ad_$T.log 2>/dev/null; then
    ( cd $E && env PLANT_LIB=$V12T TOL=$T OUT=$R/ad_$T.rds nice Rscript $E/ad_check.R ) > $R/ad_$T.log 2>&1
  fi
  echo "done ad_$T: $(head -1 $R/ad_$T.log)"
}
fq() { # T trait r
  local tag=fq_${1}_${2}_$3; [ "$2" = lma ] && [ "$1" = 1e-4 ] && tag=fq_lma_$3
  run $tag $NEW $LIB TOL=$1 PROGRAM=$R/g_$1.rds $OFF $SPLIT THETA=$2 THETA_ALONE=1 THETA_REL=$3 STRUCTURE=$R/slq_$1.rds
}
rp() { # T trait r
  local tag=rp_${1}_${2}_$3; [ "$2" = lma ] && [ "$1" = 1e-4 ] && tag=rp_lma_$3
  run $tag $NEW $LIB TOL=$1 PROGRAM=$R/g_$1.rds $OFF THETA=$2 THETA_ALONE=1 THETA_REL=$3
}
for trait in a_dG1 d_I a_dG2 lma; do for r in 1e-3 -1e-3; do fq 1e-4 $trait $r; done; done
for r in 1e-3 -1e-3; do rp 1e-4 a_dG2 $r; done
for trait in a_dG1 a_dG2 lma; do for r in 1e-4 -1e-4; do fq 1e-4 $trait $r; done; done
for r in 3e-4 -3e-4; do fq 1e-4 lma $r; rp 1e-4 lma $r; done
for r in 1e-2 -1e-2; do fq 1e-4 lma $r; done
for T in 9.5e-5 1.05e-4 9.7e-5 1.03e-4 9.85e-5 1.015e-4; do
  run g_$T $NEW $LIB TOL=$T OUT=$R/g_$T.rds
  run spq_$T $NEW $LIB TOL=$T PROGRAM=$R/g_$T.rds $OFF $SPLIT SPLIT_LOG=$R/slq_$T.rds
  ad $T
  for trait in a_dG1 d_I a_dG2 lma; do for r in 1e-3 -1e-3; do fq $T $trait $r; done; done
  for r in 1e-3 -1e-3; do rp $T a_dG1 $r; done
done
echo "q6 finished"
