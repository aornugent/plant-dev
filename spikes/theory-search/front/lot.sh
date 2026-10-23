#!/bin/bash
for sh in -0.693147 0.693147; do
  PHASE=resident GEOM=10 LNB_SHIFT=$sh OUT=/tmp/front/lot_$sh timeout 1500 Rscript /tmp/front/run_inv.R > /tmp/front/lot_$sh.log 2>&1 &
done
PHASE=resident GEOM=10 OUT=/tmp/front/lot_0 timeout 1500 Rscript /tmp/front/run_inv.R > /tmp/front/lot_0.log 2>&1 &
wait
Rscript /tmp/front/lot_read.R
