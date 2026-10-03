#!/bin/bash
# After q_rec2.sh: which side carries the recorded-draw runs' residual at 1e-5 --
# the members themselves (recsoil: no sub-cycle, the members read the recorded
# soil) or the soil's sub-cycle (rec with the soil at 1e-6).
B=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/partition_bias
REC=$B/out/rec_1e-7.rds
until grep -q "=== full_rec_1e-5_st end" $B/logs/runs.log; do sleep 10; done
$B/run.sh full_recsoil_1e-5 split_stepper_rec.R TOL=1e-5 SOIL_TOL=3e-5 COUPLING=recsoil REC=$REC
$B/run.sh full_rec_1e-5_s1e-6 split_stepper_rec.R TOL=1e-5 SOIL_TOL=1e-6 COUPLING=rec REC=$REC
