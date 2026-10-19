#!/bin/bash
# The combined prototype (hint and a 1e-10 root tolerance) on one case: level 0 and its replay in one process, hint and root tolerance off and on
# (one binary), in the order off, on, on, off.   bash chain_ws2.sh CASE WIDTH RELTOL
D=/home/user/plant-dev/docs/measurements/schedule-search/rootcause/refine2/perf
O=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/refine2perf/wsab
export PLANT_LIB=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/refine2perf/ws2/lib
C=$1; W=$2; R=$3
for arm in off1 on1 on2 off2; do
  case $arm in off*) w=0; r="" ;; on*) w=$W; r=$R ;; esac
  echo "== $arm w=$w" >> $O/chainR_$C.log
  env PLANT_HINT_WIDTH=$w ${r:+PLANT_ROOT_RELTOL=$r} Rscript $D/ab.R $C nofirst $O/WR_${C}_$arm.rds >> $O/chainR_$C.log 2>&1
done
echo done >> $O/chainR_$C.log
