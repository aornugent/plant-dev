#!/bin/bash
# E6 (shared steps over the arm switches, lib19), then E3b (gate cut, A and B).
D=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev; S=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest; X=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/X_out; O=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/JT_out
while ! grep -q "done JT4_J13_fine" $S/adjmap/queue.out; do sleep 10; done
run() { $S/adjmap/one.sh $1 dry TIMES=$S/P_out/sched/ins3c_dry.rds WEIGHT=$D/window/rule_A/weight_dry.rds TOL=3e-4 LIB=$3 PIN=$2 OUT=$O/$1.rds; }
run JT6_J12_stops $O/pin_J12_stops.rds $S/adjmap/lib19
run JT6_J13_stops $O/pin_J13_stops.rds $S/adjmap/lib19
run JT3_A_cut $S/P_out/runs/P_ins3c_dry.rds $S/libJTcut
run JT3_B_cut $X/runs/X_ins3c_2.85e-4_dry.rds $S/libJTcut
