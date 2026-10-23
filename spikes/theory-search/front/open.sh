#!/bin/bash
for g in 0 8; do
  CASE=open PHASE=resident GEOM=$g OUT=/tmp/front/open_$g timeout 1500 Rscript /tmp/front/run_inv.R > /tmp/front/open_$g.log 2>&1 &
done
wait
Rscript -e 'for (g in c(0, 8)) { r <- readRDS(sprintf("/tmp/front/open_%d.rds", g)); t <- r$node_times[[1]]; W <- r$by_node[[1]]; i <- which(t < 0.8); cat("open GEOM", g, "F", r$F, "\n"); print(signif(rbind(t = t[i], W = W[i]), 3)) }'
