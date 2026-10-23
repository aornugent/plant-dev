#!/bin/bash
for k in 4 8 12; do
  PHASE=resident GEOM=$k OUT=/tmp/front/geo_$k timeout 900 Rscript /tmp/front/run_inv.R > /tmp/front/geo_$k.log 2>&1 &
done
wait
Rscript /tmp/front/geo_read.R
