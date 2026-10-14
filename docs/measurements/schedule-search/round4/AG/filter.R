# filter.R CASE...: lib19's pilot gate g(t) (creation rate) filtered through
# dE/dt = (g - E)/w (w = 0.05 yr), exact per piecewise-constant step: how much
# establishment the averaged gate moves into the instant gate's shut gaps, and where
# the edges fall on E (rate > 0.01) against g.
source("/home/user/plant-dev/docs/measurements/schedule-search/round4/P/lib.R")
w <- 0.05
filt <- function(cr, E0 = cr$rate[1]) { E <- numeric(nrow(cr)); e <- E0
  for (i in seq_len(nrow(cr))) { h <- cr$end[i] - cr$start[i]; e <- cr$rate[i] + (e - cr$rate[i]) * exp(-h / w); E[i] <- e }; E }
for (cs in commandArgs(TRUE)) { cr <- creation_of(cs); E <- filt(cr); h <- cr$end - cr$start; k <- cr$end < 25 & cr$start > edge_table(cs)$b[1] - 1e-9
  op <- cr$rate > 0.01; tot_g <- sum(cr$rate[k] * h[k]); tot_E <- sum(E[k] * h[k])
  inGap <- sum((E * h)[k & !op]); et <- edge_table(cs)
  # E edges: runs of E > 0.01
  opE <- E > 0.01; r <- rle(opE[k]); 
  cat(sprintf("%-13s b1..25: int g %.3f, int E %.3f (%+.1f%%); E in g-gaps %.3f (%.0f%% of E); g edges %d, E edges %d; g gaps %d (median %.0f d), E gaps %d\n", cs, tot_g, tot_E, 100 * (tot_E / tot_g - 1),
    inGap, 100 * inGap / tot_E, nrow(et), sum(diff(as.integer(opE[k])) != 0), sum(et$opening), median(et$gap[et$opening]), sum(!r$values)))
  # E at closing edges and the tail length to E = 0.01 and to E = E_c/e
  cl <- et[!et$opening, ]; Ec <- approx(cr$end, E, cl$b)$y
  cat(sprintf("   at closing edges: E median %.3f (g just before %.3f); tail to E/e %.0f d; days E stays > 0.01 into the gap: median %.0f, gaps shorter than that: %d of %d\n",
    median(Ec), median(approx(cr$end, cr$rate, cl$b - 1/365)$y), w * 365, median(pmin(cl$gap, w * 365 * log(Ec / 0.01))), sum(cl$gap < w * 365 * log(Ec / 0.01)), nrow(cl)))
}
