#!/bin/sh
# libJTstopAGcut: libAG's plant (lib19 + the averaged gate) with the same stop patch
# (JT_out/stop_plant.diff) on libJTstop's patched odelia and phylloptim.
set -e
S=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest
mkdir -p $S/libJTstopAGcut
cp -a $S/libJTstop/odelia $S/libJTstop/phylloptim $S/libJTstopAGcut/
rm -f $S/JT_src/plant_stop_AGcut/src/*.o $S/JT_src/plant_stop_AGcut/src/*.so
TMPDIR=$S/JT_src/tmp R_MAKEVARS_USER=$S/JT_src/Makevars.nodebug R_LIBS=$S/libJTstopAGcut MAKEFLAGS=-j3 R CMD INSTALL --library=$S/libJTstopAGcut $S/JT_src/plant_stop_AGcut > $S/JT_out/build_stop_agcut.log 2>&1
echo built
