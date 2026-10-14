# U4: the check at lma x1.1 on episodic's grids against episodic's own check.
source("/home/user/plant-dev/docs/measurements/schedule-search/round4/F/lib.R")
A <- pair(Sys.getenv("CASE0", "episodic")); xc <- readRDS(file.path(R, paste0(Sys.getenv("TAGL", "F_l10"), "c.rds"))); xf <- readRDS(file.path(R, paste0(Sys.getenv("TAGL", "F_l10"), "f.rds")))
qc <- quantities(xc); qf <- quantities(xf); k <- intersect(A$k, names(qc)); e <- eps_vec(k)
est1 <- (qc[k] - qf[k]) / e / (1 - A$s); est0 <- (A$d / (1 - A$s))[k]
cr <- crit(est1, est0)    # theta0's estimate read against theta1's own estimate as if it were the error
big <- pmax(abs(est1), abs(est0)) > 1 / 3
cat(sprintf("lnJ theta1 - theta0 %.2f; theta1 estimate worst %.2f (%s), rms %.3f; theta0 estimate worst %.2f, rms %.3f\n",
  qc["lnJ"] - A$qc["lnJ"], max(abs(est1)), k[which.max(abs(est1))], sqrt(mean(est1^2)), max(abs(est0)), sqrt(mean(est0^2))))
cat(sprintf("max |est1 - est0| %.2f (%s); corr %.2f; theta0's read of theta1 as C1-C5: %s; quantities over eps/3: %d\n",
  max(abs(est1 - est0)), k[which.max(abs(est1 - est0))], cor(est1, est0), paste(names(cr), as.integer(cr), collapse = " "), sum(big)))
B <- pair("episodic-lma"); kk <- intersect(k, B$k); e125 <- (B$d / (1 - B$s))[kk]
o <- order(-abs(est1))[1:8]; print(data.frame(q = k[o], est_x1 = round(est0[o], 2), est_x1.1 = round(est1[o], 2), est_x1.25_owngrid = round(e125[k[o]], 2)), row.names = FALSE)
cat(sprintf("growth: rms est x1.1 / x1 = %.2f; x1.25 (own grid) / x1 = %.2f\n", sqrt(mean(est1^2)) / sqrt(mean(est0^2)), sqrt(mean(e125^2)) / sqrt(mean(est0[kk]^2))))
cat(sprintf("CPU c %.0f f %.0f (episodic's own: %.0f, %.0f)\n", cpu_of(xc), cpu_of(xf), A$cpu_c, A$cpu_f))
