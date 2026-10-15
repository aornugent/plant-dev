#!/bin/sh
# libJTsplit: libJTstop plus splits at f_hi's sign changes (JT_SPLIT_ARM=node|soil|soilall).
set -e
S=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest
mkdir -p $S/libJTsplit
cp -a $S/libJTstop/odelia $S/libJTstop/phylloptim $S/libJTsplit/
rm -f $S/JT_src/plant_split/src/*.o $S/JT_src/plant_split/src/*.so
TMPDIR=$S/JT_src/tmp R_MAKEVARS_USER=$S/JT_src/Makevars.nodebug R_LIBS=$S/libJTsplit MAKEFLAGS=-j3 R CMD INSTALL --library=$S/libJTsplit $S/JT_src/plant_split > $S/JT_out/build_split.log 2>&1
echo built
