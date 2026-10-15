#!/bin/sh
# libJTstopAG: libAG's plant (lib19 + the averaged gate) with the same stop patch
# (JT_out/stop_plant.diff) on libJTstop's patched odelia and phylloptim.
set -e
S=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest
mkdir -p $S/libJTstopAG
cp -a $S/libJTstop/odelia $S/libJTstop/phylloptim $S/libJTstopAG/
rm -f $S/JT_src/plant_stop_AG/src/*.o $S/JT_src/plant_stop_AG/src/*.so
TMPDIR=$S/JT_src/tmp R_MAKEVARS_USER=$S/JT_src/Makevars.nodebug R_LIBS=$S/libJTstopAG MAKEFLAGS=-j3 R CMD INSTALL --library=$S/libJTstopAG $S/JT_src/plant_stop_AG > $S/JT_out/build_stop_ag.log 2>&1
echo built
