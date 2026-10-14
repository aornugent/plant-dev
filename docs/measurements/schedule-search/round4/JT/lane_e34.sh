#!/bin/bash
# E3a (gate derivative cut, splice pair), E4 (knee refined, lib19), E3b (cut, A and B).
D=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev; S=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest; X=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/X_out; O=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/JT_out
run() { $S/adjmap/one.sh $1 dry TIMES=$S/P_out/sched/ins3c_dry.rds WEIGHT=$D/window/rule_A/weight_dry.rds TOL=3e-4 LIB=$3 PIN=$2 OUT=$O/$1.rds; }
run JT3_J12_cut $X/pin_ins3c_9.705.rds $S/libJTcut
run JT3_J13_cut $X/pin_ins3c_9.73.rds $S/libJTcut
run JT4_J12_fine $O/pin_J12_fine.rds $S/adjmap/lib19
run JT4_J13_fine $O/pin_J13_fine.rds $S/adjmap/lib19
run JT3_A_cut $S/P_out/runs/P_ins3c_dry.rds $S/libJTcut
run JT3_B_cut $X/runs/X_ins3c_2.85e-4_dry.rds $S/libJTcut
