#!/bin/bash
# After stage 1, one R process at a time: the single- against whole-evaluation
# timing; the stand's reverse-mode gradient on the 1e-4 grid; the dense output's
# error on crossing steps, and J with the crossing steps halved and quartered,
# plain and split; then the chord (stage 2) and the nudges (stage 3).
E=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/events
source $E/run.sh
OFF="TF24_DOMAIN_TOL=1e9"
SPLIT="LOCAL=1 MEMBER=1 EVENT_ETA=1e-10"
until grep -q "q1 finished" $E/runs/q1.out 2>/dev/null; do sleep 20; done
[ -s $E/runs/bench.log ] || ( cd $E && nice Rscript $E/bench.R > $E/runs/bench.log 2>&1 )
echo "done bench"
if ! grep -q "elasticity d_I" $E/runs/ad_1e-4.log 2>/dev/null; then
  ( cd $E && env PLANT_LIB=$E/lib TOL=1e-4 OUT=$E/runs/ad_1e-4.rds nice Rscript $E/ad_check.R ) > $E/runs/ad_1e-4.log 2>&1
fi
echo "done ad_1e-4: $(head -1 $E/runs/ad_1e-4.log)"
[ -s $E/runs/dense_check.log ] || ( cd $E && nice Rscript $E/dense_check.R > $E/runs/dense_check.log 2>&1 )
echo "done dense_check"
for n in 1 2 4; do
  run rp_h$n $NEW $LIB TOL=1e-4 PROGRAM=$R/g_1e-4.rds $OFF SPLIT_ROWS=$R/sl_1e-4.rds SPLIT=$n OUT=$R/rp_h$n.rds
  run sp_h$n $NEW $LIB TOL=1e-4 PROGRAM=$R/g_1e-4.rds $OFF SPLIT_ROWS=$R/sl_1e-4.rds SPLIT=$n $SPLIT OUT=$R/sp_h$n.rds SPLIT_LOG=$R/sl_h$n.rds
done
bash $E/q2.sh
bash $E/q3.sh
