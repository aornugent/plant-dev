#!/bin/bash
# J8-J10: splices at 8.7, 9.15 and 9.6, inside the window that carries 37% of the jitter.
D=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev; S=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest; X=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/X_out
while pgrep -f lane_j2.sh >/dev/null; do sleep 20; done
run() { $S/adjmap/one.sh $1 dry TIMES=$S/P_out/sched/ins3c_dry.rds WEIGHT=$D/window/rule_A/weight_dry.rds TOL=3e-4 LIB=$S/adjmap/lib19 PIN=$2 OUT=$X/runs/$1.rds; }
run X_J8_dry $X/pin_ins3c_8.7.rds
run X_J9_dry $X/pin_ins3c_9.15.rds
run X_J10_dry $X/pin_ins3c_9.6.rds
