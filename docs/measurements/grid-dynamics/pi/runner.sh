#!/bin/bash
# Runs the lines of queue.txt one at a time ("NAME VAR=value ..."), skipping names
# already in done.txt, and rereads the queue after each run so pending lines can
# be edited. A line starting with # is skipped; a line "STOP" ends the runner.
P=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/pi
touch $P/done.txt
while true; do
  line=""
  while read -r l; do
    [ -z "$l" ] && continue
    case "$l" in \#*) continue ;; esac
    [ "$l" = "STOP" ] && exit 0
    n=${l%% *}
    grep -qx "$n" $P/done.txt && continue
    line=$l; break
  done < $P/queue.txt
  [ -z "$line" ] && exit 0
  n=${line%% *}
  args=${line#* }
  bash $P/drv.sh $n $args
  echo "$n" >> $P/done.txt
done
