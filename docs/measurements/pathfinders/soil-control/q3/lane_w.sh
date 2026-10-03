#!/bin/bash
# Runs queue_w.txt's lines (NAME RECORD [VAR=value ...]) through drv_w2.sh, each started once
# fewer than four heavy R processes run.
M=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/pf_soil/mr
while read -r name rec args; do
  [ -z "$name" ] || [ "${name:0:1}" = "#" ] && continue
  [ -f "$M/runs/$name.rds" ] && continue
  while [ "$(pgrep -fc 'harness[_a-z]*/(run_record|ark_prototype)[.]R')" -ge 4 ]; do sleep 15; done
  bash $M/drv_w2.sh "$name" "$rec" $args
done < "$M/queue_w.txt"
echo "lane_w finished $(date +%T)" >> $M/queue.out
