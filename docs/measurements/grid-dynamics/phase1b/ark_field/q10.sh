#!/bin/bash
# The ARK field check at 3e-5 again, now reporting how far its trajectory drifts
# from arkc's recorded soil states (the reference steps' extra evaluations
# perturb TF24's warm-started leaf solves; a plain replay is bit for bit).
source /tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/phase1b/run.sh
script dca2_3e-5 $P/events dense_check_ark.R $V12T METHOD=ark TOL=3e-5 TOL_SOIL=100 GRID=$DEV/phase1a/t2/runs/arkc_3e-5.rds OUT=$R/dca2_3e-5.rds
echo "q10 finished"
