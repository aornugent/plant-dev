#!/bin/bash
# S4: a09's committed schedule, averaged gate, the stop plus the gate's derivative cut.
S=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest; O=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/JT_out
for t in 1e-4 1.05e-4; do
  /home/user/plant-dev/docs/measurements/schedule-search/round4/AG/run.sh JT11_a09c_${t}_stopcut dry TIMES=$S/loc/loc_a09_c_dry.rds TOL=$t LIB=$S/libJTstopAGcut JT_STOP=1 OUT=$O/JT11_a09c_${t}_stopcut.rds
done
