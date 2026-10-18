#!/bin/bash
# Forward runs on level 2's steps and nodes: as run, and with a_l1 x 1.01.
SP=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad
LIBS=$SP/dev/schedtest/adjmap/libS; O=$SP/refine/s05/epi-adG208; E=$SP/epi
for v in base:a_dG2=-0.2 al1:a_dG2=-0.2,a_l1=0.01; do n=fd_${v%%:*}; tr=${v#*:}
  env TOL=1e-4 ATOL=1e-4 WEIGHT_SOIL=10 WEIGHT_MAX=100 HMAX=15 SHARE=0.1 SPLIT=1 REGIME=episodic SEED=31 TRAIT_REL=$tr \
    WEIGHT=$SP/dev/window/rule_A/weight_episodic.rds LIB=$LIBS TIMES=$O/level2_times.rds OUT=$E/runs/$n.rds PIN=$O/level2.rds FORWARD=1 FIRST= \
    Rscript $E/run1.R > $E/runs/$n.log 2>&1; cat $E/runs/$n.log
done
echo E5_DONE
