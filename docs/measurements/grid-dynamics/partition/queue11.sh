#!/bin/bash
R=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/split/run.sh
until grep -q "exactx_1e-5_s3e-5 end" /tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/split/logs/runs.log; do sleep 10; done
bash $R pc1d_3e-5_s3e-5_sw05 split TOL=3e-5 SOIL_TOL=3e-5 COUPLING=pc PC_ITER=1 DEFECT=1 STEP_LOG=1 SWITCH_DAYS=0.05
bash $R exactx_3e-5_s3e-5_sw05 split TOL=3e-5 SOIL_TOL=3e-5 COUPLING=exactx STEP_LOG=1 SWITCH_DAYS=0.05
