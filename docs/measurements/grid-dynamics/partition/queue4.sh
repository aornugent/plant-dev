#!/bin/bash
R=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/split/run.sh
O=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/split/out
bash $R replay_exact_mono3e-5 split TOL=3e-5 SOIL_TOL=3e-5 COUPLING=exact STEP_LOG=1 PROGRAM=$O/mono_3e-5.rds
