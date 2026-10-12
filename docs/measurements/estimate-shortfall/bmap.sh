#!/bin/bash
# bmap.sh NAME TIMES COARSE: the map with fine time bands over the panel's first years.
D=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev
cd /home/user/plant-dev && env PLANT_LIB=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap/lib REGIME=episodic TOL=3e-5 ATOL=1e-4 WEIGHT_SOIL=10 WEIGHT=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/window/rule_A/weight_episodic.rds \
  WEIGHT_MAX=100 HMAX=15 SHARE=0.1 SPLIT=1 MODE=map TIMES=$2 COARSE=$3 BANDS=8.0,8.05,8.1,8.15,8.2,8.3,8.4,8.52,8.75,9,9.5,10,11,12,14,17,20,25,30 \
  OUT=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/rc/$1.rds Rscript /tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/rc/adj_run_b.R > /tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/rc/$1.log 2>&1
echo "done $1 $?" >> /tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/rc/bmap.out
