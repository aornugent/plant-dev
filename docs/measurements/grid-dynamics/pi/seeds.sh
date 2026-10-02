#!/bin/bash
# The chain-alone seeds at each tolerance the coupled runs use (odelia's law, as the given file).
P=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/pi
for tol in 1e-4 1e-5 2.85e-5 3.15e-5; do
  bash $P/chain.sh seed_ld_$tol REGIME=long-drought TOL=$tol CONTROL=odelia OUT=$P/chain/seed_ld_$tol.rds
  cat $P/chain/seed_ld_$tol.log
done
