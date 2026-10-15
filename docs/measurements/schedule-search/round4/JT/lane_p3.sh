#!/bin/bash
# lane_p3.sh TAG MODE [VAR=value ...]: the inset's committed schedule on dry at 3e-4 and
# 2.85e-4 on libJTsplit with JT_SPLIT_ARM=MODE, gradient; output JT_out/JT12_TAG_<tol>.rds.
D=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev; S=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest; O=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/JT_out
tag=$1; mode=$2; shift 2
for t in 3e-4 2.85e-4; do
  $S/adjmap/one.sh JT12_${tag}_$t dry TIMES=$S/P_out/sched/ins3c_dry.rds WEIGHT=$D/window/rule_A/weight_dry.rds TOL=$t LIB=$S/libJTsplit JT_SPLIT_ARM=$mode JT_STOP_LOG=1 OUT=$O/JT12_${tag}_$t.rds "$@"
done
