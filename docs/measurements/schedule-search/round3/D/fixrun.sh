#!/bin/bash
# fixrun.sh NAME [VAR=value ...]: adj_run.R at one.sh's settings, output in D_out.
D=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev
A=$D/schedtest/adjmap; O=$D/schedtest/D_out
name=$1; shift
env REGIME=long-drought TOL=3e-5 ATOL=1e-4 WEIGHT_SOIL=10 WEIGHT=$D/window/rule_A/weight_long-drought.rds \
  WEIGHT_MAX=100 HMAX=15 SHARE= SPLIT=1 OUT=$O/$name.rds "$@" \
  Rscript $A/adj_run.R > $O/$name.log 2>&1
echo "done $name $?" >> $O/queue.out
