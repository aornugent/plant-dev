#!/bin/bash
# The real runs of notes.md left after the restart, one at a time.
L=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/loc
DEV=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev
/home/user/plant-dev/docs/measurements/schedule-search/round4/S/one_S.sh S_free_long-wet long-wet TIMES=$L/loc_a09_c_long-wet.rds TOL=1e-4 KNOTS=0
/home/user/plant-dev/docs/measurements/schedule-search/round4/S/one_S.sh S_free_episodic episodic TIMES=$L/loc_a09_c_episodic.rds TOL=1e-4 KNOTS=0
/home/user/plant-dev/docs/measurements/schedule-search/round4/S/one_S.sh S_free_long-drought long-drought TIMES=$L/loc_a09_c_long-drought.rds TOL=1e-4 KNOTS=0
