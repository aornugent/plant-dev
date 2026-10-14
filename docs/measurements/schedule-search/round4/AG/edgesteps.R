# edgesteps.R RUN CASE: accepted step sizes at the instant gate's edges, the steps on
# which a split of the newest node holds E at one value (bounds that approximation).
source("/home/user/plant-dev/docs/measurements/schedule-search/round4/AG/lib.R")
a <- commandArgs(TRUE); x <- ag_run(a[1]); et <- edge_table(a[2]); t <- x$stand$times; h <- diff(t) * 365
i <- findInterval(et$b, t); hs <- h[pmax(1, i)]
G <- x$gate; dE <- vapply(et$b, function(b) { j <- findInterval(b, G$time); abs(G$E[min(j + 1, nrow(G))] - G$E[max(j, 1)]) }, 0)
cat(sprintf("%s: step containing each g-edge: median %.2f d, 90%% %.2f d, max %.2f d; E change over it median %.4f, max %.4f; held-E error bound per step ~ dE*h/2 median %.2e d (spell weight ~10 d)\n",
  a[1], median(hs), quantile(hs, 0.9), max(hs), median(dE), max(dE), median(dE * hs / 2)))
