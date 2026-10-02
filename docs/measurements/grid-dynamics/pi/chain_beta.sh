#!/bin/bash
# The PI law's beta on the chain alone: 0.04 (the default) against 0.08.
P=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/pi
C=$P/chain
export CHAIN_SCRIPT=$P/soil_chain_obs.R
for b in 0.08; do
  for tol in 1e-4 3e-5 1e-5; do
    bash $P/chain.sh beta${b}_ld_${tol} REGIME=long-drought TOL=$tol CONTROL=pi PI_BETA=$b REF=$C/ref_ld.rds OUT=$C/beta${b}_ld_${tol}.rds
    bash $P/chain.sh beta${b}_const_${tol} REGIME=constant TOL=$tol CONTROL=pi PI_BETA=$b REF=$C/ref_const.rds OUT=$C/beta${b}_const_${tol}.rds
    cat $C/beta${b}_ld_${tol}.log $C/beta${b}_const_${tol}.log | cut -c1-150
  done
done
