#!/bin/bash
# Build the probe plant into this spike's own library, at -j2.
S=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/split
export R_LIBS=$S/lib MAKEFLAGS=-j2
t0=$(date +%s)
R CMD INSTALL --no-docs --library=$S/lib $S/plant > $S/logs/install_plant.log 2>&1
echo "status $? in $(( $(date +%s) - t0 ))s" >> $S/logs/install_plant.log
