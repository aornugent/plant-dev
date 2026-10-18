#!/bin/bash
# The warm-start prototype on one case: level 0 and its replay in one process, hint off and on
# (one binary), in the order off, on, on, off.   bash chain_ws.sh CASE WIDTH
D=/home/user/plant-dev/docs/measurements/schedule-search/rootcause/refine2/perf
O=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/refine2perf/wsab
export PLANT_LIB=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/refine2perf/ws/lib
C=$1; W=$2
for arm in off1 on1 on2 off2; do
  case $arm in off*) w=0 ;; on*) w=$W ;; esac
  echo "== $arm w=$w" >> $O/chain_$C.log
  PLANT_HINT_WIDTH=$w Rscript $D/ab.R $C nofirst $O/WS_${C}_$arm.rds >> $O/chain_$C.log 2>&1
done
echo done >> $O/chain_$C.log
