#!/bin/bash
# R0, the lib19 check, R1 on dry with a09's committed schedule (jobs_a09.txt line 3), in turn.
T="TIMES=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/loc/loc_a09_c_dry.rds TOL=1e-4"
/home/user/plant-dev/docs/measurements/schedule-search/round4/R/one_r.sh R_base_dry dry $T
/home/user/plant-dev/docs/measurements/schedule-search/round4/R/one_r.sh R_l19_dry dry $T LIB=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap/lib19 FORWARD=1
/home/user/plant-dev/docs/measurements/schedule-search/round4/R/one_r.sh R_free_dry dry $T KNOTS=0
