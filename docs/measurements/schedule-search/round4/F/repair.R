# Repairs for uses at the radius: (a) commit fine for the analysis, uses on f with theta0's
# fine estimate d0 s/(1 - s); (c) each use runs its own pair on theta0's grids. Costs from a09.
source("/home/user/plant-dev/docs/measurements/schedule-search/round4/F/lib.R")
for (u in list(c("episodic", "F_l10"), c("episodic", "F_l09"), c("dry", "F_dl09"))) { A <- pair(u[1])
  qc <- quantities(readRDS(file.path(R, paste0(u[2], "c.rds")))); qf <- quantities(readRDS(file.path(R, paste0(u[2], "f.rds"))))
  k <- intersect(A$k, names(qc)); e <- eps_vec(k); d1 <- (qc[k] - qf[k]) / e; s <- A$s
  ef1 <- d1 * s / (1 - s); ef0 <- (A$d * s / (1 - s))[k]
  cat(sprintf("%-8s %-6s use on f: est. error worst %.2f, theta0's fine estimate misses by <= %.2f, C1-C5 %s\n", u[1], u[2], max(abs(ef1)), max(abs(ef1 - ef0)), paste(as.integer(crit(ef1, ef0)), collapse = ""))) }
L <- lapply(ALL, pair); Ta <- Tc <- T0 <- 0
for (P in L) { T0 <- T0 + P$Tc + P$Tf + 2 * (if (max(abs(P$d / (1 - P$s))) < 1) P$Tc else P$Tf); Ta <- Ta + P$Tc + 3 * P$Tf; Tc <- Tc + 3 * (P$Tc + P$Tf) }
cat(sprintf("T all ten: a09 %.0f; (a) uses on f %.0f (%+.1f%%); (c) a pair per use %.0f (%+.1f%%)\n", T0, Ta, 100 * (Ta / T0 - 1), Tc, 100 * (Tc / T0 - 1)))
