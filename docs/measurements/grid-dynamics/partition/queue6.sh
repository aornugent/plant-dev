#!/bin/bash
R=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/split/run.sh
# wait for queue5 to finish
until grep -q "stagelind_3e-5_s3e-5 end" /tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/split/logs/runs.log; do sleep 10; done
bash $R mono_3e-5_uptake0.999 split TOL=3e-5 MONO=1 UPTAKE_SCALE=0.999
bash $R held_3e-5_s3e-5_hmax1 split TOL=3e-5 SOIL_TOL=3e-5 COUPLING=held STEP_LOG=1 HMAX=1
bash $R held_3e-5_s3e-5_hmax0.25 split TOL=3e-5 SOIL_TOL=3e-5 COUPLING=held STEP_LOG=1 HMAX=0.25
bash $R mono_1e-4 mono TOL=1e-4 METHOD=ck
bash $R mono_3e-4 mono TOL=3e-4 METHOD=ck
bash $R mono_1e-3 mono TOL=1e-3 METHOD=ck
