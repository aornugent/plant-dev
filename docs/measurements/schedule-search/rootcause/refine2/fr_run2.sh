#!/bin/bash
# fr_run2.sh: after fr_run.sh, dry-lma125's scale-1 schedule at a 5% tolerance nudge and at 3e-5,
# no replay: is its uncovered TF24_cost_scale error step noise, tolerance bias, or neither?
SP=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad
LIB=$SP/dev/ns/libNS; O=$SP/frontier/ns; D=/home/user/plant-dev/docs/measurements/schedule-search/rootcause/refine2
until grep -q "all done" $O/queue.log; do sleep 30; done
echo "start dry-lma125 nudge+3e-5 $(date +%T)" >> $O/queue.log
(cd /home/user/plant-dev && PLANT_LIB=$LIB Rscript $D/fr_run.R dry-lma125 $O 1:1.05e-4:0,1:3e-5:0 > $O/dry-lma125_2.log 2>&1)
echo "done $? dry-lma125 nudge+3e-5; all2 done $(date +%T)" >> $O/queue.log
