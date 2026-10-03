#!/bin/bash
# The whole run with the member step capped at HMAX days (split_stepper_cap.R):
# stagelin + defect at member tol 1e-6, HMAX 1 then 0.5; pc + defect at HMAX 1.
B=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/partition_bias
$B/run.sh fullc_sld_1e-6_h1 split_stepper_cap.R TOL=1e-6 SOIL_TOL=3e-5 COUPLING=stagelin DEFECT=1 HMAX=1
$B/run.sh fullc_sld_1e-6_h0.5 split_stepper_cap.R TOL=1e-6 SOIL_TOL=3e-5 COUPLING=stagelin DEFECT=1 HMAX=0.5
$B/run.sh fullc_pc1d_1e-6_h1 split_stepper_cap.R TOL=1e-6 SOIL_TOL=3e-5 COUPLING=pc PC_ITER=1 DEFECT=1 HMAX=1
