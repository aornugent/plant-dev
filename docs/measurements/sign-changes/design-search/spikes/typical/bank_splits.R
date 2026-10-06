# The incumbent's split record on two more records of the bank (constant and
# episodic rain; 108 uniform nodes, 1e-4 tied): how many node steps it cuts, on
# which nodes by share of J, and how slow its slowest crossing is, against long
# drought's (p21/final2/split_1.rds).
D <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev"
.libPaths(c(file.path(D, "lib_rr"), .libPaths()))
share_of <- function(x) {
  n <- x$stand$nodes
  m <- min(length(n$establishment), length(n$nrr))
  pd <- plant::Weibull_Disturbance_Regime(x$setting$lifetime)
  w <- n$establishment[1:m] * n$nrr[1:m] * vapply(n$birth[1:m], pd$density, 0)
  w / sum(w)
}
for (f in c(file.path(D, "p21/final2/split_1.rds"), "fwd_constant.rds", "fwd_episodic.rds")) {
  x <- readRDS(f); r <- x$stand$split_record; s <- share_of(x)
  h <- x$stand$sizes; h <- h[is.finite(h)]
  heavy <- s >= 1e-3
  cat(sprintf("%-16s steps %5d  node steps cut %5d  searched %4d  nodes cut %3d of %d\n",
              x$setting$regime, length(x$stand$times), sum(r$split), sum(r$searched), sum(r$split > 0), length(r$split)))
  cat(sprintf("   nodes >= 1e-3 of J: %d, carrying %.3f of J, holding %.1f%% of the cuts; median step %.2f days\n",
              sum(heavy), sum(s[heavy]), 100 * sum(r$split[heavy]) / max(1, sum(r$split)), 365 * median(h)))
  cat(sprintf("   slowest crossing |dP/dt| %.3g kg/yr^2 at day %.1f, node %d (share %.2g); kappa there ~ %.2g at the median step\n",
              r$least_rate, 365 * r$least_rate_time, r$least_rate_node, s[r$least_rate_node],
              median(h) * r$least_rate / 1e-4))
}
