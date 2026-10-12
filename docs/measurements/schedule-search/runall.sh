#!/bin/bash
# Run the lattice jobs, four at a time; each line: NAME RECORD VAR=value ...
A=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap
xargs -P 4 -L 1 $A/one.sh < /tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/lattice/jobs.txt
