#!/bin/bash
# Each free run against its knot-stopping base (cmp.R), the rain's quadrature
# (gate.R) and its knot stops (knot_split.R), as notes.md reports them.
S=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest
R=/home/user/plant-dev/docs/measurements/schedule-search/round4/R
cd /tmp
for c in dry long-wet episodic long-drought; do
  base=$S/adjmap/runs/val_a09_c_$c.rds
  [ $c = long-drought ] && base=$S/adjmap/runs/val_a09p_c_long-drought.rds
  echo "=== $c"
  Rscript $R/cmp.R $c $base $S/S_out/runs/S_free_$c.rds 2>&1 | tail -n +1
  PLANT_LIB=$S/adjmap/libS Rscript $R/gate.R $base $S/S_out/runs/S_free_$c.rds 2>&1 | grep -v "^Warn"
  PLANT_LIB=$S/adjmap/libS Rscript $R/knot_split.R S_out/runs/S_free_$c.rds 2>&1 | tail -1
done
