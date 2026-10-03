#!/bin/bash
# Step 1 data: each record's stand and nine walks, one R process at a time.
D=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev
P=$D/pf_thin
cd $P || exit 1
mkdir -p runs
wait_load() { while awk '{exit !($1 >= 4)}' /proc/loadavg; do sleep 30; done; }
for r in long-drought episodic long-wet; do
  [ -f runs/walks_$r.done ] && continue
  wait_load
  echo "start $r $(date +%T)" >> queue.out
  env PLANT_LIB=$D/lib_sw REGIME=$r OUT=runs/walks_$r.rds nice -n 10 Rscript walks.R > runs/walks_$r.log 2>&1 && touch runs/walks_$r.done
  echo "done $r $(date +%T)" >> queue.out
done
echo "queue1 finished $(date +%T)" >> queue.out
