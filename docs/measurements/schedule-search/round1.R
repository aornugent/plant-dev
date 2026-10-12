source("/home/user/plant-dev/harness/schedule/candidates.R")
cs <- c("episodic", "episodic-lma")
# additivity check where off-axis runs exist
for (c0 in cs) { lib <- load_library(c0); for (pt in list(c(32, 35), c(8, 140))) { key <- sprintf("%s/%s", pt[1], pt[2]); if (is.null(lib[[key]])) next
  real <- lib[[key]]; l2 <- lib; l2[[key]] <- NULL; pr <- lookup(l2, pt[1], pt[2]); k <- intersect(names(real$q), names(pr$q))
  d <- abs(real$q[k] - pr$q[k]) / eps_vec(k); cat(sprintf("additivity %s (%s): worst %.3f eps (%s), rows predicted/real %.3f\n", c0, key, max(d), names(which.max(d)), pr$rows / real$rows)) } }
# each lattice point's own error, for orientation
for (c0 in cs) { lib <- load_library(c0); ref <- reference(c0)
  for (n in names(lib)) { q <- lib[[n]]$q; k <- intersect(names(q), names(ref)); e <- abs(q[k] - ref[k]) / eps_vec(k)
    cat(sprintf("%-13s %-8s worst %.2f (%s) rows %.0fk cost %.0f s\n", c0, n, max(e), names(which.max(e)), lib[[n]]$rows / 1e3, run_cost(lib[[n]]$rows))) } }
cands <- list(one_16_70 = one_point(16, 70), one_32_35 = one_point(32, 35), ladder = ladder(), regional = regional())
for (nm in names(cands)) { r <- evaluate(cands[[nm]], cs); cat(sprintf("\n%s: T %.0f s, feasible %s\n", nm, r$T, r$feasible)); print(r$table, digits = 3, row.names = FALSE) }
