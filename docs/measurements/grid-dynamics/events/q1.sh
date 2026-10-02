#!/bin/bash
# Stage 1: the probe present and unused against the record's build, then the
# split's cost in leaf solves at 1e-4 and 3e-5 under the tied tolerance.
source /tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/events/run.sh
OFF="TF24_DOMAIN_TOL=1e9"
SPLIT="LOCAL=1 MEMBER=1 EVENT_ETA=1e-10"
# The original driver on lib_v12t; then the modified driver on the probe build,
# compared step by step.
run v0_1e-4 $ORIG $V12T TOL=1e-4 OUT=$R/v0_1e-4.rds
run g_1e-4 $NEW $LIB TOL=1e-4 OUT=$R/g_1e-4.rds REF=$R/v0_1e-4.rds
# Replays of that grid: plain, split by the probe, split by whole-patch
# evaluation (which must give the probe's J bit for bit).
run rp_1e-4 $NEW $LIB TOL=1e-4 PROGRAM=$R/g_1e-4.rds $OFF
run sp_1e-4 $NEW $LIB TOL=1e-4 PROGRAM=$R/g_1e-4.rds $OFF $SPLIT SPLIT_LOG=$R/sl_1e-4.rds CROSS_LOG=$R/cl_sp_1e-4.rds
run spw_1e-4 $NEW $LIB TOL=1e-4 PROGRAM=$R/g_1e-4.rds $OFF LOCAL=1 EVENT_ETA=1e-10
# 3e-5: grid, plain replay, split replay.
run g_3e-5 $NEW $LIB TOL=3e-5 OUT=$R/g_3e-5.rds
run rp_3e-5 $NEW $LIB TOL=3e-5 PROGRAM=$R/g_3e-5.rds $OFF
run sp_3e-5 $NEW $LIB TOL=3e-5 PROGRAM=$R/g_3e-5.rds $OFF $SPLIT SPLIT_LOG=$R/sl_3e-5.rds
# The adaptive build with the split in it, at both tolerances.
run ga_1e-4 $NEW $LIB TOL=1e-4 $SPLIT OUT=$R/ga_1e-4.rds
run ga_3e-5 $NEW $LIB TOL=3e-5 $SPLIT OUT=$R/ga_3e-5.rds
echo "q1 finished"
