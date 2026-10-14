#!/bin/bash
# E1, E2: the closing edges' tighter tolerance under both gates, with a 5% nudge each.
D=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev; S=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest; X=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/X_out
W=$X/weight_dry_ett.rds
for t in 3e-4 2.85e-4; do $S/adjmap/one.sh X_ett_ins3c_${t}_dry dry TIMES=$S/P_out/sched/ins3c_dry.rds WEIGHT=$W TOL=$t LIB=$S/adjmap/lib19 OUT=$X/runs/X_ett_ins3c_${t}_dry.rds; done
for t in 1e-4 1.05e-4; do /home/user/plant-dev/docs/measurements/schedule-search/round4/AG/run.sh AG_ett_a09c_${t}_dry dry TIMES=$S/loc/loc_a09_c_dry.rds TOL=$t WEIGHT=$W; done
