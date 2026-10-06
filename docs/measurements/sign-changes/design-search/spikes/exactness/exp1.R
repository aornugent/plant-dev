# Elasticity spread under seven tol nudges, each method on its own adaptive mesh,
# and each method's error against the converged reference.
source("toy.R")
setup()
th0 <- c(2, 0.35, 0.05)
base <- as.numeric(Sys.getenv("TOL", "1e-4"))
methods <- strsplit(Sys.getenv("METHODS", "plain,smooth,bracket,split"), ",")[[1]]
f <- c(0.95, 0.97, 0.99, 1, 1.01, 1.03, 1.05)
res <- list()
for (m in methods) {
  E <- matrix(NA, length(f), 4, dimnames = list(f, c("lnJ", "e1", "e2", "e3")))
  info <- c()
  for (i in seq_along(f)) {
    reset_counts()
    a <- run_adaptive(th0, base * f[i], m)
    E[i, 1] <- replay(a$times, th0, m)
    for (k in 1:3) E[i, k + 1] <- elasticity(a$times, th0, k, m)
    info <- c(info, length(a$times) - 1)
  }
  res[[m]] <- list(E = E, steps = info)
  cat(m, "steps", info, "\n"); print(signif(E, 7))
  flush.console()
}
saveRDS(res, sprintf("exp1_%s.rds", format(base)))
