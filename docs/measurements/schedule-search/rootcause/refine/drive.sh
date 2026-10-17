#!/bin/bash
# drive.sh TOL TARGETS [CASE...]: alternate drive.R passes with the runs they request
# (run.sh, P lanes) until no case waits on a run.
D=/home/user/plant-dev/docs/measurements/schedule-search/rootcause/refine
O=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/refine
for pass in $(seq 1 14); do
  R=$O/requests_$1.txt; rm -f $R
  REQ=$R Rscript $D/drive.R "$@" > $O/drive_$1.log 2>&1
  [ -s $R ] || break
  echo "pass $pass $(date +%T): $(sort -u $R | tr '\n' ' ')" >> $O/drive_$1.passes
  $D/run.sh $(sort -u $R)
done
echo "drive $1 finished $(date +%T)" >> $O/drive_$1.passes
