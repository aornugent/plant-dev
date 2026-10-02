#!/bin/bash
R=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/split/run.sh
bash $R defect_3e-5_s3e-5 split TOL=3e-5 SOIL_TOL=3e-5 COUPLING=defect STEP_LOG=1
bash $R stage_3e-5_s3e-5 split TOL=3e-5 SOIL_TOL=3e-5 COUPLING=stage STEP_LOG=1
