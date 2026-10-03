#!/bin/bash
# The reference pass on the long-drought rule-A recording: every fourth node of
# each invader, Cash-Karp at rtol 1e-8, from the snapshot.
D=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev
S=$D/spike_methods
cd $S/snap || exit 1
env PLANT_LIB=$D/lib_guard REC=${REC:-ld_ruleA} REGIME=${REGIME:-long-drought} RTOL=${RTOL:-1e-8} \
  MEMBERS=${MEMBERS:-1,5,9,13,17,21,25,29,33,37,41,45,49,53,57,61,65,69,73,77,81,85,89,93,97,101,105} \
  OUT=${OUT:-pass1_ld_ruleA.rds} nice -n 10 Rscript pass1.R > $S/${LOG:-pass1_ld_ruleA.log} 2>&1
