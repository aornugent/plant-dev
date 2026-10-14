#!/bin/bash
# J12-J14: splices just before and after the closing edge at 9.711, and at 9.9.
D=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev; S=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest; X=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/X_out
run() { $S/adjmap/one.sh $1 dry TIMES=$S/P_out/sched/ins3c_dry.rds WEIGHT=$D/window/rule_A/weight_dry.rds TOL=3e-4 LIB=$S/adjmap/lib19 PIN=$2 OUT=$X/runs/$1.rds; }
run X_J12_dry $X/pin_ins3c_9.705.rds
run X_J13_dry $X/pin_ins3c_9.73.rds
run X_J14_dry $X/pin_ins3c_9.9.rds
