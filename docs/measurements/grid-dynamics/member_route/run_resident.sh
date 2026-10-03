#!/bin/bash
# The resident recording: Cash-Karp, uniform 108, tied 3e-5, rule A's weight, with
# every accepted state kept (STATES). The driver runs on lib_v12t, as the window
# phase's and phase 1c's driver runs do; without STATES, REGIME=long-drought is the
# command that made window/drv/long-drought_rule.rds.
#   REGIME=long-drought NAME=ld_ruleA bash run_resident.sh
D=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev
S=$D/spike_methods
REGIME=${REGIME:-long-drought}
NAME=${NAME:-ld_ruleA}
WEIGHT_FILE=${WEIGHT_FILE:-$S/weight_$REGIME.rds}
cd $S/snap || exit 1
env PLANT_LIB=$D/lib_v12t METHOD=ck TOL=3e-5 ATOL=1e-4 TIMES=$D/window/t/t_u108.rds \
  REGIME=$REGIME WEIGHT=$WEIGHT_FILE STATES=$S/${NAME}_states.rds OUT=$S/$NAME.rds \
  nice -n 10 Rscript harness/ark_prototype.R > $S/$NAME.log 2>&1
