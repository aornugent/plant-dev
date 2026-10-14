#!/bin/bash
# E4: dry-flat's inset pair on libS without rain stops, the closing edges' tolerance tightened.
S=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest; X=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/X_out
for v in c f; do $S/adjmap/one_nk.sh val_inse_${v}_dry-flat dry-flat TIMES=$S/P_out/sched/ins${v}_dry-flat.rds WEIGHT=$X/weight_dry-flat_ett.rds TOL=1e-4 LIB=$S/adjmap/libS KNOTS=0; done
