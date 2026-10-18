#!/bin/bash
# run5_map.sh: the closing fate map's schedule on dry, forward, with storage_relaxation_offset x 2 (twin.R).
DEV=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev
E=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/evidence
CL=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/closing
while [ "$(pgrep -c -f 'R --|Rscript|exec/R')" -ge 4 ]; do sleep 20; done
echo "start map_sro2_dry $(date +%T)" >> $E/r5/queue.out
env REGIME=dry SEED=31 TRAIT_REL=storage_relaxation_offset=1 ATOL=1e-4 WEIGHT_SOIL=10 WEIGHT=$DEV/window/rule_A/weight_dry.rds WEIGHT_MAX=100 HMAX=15 SHARE=0.1 SPLIT=1 \
  TOL=1e-4 TIMES=$CL/sched/map_dry.rds OUT=$E/r5/map_sro2_dry.rds \
  Rscript /home/user/plant-dev/docs/measurements/schedule-search/rootcause/evidence/twin.R > $E/r5/map_sro2_dry.log 2>&1
echo "done $? map_sro2_dry $(date +%T)" >> $E/r5/queue.out
