#!/bin/bash
# The map on the edge-aligned episodic grid, then its bisection test.
A=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap
cd $A
./one.sh map_e_epg2 episodic MODE=map TIMES=$A/../edges/epg2.rds COARSE=odd
Rscript bisect.R make map_e_epg2 17 > logs/bis_epg2_make.log 2>&1
for m in map own random; do ./one.sh bis_map_e_epg2_$m episodic MODE=plain FORWARD=1 TIMES=$A/sched/bis_map_e_epg2_$m.rds; done
Rscript bisect.R score map_e_epg2 17 > logs/bis_epg2_score.log 2>&1
