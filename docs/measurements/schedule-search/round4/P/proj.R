# proj.R CASE BASE_RUN RUN...: each run's move projected on BASE_RUN's move (both against a09 c), and ln J errors.
source("/home/user/plant-dev/docs/measurements/schedule-search/round4/P/lib.R")
a <- commandArgs(TRUE); cs <- a[1]; B <- pair(cs)
mvof <- function(nm) { f <- file.path(POUT, "runs", paste0(nm, ".rds")); x <- readRDS(f); q <- quantities(x); k <- intersect(B$k, names(q)); e <- eps_vec(k); err <- (q[k] - B$ref[k]) / e; list(mv = err - B$ec[k], err = err, k = k) }
m0 <- mvof(a[2])
for (nm in a[-1]) { m <- mvof(nm); k <- intersect(m0$k, m$k)
  cat(sprintf("%-18s on %-14s: projection %.2f, corr %.2f, resid rms %.3f | lnJ err %+.3f (base %+.3f)\n", nm, a[2], sum(m$mv[k] * m0$mv[k]) / sum(m0$mv[k]^2), cor(m$mv[k], m0$mv[k]),
    sqrt(mean((m$mv[k] - m0$mv[k] * sum(m$mv[k] * m0$mv[k]) / sum(m0$mv[k]^2))^2)), m$err["lnJ"], B$ec["lnJ"])) }
