#!/bin/bash
# drive.sh ROUTE RESERVE [CASE...]: alternate drive.R passes with the runs they request (run.sh,
# P lanes) until no case waits on a run.
D=/home/user/plant-dev/docs/measurements/schedule-search/rootcause/loop
L=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/loop
for pass in $(seq 1 8); do
  R=$L/requests_$1_$2.txt; rm -f $R
  REQ=$R Rscript $D/drive.R "$@" > $L/drive_$1_$2.log 2>&1
  [ -s $R ] || break
  echo "pass $pass: $(sort -u $R | wc -l) runs" >> $L/drive_$1_$2.passes
  $D/run.sh $(sort -u $R)
done
