#!/bin/bash
# Runs a queue file's lines in order, one at a time: NAME RECORD [VAR=value ...]
M=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/pf_soil/mr
while read -r name rec args; do
  [ -z "$name" ] || [ "${name:0:1}" = "#" ] && continue
  [ -f "$M/runs/$name.rds" ] && continue
  bash $M/drv.sh "$name" "$rec" $args
done < "$1"
echo "lane $1 finished $(date +%T)" >> $M/queue.out
