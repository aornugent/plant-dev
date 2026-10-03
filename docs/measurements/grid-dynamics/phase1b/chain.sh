#!/bin/bash
# The soil chain alone (no uptake) under CK and DP at three tolerances, against
# CK at 1e-9: is DP's bias the soil's? Seconds per run.
P=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/phase1b
L=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/lib_v12t
S=$P/snap/chain
rm -rf $S; mkdir -p $S/harness; cp $P/harness/*.R $S/harness/
cd $S
O=$P/runs/chain
mkdir -p $O
[ -s $O/ref.rds ] || env PLANT_LIB=$L METHOD=ck TOL=1e-9 OUT=$O/ref.rds nice -n 10 Rscript harness/soil_chain.R > $O/ref.log 2>&1
for m in ck dp; do for T in 1e-4 3e-5 1e-5; do
  env PLANT_LIB=$L METHOD=$m TOL=$T REF=$O/ref.rds OUT=$O/${m}_$T.rds nice -n 10 Rscript harness/soil_chain.R > $O/${m}_$T.log 2>&1
done; done
cat $O/ref.log $O/ck_*.log $O/dp_*.log
