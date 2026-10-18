#!/bin/bash
# fr_run.sh: the frontier's real runs on libNS, one R process at a time (pre-registration F).
SP=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad
LIB=$SP/dev/ns/libNS; O=$SP/frontier/ns; D=/home/user/plant-dev/docs/measurements/schedule-search/rootcause/refine2
mkdir -p $O
until tail -n 3 $SP/dev/ns/install.log | grep -q "exit 0"; do sleep 30; done
run() { echo "start $1 $(date +%T)" >> $O/queue.log
  (cd /home/user/plant-dev && PLANT_LIB=$LIB Rscript $D/fr_run.R $1 $O $2 > $O/$1.log 2>&1)
  echo "done $? $1 $(date +%T)" >> $O/queue.log; }
run dry-lma125 1:1e-4,0.7:1e-4
run ld104-p50125 1:1e-4,0.7:1e-4
run episodic 1:1e-4,0.7:1e-4
run episodic-lma 1:1e-4,1:3e-4
echo "all done $(date +%T)" >> $O/queue.log
