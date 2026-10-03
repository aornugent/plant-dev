#!/bin/bash
# After q_resume2.sh: the members' own error at the whole-run level, the soil's
# draw from the recording at 1e-6 and 3e-5, and at 1e-5 with states kept to see
# where it parts from the reference.
B=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/partition_bias
REC=$B/out/rec_1e-7.rds
until grep -q "=== lock_helddef_mono3e-5 end" $B/logs/runs.log; do sleep 10; done
$B/run.sh full_rec_1e-6 split_stepper_rec.R TOL=1e-6 SOIL_TOL=3e-5 COUPLING=rec REC=$REC
$B/run.sh full_rec_3e-5 split_stepper_rec.R TOL=3e-5 SOIL_TOL=3e-5 COUPLING=rec REC=$REC
$B/run.sh full_rec_1e-5_st split_stepper_rec.R TOL=1e-5 SOIL_TOL=3e-5 COUPLING=rec REC=$REC STATES=$B/out/full_rec_1e-5_st_states.rds
