#!/bin/bash
# E2: the J12/J13 splice pair replayed with a_d0 x 10 (lib19, gradient).
D=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev; S=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest; X=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/X_out; O=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/JT_out
run() { $S/adjmap/one.sh $1 dry TIMES=$S/P_out/sched/ins3c_dry.rds WEIGHT=$D/window/rule_A/weight_dry.rds TOL=3e-4 LIB=$S/adjmap/lib19 PIN=$2 OUT=$O/$1.rds "${@:3}"; }
run JT2_J12_ad10 $X/pin_ins3c_9.705.rds TRAIT_REL=a_d0=9
run JT2_J13_ad10 $X/pin_ins3c_9.73.rds TRAIT_REL=a_d0=9
