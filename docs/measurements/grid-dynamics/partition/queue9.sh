#!/bin/bash
R=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/split/run.sh
O=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/split/out
bash $R frozen_pc1d_3e-5_0 split TOL=3e-5 SOIL_TOL=3e-5 COUPLING=pc PC_ITER=1 DEFECT=1 PROGRAM=$O/pc1d_3e-5_s3e-5.rds THETA=lma THETA_REL=0
bash $R frozen_pc1d_3e-5_+1e-5 split TOL=3e-5 SOIL_TOL=3e-5 COUPLING=pc PC_ITER=1 DEFECT=1 PROGRAM=$O/pc1d_3e-5_s3e-5.rds THETA=lma THETA_REL=1e-5
bash $R frozen_pc1d_3e-5_-1e-5 split TOL=3e-5 SOIL_TOL=3e-5 COUPLING=pc PC_ITER=1 DEFECT=1 PROGRAM=$O/pc1d_3e-5_s3e-5.rds THETA=lma THETA_REL=-1e-5
bash $R held_1e-6_s3e-5 split TOL=1e-6 SOIL_TOL=3e-5 COUPLING=held STEP_LOG=1
