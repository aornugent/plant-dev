#!/bin/bash
# X2: the inset pair on dry at 3e-4 with the founders' year at 1e-4, lib19.
D=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev
for v in c f; do
  $D/schedtest/adjmap/one.sh X_ins3${v}_f3_dry dry TIMES=$D/schedtest/P_out/sched/ins3${v}_dry.rds WEIGHT=$D/schedtest/X_out/weight_dry_f3.rds \
    TOL=3e-4 LIB=$D/schedtest/adjmap/lib19 OUT=$D/schedtest/X_out/runs/X_ins3${v}_f3_dry.rds
done
echo "lane x2 done"
