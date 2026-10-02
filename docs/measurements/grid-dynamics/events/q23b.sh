#!/bin/bash
# The rest of the chain after the dense-output check: the stand's reverse-mode
# gradient on lib_v12t (the probe builds cannot sweep), J with the crossing
# steps cut into 1, 2 and 4, plain and split, then stages 2 and 3. Waits first
# for any of this spike's R runs still going, so one runs at a time.
E=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/events
source $E/run.sh
OFF="TF24_DOMAIN_TOL=1e9"
SPLIT="LOCAL=1 MEMBER=1 EVENT_ETA=1e-10"
while pgrep -f "R --no-echo --no-restore --file=.*scratchpad/dev/events/" > /dev/null; do sleep 15; done
if ! grep -q "elasticity d_I" $E/runs/ad_1e-4.log 2>/dev/null; then
  ( cd $E && env PLANT_LIB=$V12T TOL=1e-4 OUT=$E/runs/ad_1e-4.rds nice Rscript $E/ad_check.R ) > $E/runs/ad_1e-4.log 2>&1
fi
echo "done ad_1e-4: $(head -1 $E/runs/ad_1e-4.log)"
for n in 1 2 4; do
  run rp_h$n $NEW $LIB TOL=1e-4 PROGRAM=$R/g_1e-4.rds $OFF SPLIT_ROWS=$R/sl_1e-4.rds SPLIT=$n OUT=$R/rp_h$n.rds
  run sp_h$n $NEW $LIB TOL=1e-4 PROGRAM=$R/g_1e-4.rds $OFF SPLIT_ROWS=$R/sl_1e-4.rds SPLIT=$n $SPLIT OUT=$R/sp_h$n.rds SPLIT_LOG=$R/sl_h$n.rds
done
bash $E/q2.sh
bash $E/q3.sh
