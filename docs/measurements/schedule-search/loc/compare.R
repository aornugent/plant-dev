# compare.R CASE RUN...: each run's errors in eps against the case's reference, with
# lattice runs alongside; for consecutive runs, the estimate (Q_a - Q_b)/3 for b.
suppressMessages(source("/home/user/plant-dev/harness/schedule/evaluate.R"))
a <- commandArgs(TRUE); case <- a[1]; nm <- a[-1]
A <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap/runs"
ref <- reference(case)
get <- function(n) readRDS(file.path(A, paste0(n, ".rds")))
xs <- lapply(nm, get); qs <- lapply(xs, quantities); k <- Reduce(intersect, c(list(names(ref)), lapply(qs, names)))
e <- eps_vec(k); err <- sapply(qs, function(q) (q[k] - ref[k]) / e); colnames(err) <- nm
cost <- sapply(xs, function(x) run_cost(x$stand$rows, TRUE))
cat(sprintf("%-22s %8s %6s %7s %6s %s\n", "run", "rows(k)", "cost", "worst", "over1", "over1/3"))
for (i in seq_along(nm)) cat(sprintf("%-22s %8.0f %6.0f %7.2f %6d %d\n", nm[i], xs[[i]]$stand$rows / 1e3, cost[i], max(abs(err[, i])), sum(abs(err[, i]) > 1), sum(abs(err[, i]) > 1/3)))
big <- apply(abs(err), 1, max) > 1/3
print(round(err[big, , drop = FALSE], 2))
if (length(nm) >= 2) for (i in 2:length(nm)) {
  est <- (qs[[i - 1]][k] - qs[[i]][k]) / 3 / e; ee <- err[, i]; m <- pmax(abs(ee), abs(est)) > 1/3
  ok <- abs(est) >= abs(ee) / 2 & abs(est) <= 2 * abs(ee) & sign(est) == sign(ee)
  r <- abs(err[, i]) / abs(err[, i - 1]); bb <- abs(err[, i - 1]) > 1/3
  cat(sprintf("%s -> %s: lnJ move %+.3f eps; median |err| ratio over |err|>1/3: %.2f (n %d); est within x2 signed %d of %d\n",
    nm[i - 1], nm[i], (qs[[i]]["lnJ"] - qs[[i - 1]]["lnJ"]) / 0.025, median(r[bb]), sum(bb), sum(ok[m]), sum(m)))
}
