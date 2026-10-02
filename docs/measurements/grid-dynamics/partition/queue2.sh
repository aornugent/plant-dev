#!/bin/bash
R=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/split/run.sh
bash $R defect_3e-5_s1e-6 split TOL=3e-5 SOIL_TOL=1e-6 COUPLING=defect STEP_LOG=1
bash $R defect_3e-5_s3e-5_hmax1 split TOL=3e-5 SOIL_TOL=3e-5 COUPLING=defect STEP_LOG=1 HMAX=1
bash $R defect_1e-6_s3e-5 split TOL=1e-6 SOIL_TOL=3e-5 COUPLING=defect STEP_LOG=1
