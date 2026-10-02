#!/bin/bash
# Candidate PI gains on the chain alone, long drought: (kI, kP) = (alpha - beta, beta).
#   g1  (0.13, 0.04) S 0.9      the tested law
#   g2  (0.06, 0.08) S 0.9      Hairer's beta = 0.08 (set point 0.17)
#   g3  (0.06, 0.08) S 0.9525   Gustafsson's gains at the tested law's set point 0.445
#   g4  (0.13, 0.08) S 0.9      the proportional gain doubled
P=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/pi
C=$P/chain
export CHAIN_SCRIPT=$P/soil_chain_obs.R
for tol in 1e-4 3e-5 1e-5; do
  bash $P/chain.sh g2_ld_$tol REGIME=long-drought TOL=$tol CONTROL=pi PI_BETA=0.08 REF=$C/ref_ld.rds OUT=$C/g2_ld_$tol.rds
  bash $P/chain.sh g3_ld_$tol REGIME=long-drought TOL=$tol CONTROL=pi PI_BETA=0.08 PI_ALPHA=0.14 PI_SAFETY=0.9525 REF=$C/ref_ld.rds OUT=$C/g3_ld_$tol.rds
  bash $P/chain.sh g4_ld_$tol REGIME=long-drought TOL=$tol CONTROL=pi PI_BETA=0.08 PI_ALPHA=0.21 REF=$C/ref_ld.rds OUT=$C/g4_ld_$tol.rds
  bash $P/chain.sh g3_const_$tol REGIME=constant TOL=$tol CONTROL=pi PI_BETA=0.08 PI_ALPHA=0.14 PI_SAFETY=0.9525 REF=$C/ref_const.rds OUT=$C/g3_const_$tol.rds
  bash $P/chain.sh g4_const_$tol REGIME=constant TOL=$tol CONTROL=pi PI_BETA=0.08 PI_ALPHA=0.21 REF=$C/ref_const.rds OUT=$C/g4_const_$tol.rds
done
for g in g2 g3 g4; do for tol in 1e-4 3e-5 1e-5; do echo "$g $tol: $(head -1 $C/${g}_ld_$tol.log | cut -d'|' -f1) | $(sed -n 2p $C/${g}_ld_$tol.log | cut -c1-110)"; done; done
for g in g3 g4; do for tol in 1e-4 3e-5 1e-5; do echo "$g const $tol: $(head -1 $C/${g}_const_$tol.log | cut -d'|' -f1) | $(sed -n 2p $C/${g}_const_$tol.log | cut -c60-140)"; done; done
