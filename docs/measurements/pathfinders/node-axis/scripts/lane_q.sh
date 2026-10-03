#!/bin/bash
# Takes jobs_next.txt's first untaken line (run1.sh's arguments) whenever fewer than four
# heavy R processes run, marks it taken, and runs it; ends when none is left or STOP exists.
N=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/pf_nodes
exec 9> $N/jobs.lock
while [ ! -f $N/STOP ]; do
  flock 9
  if [ "$(pgrep -fc 'harness/(run_record|ark_prototype)[.]R')" -ge 4 ]; then flock -u 9; sleep 30; continue; fi
  job=$(grep -m1 -v '^#' $N/jobs_next.txt)
  if [ -z "$job" ]; then flock -u 9; break; fi
  sed -i "0,/^[^#]/s/^\([^#]\)/# taken $(date +%T) \1/" $N/jobs_next.txt
  bash $N/run1.sh $job &
  pid=$!
  sleep 15
  flock -u 9
  wait $pid
done
echo "lane_q ended $(date +%T)" >> $N/queue.out
