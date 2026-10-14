# usecmp.R RUN CASE0 CASE1: theta1 (CASE1's traits) run on CASE0's a09 committed grid,
# against CASE1's reference, CASE1's own-grid committed run, and CASE0's estimate.
source("/home/user/plant-dev/docs/measurements/schedule-search/round4/F/lib.R")
a <- commandArgs(TRUE); x <- readRDS(file.path(R, paste0(a[1], ".rds"))); A <- pair(a[2]); B <- pair(a[3])
q <- quantities(x); k <- Reduce(intersect, list(B$k, A$k, names(q))); e <- eps_vec(k)
eu <- (q[k] - B$ref[k]) / e; eo <- B$ec[k]; est0 <- (A$d / (1 - A$s))[k]; est1 <- (B$d / (1 - B$s))[k]
mv <- eu - eo; cr0 <- crit(eu, est0); cr1 <- crit(eo, est1)
cat(sprintf("%s: J %.6f (own grid %.6f), CPU %.0f s (own %.0f), rows %.0f (own %.0f)\n", a[1], x$stand$J, B$xc$stand$J, cpu_of(x), B$cpu_c, x$stand$rows, B$xc$stand$rows))
cat(sprintf("error on theta0's grid: worst %.2f (%s), rms %.3f | own grid: worst %.2f, rms %.3f | theta0's own error worst %.2f\n",
  max(abs(eu)), k[which.max(abs(eu))], sqrt(mean(eu^2)), max(abs(eo)), sqrt(mean(eo^2)), max(abs(A$ec[k]))))
cat(sprintf("move from own grid: max %.2f (%s), rms %.3f, n > 0.15: %d, n > 0.3: %d\n", max(abs(mv)), k[which.max(abs(mv))], sqrt(mean(mv^2)), sum(abs(mv) > 0.15), sum(abs(mv) > 0.3)))
cat(sprintf("theta0's estimate as this use's estimate: %s | corrected (eu - est0) worst %.2f rms %.3f | corr(eu, est0) %.2f, corr(eu, A$ec) %.2f\n",
  paste(names(cr0), as.integer(cr0), collapse = " "), max(abs(eu - est0)), sqrt(mean((eu - est0)^2)), cor(eu, est0), cor(eu, A$ec[k])))
o <- order(-abs(eu))[1:6]; print(data.frame(q = k[o], use = round(eu[o], 2), own = round(eo[o], 2), theta0 = round(A$ec[k][o], 2), est0 = round(est0[o], 2)), row.names = FALSE)
