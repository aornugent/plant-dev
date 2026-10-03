#!/bin/bash
# runq.sh DIR: runs the lines of DIR/queue.txt one at a time ("NAME VAR=value ..."),
# skipping names in DIR/done.txt and rereading the queue after each run. A line starting
# with # is skipped; "STOP" ends the runner. SCRIPT=... picks the harness script
# (default ark_prototype.R); PLANT_LIB defaults to lib_v12t and a line may override it.
# Runs from DIR, whose harness/ is that task's snapshot, under nice -n 10.
D=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev
P=$1
touch $P/done.txt
cd $P || exit 1
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
  script=ark_prototype.R
  for a in $args; do case "$a" in SCRIPT=*) script=${a#SCRIPT=} ;; esac; done
  echo "start $(date +%T) $n $args" >> $P/queue.out
  env PLANT_LIB=$D/lib_v12t $args nice -n 10 Rscript harness/$script > $P/logs/$n.log 2>&1
  status=$?
  echo "done $(date +%T) $n status $status" >> $P/queue.out
  echo "$n" >> $P/done.txt
done
