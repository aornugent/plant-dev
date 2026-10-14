#!/bin/bash
# N6: a09 with its nested check under the sharp gate at 1e-4 on dry (the whole halving),
# after the sharp gate's class runs.
D=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev; S=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest; X=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/X_out
while pgrep -f "lane_cls.sh 19" >/dev/null; do sleep 20; done
$S/adjmap/one.sh X_a09nb_dry dry TIMES=$X/sched/a09nb_dry.rds WEIGHT=$D/window/rule_A/weight_dry.rds TOL=1e-4 LIB=$S/adjmap/lib19 OUT=$X/runs/X_a09nb_dry.rds
