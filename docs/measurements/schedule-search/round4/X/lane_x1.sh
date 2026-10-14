#!/bin/bash
# X1: the inset pair on dry at tolerance 3e-4 nudged by ±5%, lib19, one run at a time.
D=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev
for t in 2.85e-4 3.15e-4; do for v in c f; do
  $D/schedtest/adjmap/one.sh X_ins3${v}_${t}_dry dry TIMES=$D/schedtest/P_out/sched/ins3${v}_dry.rds WEIGHT=$D/window/rule_A/weight_dry.rds \
    TOL=$t LIB=$D/schedtest/adjmap/lib19 OUT=$D/schedtest/X_out/runs/X_ins3${v}_${t}_dry.rds
done; done
echo "lane x1 done"
