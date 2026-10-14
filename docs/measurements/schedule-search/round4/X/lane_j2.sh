#!/bin/bash
# J4-J7: finer splices inside the windows where the jitter enters (after lane_j ends).
D=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev; S=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest; X=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/X_out
while pgrep -f lane_j.sh >/dev/null; do sleep 20; done
run() { $S/adjmap/one.sh $1 dry TIMES=$S/P_out/sched/ins3c_dry.rds WEIGHT=$D/window/rule_A/weight_dry.rds TOL=3e-4 LIB=$S/adjmap/lib19 PIN=$2 OUT=$X/runs/$1.rds; }
run X_J4_dry $X/pin_ins3c_5.rds
run X_J5_dry $X/pin_ins3c_6.7.rds
run X_J6_dry $X/pin_ins3c_8.3.rds
run X_J7_dry $X/pin_ins3c_17.rds
echo "lane j2 done"
