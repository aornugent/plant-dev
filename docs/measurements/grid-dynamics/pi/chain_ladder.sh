#!/bin/bash
# Task 5: the chain alone's global moisture error against tol, under odelia and pi,
# on long drought (at the knots, harness/soil_chain.R as is) and constant (at the
# end, as is; and at observation times, soil_chain_obs.R with OBS). One at a time.
P=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/pi
C=$P/chain
OBS=0.02,0.05,0.1,0.2,0.5,1,2,5,10,20,30
run() { bash $P/chain.sh "$@"; }
run ref_ld REGIME=long-drought TOL=1e-10 CONTROL=odelia OUT=$C/ref_ld.rds
run ref_const REGIME=constant TOL=1e-10 CONTROL=odelia OUT=$C/ref_const.rds
run refpi_ld REGIME=long-drought TOL=1e-10 CONTROL=pi REF=$C/ref_ld.rds OUT=$C/refpi_ld.rds
run refpi_const REGIME=constant TOL=1e-10 CONTROL=pi REF=$C/ref_const.rds OUT=$C/refpi_const.rds
export CHAIN_SCRIPT=$P/soil_chain_obs.R
run refobs_const REGIME=constant TOL=1e-10 CONTROL=odelia OBS=$OBS OUT=$C/refobs_const.rds
run refobspi_const REGIME=constant TOL=1e-10 CONTROL=pi OBS=$OBS OUT=$C/refobspi_const.rds
unset CHAIN_SCRIPT
for law in odelia pi; do
  for tol in 1e-3 3e-4 1e-4 3e-5 1e-5 3e-6 1e-6 3e-7 1e-7; do
    run lad_ld_${law}_${tol} REGIME=long-drought TOL=$tol CONTROL=$law REF=$C/ref_ld.rds OUT=$C/lad_ld_${law}_${tol}.rds
    run lad_const_${law}_${tol} REGIME=constant TOL=$tol CONTROL=$law REF=$C/ref_const.rds OUT=$C/lad_const_${law}_${tol}.rds
    CHAIN_SCRIPT=$P/soil_chain_obs.R bash $P/chain.sh obs_const_${law}_${tol} REGIME=constant TOL=$tol CONTROL=$law OBS=$OBS OUT=$C/obs_const_${law}_${tol}.rds
  done
done
# The side test: pi with r_prev left by a clipped step (the driver's choice).
for tol in 1e-4 3e-5 1e-5; do
  CHAIN_SCRIPT=$P/soil_chain_obs.R bash $P/chain.sh keep_ld_pi_${tol} REGIME=long-drought TOL=$tol CONTROL=pi CLIP=keep REF=$C/ref_ld.rds OUT=$C/keep_ld_pi_${tol}.rds
  CHAIN_SCRIPT=$P/soil_chain_obs.R bash $P/chain.sh keep_const_pi_${tol} REGIME=constant TOL=$tol CONTROL=pi CLIP=keep REF=$C/ref_const.rds OUT=$C/keep_const_pi_${tol}.rds
done
echo chain ladder done
