#!/bin/bash
# S2 (averaged gate): a09's committed schedule on dry with the arm-switch stop, 1e-4 and 1.05e-4.
S=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest; O=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/JT_out
for t in 1e-4 1.05e-4; do
  /home/user/plant-dev/docs/measurements/schedule-search/round4/AG/run.sh JT9_a09c_${t}_stop dry TIMES=$S/loc/loc_a09_c_dry.rds TOL=$t LIB=$S/libJTstopAG JT_STOP=1 JT_STOP_LOG=1 OUT=$O/JT9_a09c_${t}_stop.rds
done
