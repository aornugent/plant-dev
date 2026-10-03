#!/bin/bash
# The first mortality event (legs 1-10, to t = 3.7037): stagelin + defect, and the
# recorded couplings (b), at two member tolerances, states kept.
B=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/partition_bias
REC=$B/out/rec_1e-7.rds
for tol in 1e-4 1e-6; do
  $B/run.sh ev_sld_$tol split_stepper_orig.R TOL=$tol SOIL_TOL=3e-5 COUPLING=stagelin DEFECT=1 LEGS=10 STATES=$B/out/ev_sld_${tol}_states.rds
  $B/run.sh ev_rec_$tol split_stepper_rec.R TOL=$tol SOIL_TOL=3e-5 COUPLING=rec REC=$REC LEGS=10 STATES=$B/out/ev_rec_${tol}_states.rds
  $B/run.sh ev_recsoil_$tol split_stepper_rec.R TOL=$tol SOIL_TOL=3e-5 COUPLING=recsoil REC=$REC LEGS=10 STATES=$B/out/ev_recsoil_${tol}_states.rds
done
