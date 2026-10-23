#!/bin/bash
# kept: every resident's P scaled
for g in 0 8; do
  for s in 1.001 0.999; do
    PHASE=resident GEOM=$g PLANT_LEAF_KEY=96 PLANT_LEAF_PSCALE=$s OUT=/tmp/front/kept_${g}_$s timeout 1500 Rscript /tmp/front/run_inv.R > /tmp/front/kept_${g}_$s.log 2>&1 &
  done
done
# held, resolved: identity invader on the full refined schedule
for s in 1 1.001 0.999 1.0001 0.9999; do
  PHASE=invade INV_N=1 IDENT_EPS=1e-9 GEOM=8 INV_ALL=1 PLANT_LEAF_PSCALE=$s OUT=/tmp/front/held8_$s timeout 2400 Rscript /tmp/front/run_inv.R > /tmp/front/held8_$s.log 2>&1 &
done
wait
Rscript /tmp/front/kh_read.R
