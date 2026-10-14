#!/bin/bash
# J0-J3: the committed inset run on dry at 3e-4 replayed on the 2.85e-4 run's steps, whole
# and spliced after the introductions near 3.5, 10 and 25. Starts when the X1 lane ends.
D=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev; S=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest; X=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/X_out
while kill -0 26402 2>/dev/null; do sleep 20; done
run() { $S/adjmap/one.sh $1 dry TIMES=$S/P_out/sched/ins3c_dry.rds WEIGHT=$D/window/rule_A/weight_dry.rds TOL=3e-4 LIB=$S/adjmap/lib19 PIN=$2 OUT=$X/runs/$1.rds; }
run X_J0_dry $X/runs/X_ins3c_2.85e-4_dry.rds
run X_J1_dry $X/pin_ins3c_3.4958.rds
run X_J2_dry $X/pin_ins3c_10.037.rds
run X_J3_dry $X/pin_ins3c_24.788.rds
echo "lane j done"
