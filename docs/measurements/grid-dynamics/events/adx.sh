#!/bin/bash
# One reverse-mode run on lib_v12t at tolerance $1, outside the queue (which
# skips a tolerance whose log already holds the elasticities).
E=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/events
T=$1
grep -q "elasticity d_I" $E/runs/ad_$T.log 2>/dev/null && { echo "have ad_$T"; exit 0; }
cd $E && env PLANT_LIB=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/lib_v12t TOL=$T OUT=$E/runs/ad_$T.rds nice Rscript $E/ad_check.R > $E/runs/ad_$T.log 2>&1
echo "ad_$T: $(head -1 $E/runs/ad_$T.log)"
