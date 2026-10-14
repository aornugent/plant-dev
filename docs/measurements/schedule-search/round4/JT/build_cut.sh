#!/bin/sh
# libJTcut: lib19 with the establishment gate's derivative in net production cut
# (value unchanged), from JT_src/plant (lib19's plant source plus that one edit).
set -e
S=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest
mkdir -p $S/libJTcut
cp -a $S/adjmap/lib19/odelia $S/adjmap/lib19/phylloptim $S/libJTcut/
R_LIBS=$S/libJTcut MAKEFLAGS=-j3 R CMD INSTALL --library=$S/libJTcut $S/JT_src/plant > $S/JT_out/build_cut.log 2>&1
echo built
