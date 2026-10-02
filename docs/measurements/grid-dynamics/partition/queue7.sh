#!/bin/bash
R=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/split/run.sh
until grep -q "mono_3e-5_uptake0.999 end" /tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/split/logs/runs.log; do sleep 10; done
bash $R stagelind_1e-5_s3e-5 split TOL=1e-5 SOIL_TOL=3e-5 COUPLING=stagelin DEFECT=1 STEP_LOG=1
bash $R stagelind_3e-6_s3e-5 split TOL=3e-6 SOIL_TOL=3e-5 COUPLING=stagelin DEFECT=1 STEP_LOG=1
bash $R stagelind_1e-4_s3e-5 split TOL=1e-4 SOIL_TOL=3e-5 COUPLING=stagelin DEFECT=1 STEP_LOG=1
bash $R stagelind_3e-5_s1e-6 split TOL=3e-5 SOIL_TOL=1e-6 COUPLING=stagelin DEFECT=1 STEP_LOG=1
bash $R stagelind_1e-6_s3e-5 split TOL=1e-6 SOIL_TOL=3e-5 COUPLING=stagelin DEFECT=1 STEP_LOG=1
bash $R mono_1e-4 mono TOL=1e-4 METHOD=ck
bash $R mono_3e-4 mono TOL=3e-4 METHOD=ck
bash $R mono_1e-3 mono TOL=1e-3 METHOD=ck
bash $R held_3e-5_s3e-5_hmax1 split TOL=3e-5 SOIL_TOL=3e-5 COUPLING=held STEP_LOG=1 HMAX=1
