# Where a05's cost and error sit, per case: nodes, cost, band shrinks of the check.
source("/home/user/plant-dev/docs/measurements/schedule-search/round3/C/lib.R")
for (cs in TRAIN) { cd <- prepare(cs); p <- cd$pilot; pr <- a05_pair(p); Sc <- pr$Sc; Sk <- pr$Sk
  wide <- build_graded(p, function(b) 1e9)  # widest legal
  ec <- round(Sc, 8) %in% round(p$edges, 8)
  Ac <- bandA(cd, Sc, cs); Ak <- bandA(cd, Sk, cs); Aw <- bandA(cd, wide, cs)
  sp <- A05$proxy_err(p, Sk) / A05$proxy_err(p, Sc)
  cat(sprintf("%-13s b1 %.2f edges %d | Sc %d (int %d) Sk %d wide %d | cost c %.0f f %.0f (%.2f) wide %.2f edges-only %.2f | s proxy %.2f\n", cs, p$b1, length(p$edges), length(Sc), sum(!ec), length(Sk), length(wide),
    cost_of(cd, Sc), cost_of(cd, Sk), cost_of(cd, Sk)/cost_of(cd, Sc), cost_of(cd, wide)/cost_of(cd, Sc), cost_of(cd, sort(unique(c(0, p$edges))))/cost_of(cd, Sc), sp))
  cat("   bandA c:", sprintf("%.2f", Ac), " shrink k/c:", sprintf("%.2f", Ak/Ac), " wide/c:", sprintf("%.2f", Aw/Ac), "\n")
  K <- do.call(rbind, cd$kap[setdiff(cd$Qs, "lnJ")])
  e <- err_of(cd, Sc, cs); ew <- err_of(cd, wide, cs)
  cat("   max|err| c", sprintf("%.2f", max(abs(e))), " wide", sprintf("%.2f", max(abs(ew))), " n>1/3:", sum(abs(e) > 1/3), "\n")
  # contribution of each band to each quantity's error (kap * A)
  C <- sweep(K, 2, Ac, "*"); top <- order(-abs(e[rownames(K)]))[1:4]
  print(round(cbind(C[top, , drop = FALSE], tot = rowSums(C[top, , drop = FALSE])), 2)) }
