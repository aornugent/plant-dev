#!/bin/bash
# S2 (sharp gate): the inset's committed schedule on dry with the arm-switch stop, 3e-4 and 2.85e-4.
D=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev; S=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest; O=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/JT_out
for t in 3e-4 2.85e-4; do
  $S/adjmap/one.sh JT8_ins_${t}_stop dry TIMES=$S/P_out/sched/ins3c_dry.rds WEIGHT=$D/window/rule_A/weight_dry.rds TOL=$t LIB=$S/libJTstop JT_STOP=1 JT_STOP_LOG=1 OUT=$O/JT8_ins_${t}_stop.rds
done
