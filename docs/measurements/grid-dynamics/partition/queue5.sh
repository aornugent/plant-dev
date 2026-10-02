#!/bin/bash
R=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/split/run.sh
bash $R pc1_3e-5_s3e-5 split TOL=3e-5 SOIL_TOL=3e-5 COUPLING=pc PC_ITER=1 STEP_LOG=1
bash $R stagelin_3e-5_s3e-5 split TOL=3e-5 SOIL_TOL=3e-5 COUPLING=stagelin STEP_LOG=1
bash $R stagelind_3e-5_s3e-5 split TOL=3e-5 SOIL_TOL=3e-5 COUPLING=stagelin DEFECT=1 STEP_LOG=1
