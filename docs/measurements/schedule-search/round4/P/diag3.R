# diag3.R CASE: the inset pair at 3e-4 against 1e-4, per quantity over eps/5 or estimate over eps/3: c and f errors at
# both tolerances, the estimate, and what the tolerance moved in each run.
source("/home/user/plant-dev/docs/measurements/schedule-search/round4/P/lib.R")
cs <- commandArgs(TRUE)[1]; ref <- refq(cs); ld <- function(t, s) readRDS(file.path(POUT, "runs", sprintf("P_%s%s_%s.rds", t, s, cs)))
q <- lapply(list(c1 = ld("ins", "c"), f1 = ld("ins", "f"), c3 = ld("ins3", "c"), f3 = ld("ins3", "f")), quantities)
k <- Reduce(intersect, c(list(names(ref)), lapply(q, names))); e <- eps_vec(k); E <- sapply(q, function(v) (v[k] - ref[k]) / e)
p <- pilot_of(cs); x <- readRDS(file.path(POUT, "runs", sprintf("P_insc_%s.rds", cs))); y <- readRDS(file.path(POUT, "runs", sprintf("P_insf_%s.rds", cs)))
s <- alg$proxy_err(p, y$node_times) / alg$proxy_err(p, x$node_times)
est1 <- (E[, "c1"] - E[, "f1"]) / (1 - s); est3 <- (E[, "c3"] - E[, "f3"]) / (1 - s)
D <- data.frame(c1 = E[, "c1"], f1 = E[, "f1"], est1 = est1, c3 = E[, "c3"], f3 = E[, "f3"], est3 = est3, read3 = est3 / E[, "c3"], tol_c = E[, "c3"] - E[, "c1"], tol_f = E[, "f3"] - E[, "f1"])
m <- abs(D$c3) > 0.2 | abs(D$est3) > 1/3; print(round(D[m, ][order(-abs(D$est3[m])), ], 2))
cat(sprintf("tolerance move 1e-4 -> 3e-4: c rms %.3f max %.2f; f rms %.3f max %.2f; corr(tol_c, tol_f) %.2f; rms of (tol_c - tol_f) %.3f -> estimate shift rms %.3f\n",
  sqrt(mean(D$tol_c^2)), max(abs(D$tol_c)), sqrt(mean(D$tol_f^2)), max(abs(D$tol_f)), cor(D$tol_c, D$tol_f), sqrt(mean((D$tol_c - D$tol_f)^2)), sqrt(mean(((D$tol_c - D$tol_f) / (1 - s))^2))))
