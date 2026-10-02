#!/bin/bash
R=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/split/run.sh
O=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/split/out
bash $R mono_3e-5 mono TOL=3e-5 METHOD=ck
bash $R replay_held_mono3e-5 split TOL=3e-5 SOIL_TOL=3e-5 COUPLING=held STEP_LOG=1 PROGRAM=$O/mono_3e-5.rds
bash $R replay_defect_mono3e-5 split TOL=3e-5 SOIL_TOL=3e-5 COUPLING=defect STEP_LOG=1 PROGRAM=$O/mono_3e-5.rds
