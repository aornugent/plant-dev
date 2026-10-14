#!/bin/bash
# run.sh NAME PIN [VAR=value ...]: probe.R on a saved dry run's pinned steps; output JT_out/NAME.{rds,log}.
S=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest
O=$S/JT_out; mkdir -p $O
name=$1; pin=$2; shift 2
env PIN=$pin OUT=$O/$name.rds "$@" Rscript /home/user/plant-dev/docs/measurements/schedule-search/round4/JT/probe.R > $O/$name.log 2>$O/$name.err
echo "done $name $?" >> $O/queue.out
