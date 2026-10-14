#!/bin/bash
# J15: central differences along TF24_cost_scale on A's and B's pinned steps, forward only.
D=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev; S=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest; X=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/X_out
run() { $S/adjmap/one.sh $1 dry TIMES=$S/P_out/sched/ins3c_dry.rds WEIGHT=$D/window/rule_A/weight_dry.rds TOL=3e-4 LIB=$S/adjmap/lib19 FORWARD=1 PIN=$2 TRAIT_REL=TF24_cost_scale=$3 OUT=$X/runs/$1.rds; }
run X_fdA_up_dry $S/P_out/runs/P_ins3c_dry.rds 1e-4
run X_fdA_dn_dry $S/P_out/runs/P_ins3c_dry.rds -1e-4
run X_fdB_up_dry $X/runs/X_ins3c_2.85e-4_dry.rds 1e-4
run X_fdB_dn_dry $X/runs/X_ins3c_2.85e-4_dry.rds -1e-4
