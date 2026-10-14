#!/bin/bash
# E3: the averaged gate's pairs on dry with the closing edges' tolerance tightened.
D=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev; S=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest; X=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/X_out; AG=/home/user/plant-dev/docs/measurements/schedule-search/round4/AG/run.sh; W=$X/weight_dry_ett.rds
$AG AG_ett_a09f_dry dry TIMES=$S/loc/loc_a09_f_dry.rds TOL=1e-4 WEIGHT=$W
$AG AG_ett_insc_dry dry TIMES=$S/P_out/sched/insc_dry.rds TOL=1e-4 WEIGHT=$W
$AG AG_ett_insf_dry dry TIMES=$S/P_out/sched/insf_dry.rds TOL=1e-4 WEIGHT=$W
