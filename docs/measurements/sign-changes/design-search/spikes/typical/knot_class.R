# Do the curved crossings (large q = P'' h / P') sit in steps that start at a
# rainfall knot, so that a step-level guard could route them?
D <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev"
sp <- readRDS("census.rds")
f <- readRDS(file.path(D, "p21/final2/split_1.rds"))
knots <- sort(unique(f$knots))
sp$at_knot <- vapply(sp$t, function(s) min(abs(knots - s)) * 365 < 1e-6, TRUE)
one <- sp[sp$n == 1, ]
one$ulin <- one$v0 / (one$v0 - one$v1)
one$q <- 2 * abs(one$u1 - one$ulin) / pmax(one$u1 * (1 - one$u1), 1e-3)
for (k in c(TRUE, FALSE)) {
  s <- one[one$at_knot == k, ]
  cat(sprintf("steps %s a knot: %d single cuts, %.1f%% of the proxy; q median %.3g, 90%% %.3g; up-crossings %.0f%%\n",
              if (k) "starting at" else "not starting at", nrow(s), 100 * sum(s$wt) / sum(one$wt),
              median(s$q), quantile(s$q, .9), 100 * mean(s$v1 > 0)))
}
# q by direction
for (up in c(TRUE, FALSE)) {
  s <- one[(one$v1 > 0) == up, ]
  cat(sprintf("%s-crossings: %d, q median %.3g, 90%% %.3g, proxy %.1f%%\n", if (up) "up" else "down",
              nrow(s), median(s$q), quantile(s$q, .9), 100 * sum(s$wt) / sum(one$wt)))
}
cat("h (days) of crossing steps by class: knot", signif(median(one$h[one$at_knot]) * 365, 3),
    " other", signif(median(one$h[!one$at_knot]) * 365, 3), "\n")
