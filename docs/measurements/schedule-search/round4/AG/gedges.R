# gedges.R RUN CASE: the instant gate recovered from a libAG run's E record,
# g = E + w dE/dt (exact per step for g held over it), its edges (g > 0.01)
# against the lib19 pilot's, and where E itself crosses 0.01.
source("/home/user/plant-dev/docs/measurements/schedule-search/round4/AG/lib.R")
a <- commandArgs(TRUE); x <- ag_run(a[1]); G <- x$gate; G <- G[!duplicated(G$time, fromLast = TRUE), ]; w <- 0.05
q <- exp(-diff(G$time) / w); g <- (G$E[-1] - G$E[-nrow(G)] * q) / (1 - q); t0 <- G$time[-nrow(G)]; t1 <- G$time[-1]
op <- g > 0.01; r <- rle(op); e <- cumsum(r$lengths); ed <- t1[e][-length(e)]; ed <- ed[ed > 0 & ed < 25]
p <- edge_table(a[2])$b
near <- vapply(p, function(b) min(abs(ed - b)) * 365, 0)
cat(sprintf("%s: g edges from E record %d (lib19 pilot %d); each pilot edge's nearest: median %.2f d, 90%% %.2f d, max %.1f d; unmatched (> 3 d) %d\n", a[1], length(ed), length(p), median(near), quantile(near, 0.9), max(near), sum(near > 3)))
opE <- G$E > 0.01; rE <- rle(opE); eE <- cumsum(rE$lengths); edE <- G$time[eE][-length(eE)]; cat(sprintf("E > 0.01 edges before 25: %d\n", sum(edE > 0 & edE < 25)))
