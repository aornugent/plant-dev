#!/bin/bash
# Build the plant tree under events/ into events/lib, against the odelia and
# phylloptim copied there from lib_probe.
E=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/events
cd $E
export R_LIBS=$E/lib MAKEFLAGS=-j2
date +%s > $E/build.start
nice R CMD INSTALL --no-docs --library=$E/lib $E/plant > $E/install.log 2>&1
echo "status $?" > $E/build.status
date +%s > $E/build.end
