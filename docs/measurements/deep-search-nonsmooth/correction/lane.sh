#!/bin/bash
# lane.sh TRAIT: for A then B, the pinned up/dn trajectories along TRAIT (traj.sh), c per
# switch step (cG.R) into deep/correction/c/TRAIT_RUN.rds, then the trajectories deleted.
C=/home/user/plant-dev/docs/measurements/deep-search-nonsmooth/correction
D=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/correction
tr=$1
for run in A B; do
  [ -f $D/c/${tr}_$run.rds ] && continue
  $C/traj.sh $tr $run $D/traj
  Rscript $C/cG.R $tr $run $D/traj/${tr}_${run}_up.rds $D/traj/${tr}_${run}_dn.rds $D/c/${tr}_$run.rds > $D/c/${tr}_$run.log 2>&1
  [ -f $D/c/${tr}_$run.rds ] && rm -f $D/traj/${tr}_${run}_up.rds $D/traj/${tr}_${run}_dn.rds
done
echo "done $tr $(date +%T)" >> $D/queue.out
