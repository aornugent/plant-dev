#!/bin/bash
# R2, R3: long-wet with a09's committed schedule (jobs_a09.txt line 5), in turn.
T="TIMES=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/loc/loc_a09_c_long-wet.rds TOL=1e-4"
/home/user/plant-dev/docs/measurements/schedule-search/round4/R/one_r.sh R_base_long-wet long-wet $T
/home/user/plant-dev/docs/measurements/schedule-search/round4/R/one_r.sh R_free_long-wet long-wet $T KNOTS=0
