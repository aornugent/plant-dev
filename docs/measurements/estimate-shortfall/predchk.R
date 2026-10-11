# Map prediction for the bisected panels (3/4 of their coarsening move's own error:
# e/3 * 3/4 = e/4) against the measured pass-to-pass move, by region.  Rscript predchk.R NAME
source("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap/lib.R")
nm <- commandArgs(TRUE)[1]; x0 <- run(paste0(nm, "_p0")); x1 <- run(paste0(nm, "_p1"))
b <- nd(x0); j <- x0$dropped; e <- own_drop(b, j) / sum(b$w * b$offspring) + colSums(x0$light + x0$soil) / x0$stand$J
t0 <- x0$node_times; t1 <- x1$node_times; new <- setdiff(round(t1, 10), round(t0, 10))
hit <- vapply(seq_along(j), function(i) any(new > round(t0[j[i] - 1], 10) & new < round(t0[j[i] + 1], 10)), TRUE)
pm <- panel_moves(nd(x0), nd(x1)); mv <- (pm$field + pm$establishment + pm$interpolation) / sum(b$w * b$offspring)
br <- c(0, 0.5, 1, 2, 3.7, 10, 41)
cat(sprintf("%s: measured d lnJ %+.5f (nodes %+.5f); predicted for the bisected panels %+.5f (all e/3 %+.5f)\n", nm,
  log(x1$stand$J) - log(x0$stand$J), sum(mv), -sum(e[hit]) / 4, sum(e) / 3))
print(round(rbind(pred = tapply(-e * hit / 4, cut(b$birth[j], br), sum), meas = tapply(mv, cut(b$birth, br), sum), e3 = tapply(e / 3, cut(b$birth[j], br), sum)) * 1e3, 2))
