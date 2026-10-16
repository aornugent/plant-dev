# r2_ladder.R CASE: the interiors' nested ladder res (k = 1) -> I2 -> I4 [-> I8]: successive
# moves, their ratios (4 for second order) along root_P50, ln J, M and rms, the projected
# ratio <d1, d2>/|d2|^2 and cos(d1, d2); the region error from each rung pair by Richardson.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/p50/lib.R")
cs <- commandArgs(TRUE)[1]; R <- list(res = rd5(sprintf("cl_res_%s", cs)))
for (t in c("I2", "I4", "I8")) { f <- file.path(P5, "runs", sprintf("p5_%s_%s.rds", t, cs)); if (file.exists(f)) { x <- readRDS(f); if (!is.null(x$stand$elasticity)) R[[t]] <- x } }
nm <- names(R); d <- lapply(seq_len(length(R) - 1), function(i) mv_run(R[[i + 1]], R[[i]]))
for (i in seq_along(d)) line(sprintf("%s -> %s", nm[i], nm[i + 1]), d[[i]])
if (length(d) >= 2) for (i in 1:(length(d) - 1)) { a <- d[[i]]; b <- d[[i + 1]]; k <- intersect(names(a), names(b))
  cat(sprintf("  ratio move%d/move%d: root_P50 %.2f, omega %.2f, a_l1 %.2f, lnJ %.2f, M %.2f, rms %.2f | projected %.2f, cos %.2f\n", i, i + 1,
    a["root_P50"] / b["root_P50"], a["omega"] / b["omega"], a["a_l1"] / b["a_l1"], a["lnJ"] / b["lnJ"], onM(a) / onM(b), r2(a) / r2(b), sum(a[k] * b[k]) / sum(b[k]^2), sum(a[k] * b[k]) / sqrt(sum(a[k]^2) * sum(b[k]^2)))) }
# the region's error at res under each Richardson pair (second order assumed)
er <- err_run(R$res, cs); cum <- 0 * d[[1]]
for (i in seq_along(d)) { cum <- cum + d[[i]]; k <- 2^i; line(sprintf("region err from res->%s (x%.3f)", nm[i + 1], -k^2 / (k^2 - 1)), -k^2 / (k^2 - 1) * cum) }
