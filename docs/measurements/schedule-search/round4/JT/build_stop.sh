#!/bin/sh
# libJTstop: lib19 plus (phylloptim) the collar solve's marginal profit at each end of
# its interval, (plant) those and the arm as aux and the dry-end margin as a second
# sign value per node, Patch::stop_fraction, and (odelia) a step cut at the first
# arm switch it holds, or after a cut at its last; JT_STOP=1 cuts, any other value
# only detects (JT_STOP_LOG, JT_STOP_SCAN, JT_STOP_T0/T1 log roots and scans).
set -e
S=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest
rm -f $S/JT_src/plant_stop/src/*.o $S/JT_src/plant_stop/src/*.so
TMPDIR=$S/JT_src/tmp R_MAKEVARS_USER=$S/JT_src/Makevars.nodebug R_LIBS=$S/libJTstop MAKEFLAGS=-j3 R CMD INSTALL --library=$S/libJTstop $S/JT_src/plant_stop > $S/JT_out/build_stop.log 2>&1
echo built
