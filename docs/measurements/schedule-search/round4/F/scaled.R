# Does the error keep its size relative to the quantity? est0 * q1 / q0 against est1 (and against
# the plain transfer est0), on the three theta1 pairs run on theta0's grids.
source("/home/user/plant-dev/docs/measurements/schedule-search/round4/F/lib.R")
for (u in list(c("episodic", "F_l10"), c("episodic", "F_l09"), c("dry", "F_dl09"))) { A <- pair(u[1])
  qc <- quantities(readRDS(file.path(R, paste0(u[2], "c.rds")))); qf <- quantities(readRDS(file.path(R, paste0(u[2], "f.rds"))))
  k <- setdiff(intersect(A$k, names(qc)), "lnJ"); e <- eps_vec(k); est1 <- (qc[k] - qf[k]) / e / (1 - A$s); est0 <- (A$d / (1 - A$s))[k]
  r <- qc[k] / A$qc[k]; sc <- est0 * ifelse(abs(r) < 5 & r > 0, r, 1)
  cat(sprintf("%-8s %-6s plain: max miss %.2f rms %.3f %s | scaled by q1/q0: max miss %.2f rms %.3f %s | q1/q0 median %.2f range %.2f-%.2f\n", u[1], u[2],
    max(abs(est1 - est0)), sqrt(mean((est1 - est0)^2)), paste(as.integer(crit(est1, est0)), collapse = ""),
    max(abs(est1 - sc)), sqrt(mean((est1 - sc)^2)), paste(as.integer(crit(est1, sc)), collapse = ""), median(r), min(r), max(r))) }
