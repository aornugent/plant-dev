#!/bin/bash
# queue_w.txt from its end, skipping a run whose rds or log exists, so it meets lane_w.sh
# from the other side; each started once fewer than four heavy R processes run.
M=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/pf_soil/mr
tac "$M/queue_w.txt" | while read -r name rec args; do
  [ -z "$name" ] || [ "${name:0:1}" = "#" ] && continue
  [ -f "$M/runs/$name.rds" ] || [ -f "$M/logs/$name.log" ] && continue
  while [ "$(pgrep -fc 'harness[_a-z]*/(run_record|ark_prototype)[.]R')" -ge 4 ]; do sleep 15; done
  [ -f "$M/logs/$name.log" ] && continue
  bash $M/drv_w2.sh "$name" "$rec" $args
done
echo "lane_w_rev finished $(date +%T)" >> $M/queue.out
